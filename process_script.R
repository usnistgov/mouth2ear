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
all.setups <- list(oneLoc, twoLoc.lab,twoLoc.field)
# all.setups<-list(oneLoc, twoLoc.field)
# all.setups<-list(oneLoc, twoLoc.lab)

output <- process.sessions(all.setups = all.setups, show.lags= show.lags)

df <- output$df

# print(df)
print(df[c("y","uc","nu.eff","k","U","valid")])

cat("\n-----------Checking consistency between one and two location tests-----------\n")
# Compare between tests
test.types<-c("characterization","UHF-Direct","UHF-Trunked","VHF-Direct","VHF-Trunked")
for (test in test.types){
  test.dat<- df[grepl(test,rownames(df)),] 
  if(nrow(test.dat)>2){
    # consistency <- list()
    print(paste("--------", test, "--------"))
    for(i in 1:(nrow(test.dat)-1)){
      for(j in (i+1):nrow(test.dat)){
        
        # comp <- GUM(var.name=c("l1","l2"),
        #             x.i=test.dat[c(i,j),"y"],
        #             u.i=test.dat[c(i,j),"uc"],
        #             nu.i=test.dat[c(i,j),"nu.eff"],
        #             measurement.fnc="l1-l2")
        # 
        # consistency[[paste(i,j,sep="_")]] <- comp
        
        # Define CI i as A
        a.1 <- test.dat[i,"y"] - test.dat[i,"U"]
        a.2 <- test.dat[i,"y"] + test.dat[i,"U"]
        
        # Define CI j as B
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
    consistency <- GUM(var.name=c("l1","l2"),
                       x.i=test.dat[,"y"],
                       u.i=test.dat[,"uc"],
                       nu.i=test.dat[,"nu.eff"],
                       measurement.fnc="l1-l2")
    if(consistency$y-consistency$U<0 & consistency$y+consistency$U>0){
      cat(paste(test,"is consistent\n"))
    }
    else{
      cat(paste(test, "is NOT consistent \n"))
    }
  }
}
print("-------------Results-------------")


for(test in test.types){
  test.dat<- df[grepl(test,rownames(df)),] 
  cat(paste(test, "& $", signif(1000*test.dat[1,"y"],4), "\\pm", signif(1000*test.dat[1,"U"],2), "$ & $",
            signif(1000*test.dat[2,"y"],4), "\\pm", signif(1000*test.dat[2,"U"],2), "$ & $", 
            signif(1000*test.dat[3,"y"],4), "\\pm", signif(1000*test.dat[3,"U"],2), "$ \\\\ \\hline \n" ))
}
