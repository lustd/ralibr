#' Bump a given curve
#'
#' @param Curve A curve (discount or zero coupon)
#' @param Bump The bump to apply
#' @param IsDiscounts optional (default = TRUE) - indicates if the second column are discount facors or zero rates
#'
#' @return A bumped curve
#'
#' @export
#'
#' @examples bump_curve(Curve)
#'
bump_curve <- function(Curve, Bump = 0.0001, IsDiscounts = TRUE){
        # Take a single Curve and bump the Zero rates with 1 bps.
        # The default setting assumes that column 2 contains Discount factors
        # Output the new Discount curve (with dates)

        N <- length(Curve[,1])
        StartDates <- rep(x = Curve[1,1], N)
        T <- yearfrac(DateBegin = StartDates, DateEnd = Curve[,1], DayCountConv = "act/360")
        if(IsDiscounts){
                ZeroRates <- discount_to_rate(DF = Curve[,2], T = T, Compounding = "CC")
                ZeroRatesBump <- ZeroRates + Bump
                CurveBump <- Curve;
                CurveBump[,2] <- rate_to_discount(Rate = ZeroRatesBump,T = T,Compounding = "CC")
        }else{
                CurveBump <- Curve
                CurveBump <- Curve[,2]+Bump
        }

        return(CurveBump)
}

#' Calculate forward rates
#'
#' @param StartDate
#' @param EndDate
#' @param frame
#' @param DayCount
#' @param compounding
#'
#' @return
#' @export
#'
#' @examples
forward_rate <- function(StartDate, EndDate, frame, DayCount = "act/360", compounding = "AC"){

        ## Function calculates a forward rate for given Start and End
        ## EndDate can be eighter a Date or a numeric T (Years)

        # Updated with parse_date_internal
        StartDate <- parse_date_internal(DateToParse = StartDate)
        EndDate   <- parse_date_internal(DateToParse = EndDate)
        #if(class(EndDate)=="numeric"){EndDate <- as.numeric(StartDate)+EndDate/360}

        # Discount factors for start and end date
        DF.Start <- interpolate(X = frame[,1], Y = frame[,2], x = StartDate, method = "cs")
        DF.End <- interpolate(X = frame[,1], Y = frame[,2], x = EndDate,method = "cs")

        # What is the Yearfrac between Start and End dates
        dT <- yearfrac(DateBegin = StartDate,DateEnd = EndDate,DayCountConv = DayCount)

        if(any(dT==0)){dT[dT==0]<-EndDate[dT==0]*360}

        # Fwd Rate given convention
        if(compounding=="CC"){
                forward_rate <- log((DF.Start/DF.End))/dT
        }else{
                forward_rate <- vector(mode = "numeric",length=length(dT))
                forward_rate[dT<1] <- (1/dT[dT<1])*(DF.Start[dT<1]/DF.End[dT<1] - 1)
                forward_rate[dT>=1] <- (DF.Start[dT>=1]/DF.End[dT>=1])^(1/dT[dT>=1])-1
        }

        return(forward_rate)
}

#' Convert Discount Factors to Spot Rates
#'
#' @param DF A discount factor (numeric)
#' @param Compounding optional (default="CC") - The compounding frequency
#'
#' @return
#' @export
#'
#' @examples
discount_to_rate <- function(DF, T, Compounding = "CC"){

        if((toupper(Compounding)=="CC")|toupper(Compounding)=="Continuous"){
                ZeroRates <- -(1/T)*log(x = DF)
        }
        else if((toupper(Compounding)=="AC")|toupper(Compounding)=="Annual"){
                ZeroRates <- ((1/DF))^(1/T)-1
        }
        ZeroRates[is.na(ZeroRates)] <- 0
        return(ZeroRates)
}

#' Convert rates to discount factors
#'
#' @param Rate
#' @param Compounding
#'
#' @return
#' @export
#'
#' @examples
rate_to_discount <- function(Rate, T, Compounding = "CC"){

        if((toupper(Compounding)=="CC")|toupper(Compounding)=="Continuous"){
                Df <- exp(-Rate*T)
        }
        else if((toupper(Compounding)=="AC")|toupper(Compounding)=="Annual"){
                Df <- 1/(1+Rate)^T
        }
}



#' Interpolation
#'
#' @description Function useful for Interpolation.
#'    can be either "Dates" or "Numeric", allowing to
#'    easily Interpolate on discount curves.
#'    The interpolation can be done using linear or cubic-spline.
#'
#' @param X,Y Vectors giving the coordinates of the points to be interpolated.
#'    X can optionally be "Date" format,
#'    allowing to interpolate on a typical j
#'    discount curve structure.
#'
#' @param x A single point specifying where to interpolate on observations of X.
#'    Can be numeric, Date or character ("YYYY-MM-DD")
#'
#' @param method Either linear ("l") or cubicspline ("cs")
#'
#' @return The value corresponding to x of values in Y.
#'
#' @examples
#' Interpolate(X = c(1,3,5),Y = c(100,200,300),x = 2,method="l")
#' Interpolate(Curve$Date, Curve$Discount_Factors, "2025-03-03", "linear")
#'
#' @export

interpolate <- function(X, Y, x, method = "linear"){


        # No longer using characters as Input

        # if(class(x)=="character"){
        #         x <- ParseDate(DateToParse = x)
        # }

        # Convert the Vector X values in Column 1 to integers
        if (class(X)=="Date"){
                X <- as.numeric(X)
        }

        # Check if Point is inside the Vector X range
        if (any(x<min(X))) stop("Point < min(X)")

        # Interpolate given method
        if (method=="linear"|method=="lin"|method=="l"){
                if(any(x>max(X))){stop("x > max(X) - Use method = 'cs' for Extrapolation")}
                Interpolate <- approx(x = X,y = Y,xout = x)[[2]]
        }
        else if (method=="cs"|method=="cubicspline"|method=="spline"){
                if(any(x>max(X))){warning("x > max(X) - Extrapolating")}
                Interpolate <- spline(x = X,y = Y,method = "natural",xout = x)[[2]]
        }
        else stop("Input 'method' is wrong")

        return(Interpolate)
}

