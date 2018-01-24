# clear work space
rm(list = ls())
# Required packages
packages <- c("ggplot2", "plotly", "grid", "DEoptimR", "MASS","metRology","numDeriv","robustbase")

if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))
}
lapply(
  packages,
  FUN = function(packages) {
    do.call("require", list(packages))
  }
)

# Change working directory to source file directory
setwd(dirname(sys.frame(1)$ofile))

# Import process.sessions function from session-processing.R
source("session-processing.R")
# Import functions from extra_functions.R
source("extra_functions.R")

# Variables to keep at end of script
keep.data <- c("all.setups","setup.data","test.GUM","df","test.autocorr","no.lag.oneloc","no.lag.twoloc")

# Show Autocorrelation plots or not
show.plots <- T

# Initialize information for each set of tests

oneLoc <- list(
  name = "One Location Lab",
  path = "D:/MCV/M2E Latency/December-17_Data/Delay_Values/1loc",
  tests = c(
    "1loc-device-characterization",
    "1loc-UHF-Direct-wired-p25-lab-Vol-11",
    "1loc-UHF-Trunked-wired-p25-lab-Vol-11",
    "1loc-VHF-Direct-wired-p25-lab-Vol-11",
    "1loc-VHF-Trunked-wired-p25-lab-Vol-11"
  ),
  bad.Trials = c(NA, # characterization
                 NA, # uhf direct
                 NA, # uhf trunked
                 NA, # vhf direct
                 NA # vhf trunked
  ),
  thinning = c(3, # characterization
               4, # uhf direct
               4, # uhf trunked
               7, # vhf direct
               3 # vhf trunked
  )
)

twoLoc.lab <- list(
  name = "Two Location Lab",
  path = "D:/MCV/M2E Latency/December-17_Data/Delay_Values/2loc",
  tests = c(
    "p25-lab-characterization-2loc", # characterization lab
    "UHF-Direct-p25-lab-wired-Vol-11", # uhf direct lab
    "UHF-Trunked-p25-lab-wired-Vol-11", # uhf trunked lab
    "VHF-Direct-p25-lab-wired-Vol-11", # vhf direct lab
    "VHF-Trunked-p25-lab-wired-Vol-11" # vhf trunked lab
  ),
  bad.Trials = c(NA, # characterization
                 NA, # lab uhf direct
                 NA, # lab uhf trunked
                 NA, # lab vhf direct
                 NA # lab vhf trunked
  ),
  thinning = c(4, # characterization
               3, # lab uhf direct
               5, # lab uhf trunked
               5, # lab vhf direct
               5 # lab vhf trunked
  )
  
)

twoLoc.field <- list(
  name = "Two Location Lab",
  path = "D:/MCV/M2E Latency/December-17_Data/Delay_Values/2loc",
  tests = c(
    "p25-lab-characterization-2loc", # characterization lab
    "UHF-Direct-US36-G", # uhf direct field
    "UHF-Trunked-US36-G", #uhf trunked field
    "VHF-Direct-US36-G", # vhf direct field
    "VHF-Trunked-US36-G" # vhf trunked field
  ),
  bad.Trials = c(NA, # characterization
                 NA, # field uhf direct
                 NA, # field uhf trunked
                 NA, # field vhf direct
                 NA  # field vhf trunked
  ),
  thinning = c(4, # characterization
               5, # field uhf direct
               4, # field uhf trunked
               4, # field vhf direct
               1 # field vhf trunked
  )
  
)


# Initialize list of all setups to run uncertainty analysis on
all.setups <- list(oneLoc, twoLoc.lab,twoLoc.field)
# all.setups<-list(oneLoc, twoLoc.field)
# all.setups<-list(oneLoc, twoLoc.lab)

output <- process.sessions(all.setups)
