\name{acf.adj}
\alias{acf.adj}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
acf.adj(autocorr, plot.title = "", lag.max = NULL, show.plot = TRUE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{autocorr}{
%%     ~~Describe \code{autocorr} here~~
}
  \item{plot.title}{
%%     ~~Describe \code{plot.title} here~~
}
  \item{lag.max}{
%%     ~~Describe \code{lag.max} here~~
}
  \item{show.plot}{
%%     ~~Describe \code{show.plot} here~~
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
function (autocorr, plot.title = "", lag.max = NULL, show.plot = TRUE) 
{
    if (is.null(lag.max)) {
        lag.max <- length(autocorr$rho)/4
    }
    xvals <- 1:lag.max
    sample <- autocorr$rho[xvals]
    bound <- 1.96 * autocorr$sigma[xvals]
    norm.bnd <- 1.96/sqrt(length(autocorr$rho))
    lag <- autocorr$lag
    g <- ggplot()
    fplot <- g + geom_col(aes(x = xvals, y = sample)) + geom_line(aes(x = xvals, 
        y = bound, color = "red"), size = 1.5) + geom_line(aes(x = xvals, 
        y = -bound, color = "red"), size = 1.5) + geom_hline(yintercept = norm.bnd) + 
        geom_hline(yintercept = -norm.bnd) + geom_vline(xintercept = lag, 
        color = "blue") + theme(legend.position = "none") + ggtitle(plot.title) + 
        xlab("") + ylab("")
    if (show.plot) {
        print(fplot)
    }
    return(fplot)
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }% use one of  RShowDoc("KEYWORDS")
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
