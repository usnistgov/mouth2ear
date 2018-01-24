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
# Import functions from extra_functions.R
source("extra_functions.R")
# Initialize information for each set of tests

oneLoc <- list(
  name = "One Location Lab",
  path = "D:/MCV/Processed-data/1loc/delay_values",
  tests = c(
    "1loc-device-characterization",
    "p25-lab-wired-UHF-Direct-1loc",
    "p25-lab-wired-UHF-Trunked-1loc",
    "p25-lab-wired-VHF-Direct-1loc",
    "p25-lab-wired-VHF-Trunked-1loc"
  ),
  bad.Trials = c(NA, # characterization
                 NA, # uhf direct
                 t(data.frame(249:250)), # uhf trunked
                 NA, # vhf direct
                 NA # vhf trunked
  ),
  thinning = c(3, # characterization
               4, # uhf direct
               2, # uhf trunked
               5, # vhf direct
               4 # vhf trunked
  )
)

twoLoc.lab <- list(
  name = "Two Location Lab",
  path = "D:/MCV/Processed-data/2loc/delay_values",
  tests = c(
    "p25-lab-characterization-2loc",
    "p25-lab-wired-UHF-Direct-2loc",
    "p25-lab-wired-UHF-Trunked-2loc",
    "p25-lab-wired-VHF-Direct-2loc",
    "p25-lab-wired-VHF-Trunked-2loc"
  ),
  bad.Trials = c(NA, # characterization
                 NA, # uhf direct
                 NA, # uhf trunked
                 NA, # vhf direct
                 NA # vhf trunked
  ),
  thinning = c(4, # characterization
               4, # uhf direct
               4, # uhf trunked
               4, # vhf direct
               3 # vhf trunked
  )
  
)
#
# twoLoc.field <- list(name="Two Location Field",
#                      path="D:/MCV/Processed-data/2loc/delay_values",
#                      tests=c("p25-lab-characterization-2loc",
#                                 "US36-pullout-UHF-direct",
#                                 "US36-pullout-UHF-trunked",
#                                 "VHF-direct-NCAR",
#                                 "US36-pullout-VHF-trunked"),
#                      bad.Trials= c(NA, # characterization
#                                    NA, # uhf direct
#                                    NA, # uhf trunked
#                                    NA, # vhf direct
#                                    NA # vhf trunked
#                                    )
#                      )

# all.setups <- list(oneLoc, twoLoc.lab, twoLoc.field)
all.setups <- list(oneLoc, twoLoc.lab)
# all.setups <- list(oneLoc)
# all.setups <- list(twoLoc.lab)
setup.data <- list()

# thinning factor
thin.factor <- 5
show.plots <- F

# Measurement resolution
meas.res <- 0.125e-3

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
    s.c <- 1
    
    session.uncertainties <- list()
    for (session in session.files) {
      # Load in raw data from csv file
      session.data.raw <-
        read.csv(paste(dat.Path, "/", session, sep = ""), header = F)
      
      # Find trial means
      trial.m <- rowMeans(session.data.raw)
      # trial.m <-
        # trial.m[seq(from = 1,
                    # to = length(trial.m),
                    # by = setup$thinning[ix])]
      # Remove bad trials
      if(!is.na(setup$bad.Trials[ix])){


        bt.sesh <- ceiling(setup$bad.Trials[ix]/length(trial.m))
        if(bt.sesh == s.c){
          bt.trial <- setup$bad.Trials %% length(trial.m)
          trial.m[bt.trial]<- NA
        }
      }
      
      # Store row means in session.data
      session.data[[gsub(".csv", "", session)]] <- trial.m
      
      # Find autocorrelation info
      autocorr <- autocorr.unc(trial.m)
      
      # Store session uncertainties
      session.uncertainties[[gsub(".csv","", session)]] <- autocorr$u
      
      # Print lags
      # print(paste("---- Lag:", autocorr$lag))
      
      plot.name <- paste(test, session)
      plot.name <- gsub(".csv", "", plot.name)
      plot.name <- gsub("p25-lab-", "", plot.name)
      plot.name <- gsub("-", " ", plot.name)
      plot.name <- gsub("session_", "", plot.name)
      
      if (show.plots) {
        fplot <- acf.adj(autocorr,
                         plot.title = plot.name,
                         show.plot = FALSE)
        plot.list[[plot.name]] <- fplot
      }
      
      s.c <- s.c + 1
    }
    # Store test data
    test.data[[test]] <- session.data
    ix = ix + 1
    
    test.uncertainty <- GUM(var.name=c(paste("s",1:length(session.uncertainties),sep=""),"d"),
                            x.i=c(unlist(lapply(session.data,mean)),0),
                            u.i=c(unlist(session.uncertainties),meas.res/sqrt(12)),
                            nu.i=c(rep(length(trial.m)-1,length(session.uncertainties)),Inf),
                            measurement.fnc="d+0.25*(s1+s2+s3+s4)",
                            sig.digits.U = 6)
    
    test.valid <- GUM.validate(var.name=c(paste("s",1:length(session.uncertainties),sep=""),"d"),
                               x.i=c(unlist(lapply(session.data,mean)),0),
                               u.i=c(unlist(session.uncertainties),meas.res/sqrt(12)),
                               nu.i=c(rep(length(trial.m)-1,length(session.uncertainties)),Inf),
                               type=c(rep("A",length(session.uncertainties)),"B"),
                               distribution= c(rep("Normal",length(session.uncertainties)),"Uniform"),
                               measurement.fnc="d+0.25*(s1+s2+s3+s4)")
    
    # print(t(test.uncertainty[1:6]))
    # print(paste("Valid: ", test.valid))
    unit.shift <- 1000
    print(paste(prettyNum(unit.shift*test.uncertainty$y,digits=5,format="fg"), "+-", prettyNum(unit.shift*test.uncertainty$U,digits=2,format="fg"), "ms"))
    print("******************************************")
    
  }
  # Store setup data
  setup.data[[gsub(" ", ".", setup$name)]] <- test.data
  if (show.plots) {
    multiplot(plotlist = plot.list, cols = 5)
  }
}
