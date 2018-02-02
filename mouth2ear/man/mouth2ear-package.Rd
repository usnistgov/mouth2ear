\name{mouth2ear-package}
\alias{mouth2ear-package}
\alias{mouth2ear}
\docType{package}
\title{
\packageTitle{mouth2ear}
}
\description{
\packageDescription{mouth2ear}
}
\details{
  The mouth2ear package includes functions for:
  \itemize{
    \item Calculating M2E latency values for tests taken across multiple sessions. Can further thin data to eliminate significant autocorrelation in data.
    \item Creating acf plots and identifying the effect of autocorrelation on measurement uncertainty.
  }
  The package also includes example M2E latency measurements presented in NISTIR XXXX, saved as individual csv files for each session of each test. See examples to access the directory with the data.
  The data includes M2E latency measurements of LMR handhelds operating in direct and trunked modes. 
}
\author{
\packageAuthor{mouth2ear}
}
\references{
Frey JM, Pieper JK, Thompson ST (2018) MCV QoE Mouth to Ear Latency Measurement Methods. \emph{NISTIR}. URL \url{https://doi.org/10.6028/NIST.IR.XXXX}. 

Joint Committee on Guides in Metrology (JCGM), \emph{Evaluation of Measurement Data Guide to the Expression of Uncertainty in Measurement}, http://www.bipm.org/utils/common/documents/jcgm/JCGM_100_2008_E.pdf, 2008.

Zhang NF (2006) Calculation of the uncertainty of the mean of autocorrelated measurements. \emph{Metrologia} 43(4):S276. URL \url{http://stacks.iop.org/0026-1394/43/i=4/a=S15}.

Voran SD (2004) A bottom-up algorithm for estimating time-varying delays in coded speech. \emph{Proceedings of the 3rd International Conference on Measurement of Speech and Audio Quality in Networks}.
}
~~ Optionally other standard keywords, one per line, from file KEYWORDS in the R documentation directory ~~
\keyword{ package }
\seealso{
\code{\link[metRology]{metRology-package}}

\code{\link[metRology]{GUM}}
}
\examples{
## Get directory where example data is stored
# Full system path where example 1loc data stored
oneLoc.path <- system.file("extdata","Delay_Values", "1loc", package="mouth2ear")

# Full system path where example 2loc data stored
twoLoc.path <- system.file("extdata","Delay_Values", "2loc", package="mouth2ear")
}
