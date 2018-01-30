\name{process.sessions}
\alias{process.sessions}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
%%  ~~function to do ... ~~
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
process.sessions(all.setups, show.lags = F)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{all.setups}{
%%     ~~Describe \code{all.setups} here~~
}
  \item{show.lags}{
%%     ~~Describe \code{show.lags} here~~
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
function (all.setups, show.lags = F) 
{
    setup.data <- list()
    test.GUM <- list()
    test.autocorr <- list()
    meas.res <- 0.000125
    for (setup in all.setups) {
        print(paste("-----------------", setup$name, "-----------------"))
        test.data <- list()
        plot.list <- list()
        ix = 1
        for (test in setup$tests) {
            print(paste(test, "Thin:", setup$thinning[ix]))
            dat.Path <- paste(setup$path, "/", test, sep = "")
            session.files <- list.files(dat.Path)
            session.data <- list()
            session.unc <- list()
            session.autocorr <- list()
            for (session in session.files) {
                session.data.raw <- read.csv(paste(dat.Path, 
                  "/", session, sep = ""), header = F)
                trial.m <- rowMeans(session.data.raw)
                trial.m <- trial.m[seq(from = 1, to = length(trial.m), 
                  by = setup$thinning[ix])]
                session.data[[gsub(".csv", "", session)]] <- trial.m
                autocorr <- autocorr.unc(trial.m)
                session.unc[[gsub(".csv", "", session)]] <- autocorr$u
                session.autocorr[[gsub(".csv", "", session)]] <- autocorr
                if (show.lags) {
                  print(paste("---- Lag:", autocorr$lag))
                }
                if (autocorr$lag > 0) {
                  print(paste("---- Lag:", autocorr$lag))
                }
                plot.name <- paste(test, session)
                plot.name <- gsub("session_", "", gsub("-", " ", 
                  gsub("p25-lab-", "", gsub(".csv", "", plot.name))))
            }
            test.data[[test]] <- session.data
            test.autocorr[[test]] <- session.autocorr
            ix = ix + 1
            n <- length(session.unc)
            if (grepl("characterization", test)) {
                meas.fnc <- paste("d+1/", n, "*(", paste("s", 
                  1:n, sep = "", collapse = "+"), ")", sep = "")
                test.uncertainty <- GUM(var.name = c(paste("s", 
                  1:length(session.unc), sep = ""), "d"), x.i = c(unlist(lapply(session.data, 
                  mean)), 0), u.i = c(unlist(session.unc), meas.res/sqrt(12)), 
                  nu.i = c(rep(length(trial.m) - 1, length(session.unc)), 
                    Inf), measurement.fnc = meas.fnc)
                test.uncertainty$valid <- GUM.validate(var.name = c(paste("s", 
                  1:length(session.unc), sep = ""), "d"), x.i = c(unlist(lapply(session.data, 
                  mean)), 0), u.i = c(unlist(session.unc), meas.res/sqrt(12)), 
                  nu.i = c(rep(length(trial.m) - 1, length(session.unc)), 
                    9999), type = c(rep("A", length(session.unc)), 
                    "A"), distribution = c(rep("Normal", length(session.unc)), 
                    "Uniform"), measurement.fnc = meas.fnc)
                tmp.vec <- as.data.frame(test.uncertainty$contributions)
                tmp.vec[["c"]] <- NA
                test.uncertainty$contributions <- as.matrix(tmp.vec)
                tmp.vec <- as.data.frame(test.uncertainty$sensitivities)
                tmp.vec[["c"]] <- NA
                test.uncertainty$sensitivities <- as.matrix(tmp.vec)
            }
            else {
                test.character <- setup$tests[grepl("characterization", 
                  setup$tests)]
                GUM.character <- test.GUM[[test.character]]
                meas.fnc <- paste("d+1/", n, "*(", paste("s", 
                  1:n, sep = "", collapse = "+"), ") - c", sep = "")
                test.uncertainty <- GUM(var.name = c(paste("s", 
                  1:length(session.unc), sep = ""), "d", "c"), 
                  x.i = c(unlist(lapply(session.data, mean)), 
                    0, GUM.character$y), u.i = c(unlist(session.unc), 
                    meas.res/sqrt(12), GUM.character$u), nu.i = c(rep(length(trial.m) - 
                    1, length(session.unc)), Inf, GUM.character$nu.eff), 
                  measurement.fnc = meas.fnc)
                test.uncertainty$valid <- GUM.validate(var.name = c(paste("s", 
                  1:length(session.unc), sep = ""), "d", "c"), 
                  x.i = c(unlist(lapply(session.data, mean)), 
                    0, GUM.character$y), u.i = c(unlist(session.unc), 
                    meas.res/sqrt(12), GUM.character$u), nu.i = c(rep(length(trial.m) - 
                    1, length(session.unc)), 9999, GUM.character$nu.eff), 
                  type = c(rep("A", length(session.unc)), "A", 
                    "A"), distribution = c(rep("Normal", length(session.unc)), 
                    "Uniform", "Normal"), measurement.fnc = meas.fnc)
            }
            test.uncertainty$msgs <- NULL
            test.GUM[[test]] <- test.uncertainty
        }
        setup.data[[gsub(" ", ".", setup$name)]] <- test.data
    }
    df <- data.frame(matrix(unlist(test.GUM), ncol = length(unlist(test.GUM$`1loc-device-characterization`)), 
        byrow = T), stringsAsFactors = T)
    colnames(df) <- names(unlist(test.GUM$`1loc-device-characterization`))
    rownames(df) <- names(test.GUM)
    return(list(thinned.data = setup.data, gum.data = test.GUM, 
        df = df, autocorr.data = test.autocorr))
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }% use one of  RShowDoc("KEYWORDS")
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
