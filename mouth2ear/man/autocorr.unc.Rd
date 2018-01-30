\name{autocorr.unc}
\alias{autocorr.unc}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
autocorr.unc(y)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{y}{
%%     ~~Describe \code{y} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
##---- Should be DIRECTLY executable !! ----
##-- ==>  Define data, use random,
##--	or do  help(data=index)  for the standard data sets.

## The function is currently defined as
function (y) 
{
    y <- y[!is.na(y)]
    s.y <- sd(y, na.rm = T)
    m.y <- mean(y, na.rm = T)
    n <- length(y)
    rho <- c(rep(NA, n))
    sigma <- c(rep(NA, n))
    for (i in 1:n) {
        sv <- 0
        if (i < n) {
            for (k in (1:(n - i))) {
                sv <- sv + (y[k] - m.y) * (y[k + i] - m.y)
            }
        }
        rho[i] <- sv/((n - 1) * s.y^2)
        if (i == 1) {
            sigma[i] <- 1/sqrt(n)
        }
        else {
            sigma[i] <- sqrt((1 + 2 * sum(rho[1:(i - 1)]^2))/n)
        }
    }
    lim <- which(abs(rho) > 1.96 * sigma)
    if (length(lim) > 0) {
        n.c <- lim[length(lim)]
    }
    else {
        n.c <- 0
        u <- s.y/sqrt(n)
        lag <- 0
        r <- 1
        return(list(u = u, lag = lag, rho = rho, sigma = sigma, 
            r = r))
    }
    lag <- min(c(n.c, floor(n/4)))
    dv = seq(n - 1, n - lag, -1)
    r = 1 + 2 * (dv \%*\% rho[1:lag])/n
    u.2 <- r * (s.y^2)/n
    if (u.2 > 0) {
        u <- sqrt(u.2)
    }
    else {
        u <- NaN
    }
    return(list(u = u, lag = lag, rho = rho, sigma = sigma, r = r))
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }% use one of  RShowDoc("KEYWORDS")
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
