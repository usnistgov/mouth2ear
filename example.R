# This software was developed by employees of the National Institute of
# Standards and Technology (NIST), an agency of the Federal Government.
# Pursuant to title 17 United States Code Section 105, works of NIST
# employees are not subject to copyright protection in the United States and
# are considered to be in the public domain. Permission to freely use, copy,
# modify, and distribute this software and its documentation without fee is
# hereby granted, provided that this notice and disclaimer of warranty
# appears in all copies.
# 
# THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
# EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
# WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
# FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
# CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
# FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
# LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
# OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
# WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
# OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
# WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
# USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.
#
# --------------------Package Dependencies----------------------------------
# The following functions rely on the following packages:
# ggplot2, grid, DEoptimR, MASS, metRology, numDeriv, robustbase

# Function for effectively clearing console
clc <- function() cat(rep("\n",50))
# Clear console
clc()

# Display example information
print(paste("The following code calculates the M2E latency and associated uncertainty",
            "of the example measurements presented in MCV QoE Mouth-to-Ear Latency Measurement Methods.",
            "The NIST technical report is available at https://doi.org/10.6028/NIST.IR.XXXX.",
            "The associated data is required for this example and is available at https://doi.org/10.6028/NIST.IR.XXXX.",
            "The measurement software is available at https://github.com/usnistgov/mouth2ear."))
cat("\n")
print(paste("The following code calculates the M2E latency and associated uncertainty for three test setups:",
            "A one location test communicating over cabled RF, a two location test communicating over cabled RF,",
            "and a two location test communicating over the air. In each test setup measurements were performed on",
            "both UHF and VHF LMR handsets communicating in both direct and trunked modes. This example code demonstrates",
            "that the single location and two location tests are consistent within a controlled lab environment, and",
            "that propagation effects while communicating over the air are negligible to overall M2E latency."))
readline(prompt = "Press Enter to clear the R environment and begin the example.")
clc()


# clear work space
rm(list = setdiff(ls(),"clc"))
# Required packages
packages <- c("ggplot2", "grid", "DEoptimR", "MASS","metRology","numDeriv","robustbase")
# Install any required packages user doesn't have
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))
}
# Add required packages to library
lapply(
  packages,
  FUN = function(packages) {
    do.call("require", list(packages))
  }
)

# Query user for path to one location delay values
oneLoc.path <- readline(prompt = "Paste Path to One Location Delay Values:")
# Query user for path to two location delay values
twoLoc.path <- readline(prompt = "Paste Path to Two Location Delay Values:")

clc()

# Change working directory to source file directory
setwd(dirname(sys.frame(1)$ofile))

# Import process.sessions function from session-processing.R
source("session-processing.R")

# Variables to keep at end of script
keep.data <- c("all.setups","setup.data","test.GUM","df","test.autocorr","no.lag.oneloc","no.lag.twoloc")

# Initialize information for each set of tests
oneLoc <- list(
  name = "One Location Lab",
  path = oneLoc.path,
  tests = c(
    "1loc-device-characterization",
    "1loc-UHF-Direct-wired-p25-lab-Vol-11",
    "1loc-UHF-Trunked-wired-p25-lab-Vol-11",
    "1loc-VHF-Direct-wired-p25-lab-Vol-11",
    "1loc-VHF-Trunked-wired-p25-lab-Vol-11"
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
  path = twoLoc.path,
  tests = c(
    "p25-lab-characterization-2loc", # characterization lab
    "UHF-Direct-p25-lab-wired-Vol-11", # uhf direct lab
    "UHF-Trunked-p25-lab-wired-Vol-11", # uhf trunked lab
    "VHF-Direct-p25-lab-wired-Vol-11", # vhf direct lab
    "VHF-Trunked-p25-lab-wired-Vol-11" # vhf trunked lab
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
  path = twoLoc.path,
  tests = c(
    "p25-lab-characterization-2loc", # characterization lab
    "UHF-Direct-US36-G", # uhf direct field
    "UHF-Trunked-US36-G", #uhf trunked field
    "VHF-Direct-US36-G", # vhf direct field
    "VHF-Trunked-US36-G" # vhf trunked field
  ),
  thinning = c(4, # characterization
               5, # field uhf direct
               4, # field uhf trunked
               4, # field vhf direct
               1 # field vhf trunked
  )
  
)

# Determine if autocorrelation lags should be printed or not
show.lags <- F

# Initialize list of all setups to run uncertainty analysis on
all.setups <- list(oneLoc, twoLoc.lab, twoLoc.field)

# Run M2E latency and uncertainty calculations
output <- process.sessions(all.setups = all.setups, show.lags= show.lags)

# M2E latency and uncertainty for all tests 
df <- output$df

# Print select information on values and uncertainty for each test
cat("\n-----------------Uncertainty Information------------------\n")
print(df[c("y","uc","nu.eff","k","U","valid")])

cat("\n-----------Checking consistency between one and two location tests-----------\n")
# Compare between tests
test.types<-c("characterization","UHF-Direct","UHF-Trunked","VHF-Direct","VHF-Trunked")
for (test in test.types){
  # Test information
  test.dat<- df[grepl(test,rownames(df)),] 
  print(paste("--------", test, "--------"))
  # If more than two tests being compared
  if(nrow(test.dat)>2){
    for(i in 1:(nrow(test.dat)-1)){
      for(j in (i+1):nrow(test.dat)){
        # Define CI i as A = (a.1 - U, a.1 + U)
        a.1 <- test.dat[i,"y"] - test.dat[i,"U"]
        a.2 <- test.dat[i,"y"] + test.dat[i,"U"]
        
        # Define CI j as B = (b.1 - U, b.1 + U)
        b.1 <- test.dat[j,"y"] - test.dat[j,"U"]
        b.2 <- test.dat[j,"y"] + test.dat[j,"U"]
        
        if( (a.1 < b.1 & b.1 < a.2)| (a.1 < b.2 & b.2 < a.2) | (b.1 < a.1 & a.1 < b.2) ){
          # Endpoint of B contained in A or endpoint of A contained in B => overlap
          cat(paste("Consistent:    ",rownames(test.dat[i,]), "&", rownames(test.dat[j,]), "\n"))
        }
        else{
          cat(paste("NOT consistent:",rownames(test.dat[i,]), "&", rownames(test.dat[j,]), "\n"))
        }
      }
    }
  }
  else if(nrow(test.dat) == 2){
    # Only two tests being compared
    # Define CI i as A = (a.1 - U, a.1 + U)
    a.1 <- test.dat[1,"y"] - test.dat[1,"U"]
    a.2 <- test.dat[1,"y"] + test.dat[1,"U"]
    
    # Define CI j as B = (b.1 - U, b.1 + U)
    b.1 <- test.dat[2,"y"] - test.dat[2,"U"]
    b.2 <- test.dat[2,"y"] + test.dat[2,"U"]
    
    if( (a.1 < b.1 & b.1 < a.2)| (a.1 < b.2 & b.2 < a.2) | (b.1 < a.1 & a.1 < b.2) ){
      # Endpoint of B contained in A or endpoint of A contained in B => overlap
      cat(paste("Consistent:    ",rownames(test.dat[1,]), "&", rownames(test.dat[2,]), "\n"))
    }
    else{
      cat(paste("NOT consistent:",rownames(test.dat[1,]), "&", rownames(test.dat[2,]), "\n"))
    }
  }
}
