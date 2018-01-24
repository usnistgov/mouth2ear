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

# Variables to keep at end of script
keep.data <- c("all.setups","setup.data","test.GUM","df","test.autocorr","no.lag.oneloc","no.lag.twoloc")

# Show Autocorrelation plots or not
show.plots <- T

# Initialize information for each set of tests

oneLoc <- list(
  name = "One Location Lab",
  path = "C:/Users/jkp4/Documents/MCV/M2E-Latency/DelayValues/Data-files/1loc/delay_values",
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
               5, # uhf trunked
               5, # vhf direct
               4 # vhf trunked
               )
  )
  
  twoLoc.lab <- list(
    name = "Two Location Lab",
    path = "C:/Users/jkp4/Documents/MCV/M2E-Latency/DelayValues/Data-files/2loc/delay_values",
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
    
    
    # Initialize list of all setups to run uncertainty analysis on
    all.setups <- list(oneLoc, twoLoc.lab)
    
    # Initialize empty list to store delay values in
    setup.data <- list()
    # Initialize empty list to store GUM output in
    test.GUM <- list()
    
    # Intialize list to save test autocorrelation information
    test.autocorr <- list()
    
    # Measurement resolution
    meas.res <- 0.125e-3
    
    # Flag for if any sessions had lag
    no.lag.oneloc <- TRUE
    no.lag.twoloc<-TRUE
    for (setup in all.setups) {
      print(paste("-----------------", setup$name, "-----------------"))
      # Initialize list to store test data (stores each session individually)
      test.data <- list()
      # List to store autocorrelation plot objects in
      plot.list <- list()
      
      
      # index for referencing thinning or bad trial information
      ix = 1
      for (test in setup$tests) {
        # Display thinning factor for each test
        print(paste(test, "Thin:", setup$thinning[ix]))
        # Path to session files
        dat.Path <- paste(setup$path, "/", test, sep = "")
        # Find session files in path
        session.files <- list.files(dat.Path)
        # Initialize list to store individual session data
        session.data <- list()
        # Variable to identify session in which bad trial occurred
        s.c <- 1
        # Iniitialize list to store session uncertainty information
        session.unc <- list()
        
        # Initialize list to store autocorrelation information
        session.autocorr<- list()
        
        for (session in session.files) {
          # Load in raw data from csv file
          session.data.raw <-
            read.csv(paste(dat.Path, "/", session, sep = ""), header = F)
          
          # Find trial means
          trial.m <- rowMeans(session.data.raw)
          # Thin data by thinning factor
          trial.m <-
            trial.m[seq(from = 1,
                        to = length(trial.m),
                        by = setup$thinning[ix])]
          # # Remove bad trials (If doing with thinning, make sure spacing between trials consistent)
          # if(!is.na(setup$bad.Trials[ix])){
          #
          #
          #   bt.sesh <- ceiling(setup$bad.Trials[ix]/length(trial.m))
          #   if(bt.sesh == s.c){
          #     bt.trial <- setup$bad.Trials %% length(trial.m)
          #     trial.m[bt.trial]<- NA
          #   }
          # }
          
          # Store row means in session.data
          session.data[[gsub(".csv", "", session)]] <- trial.m
          
          # Find autocorrelation info
          autocorr <- autocorr.unc(trial.m)
          
          # Store session uncertainties
          session.unc[[gsub(".csv","", session)]] <- autocorr$u
          
          # Store session autocorrelation
          session.autocorr[[gsub(".csv","",session)]] <- autocorr
          
          # # Print lags
          # print(paste("---- Lag:", autocorr$lag))
          if(autocorr$lag>0){
            print(paste("Bad lag", test))
            if(grepl("1loc",test)){
              print("*******************FLAGGED*******************")
            no.lag.oneloc<-FALSE
            }
            else{
              no.lag.twoloc<-FALSE
            }
          }

          # Initialize plot name
          plot.name <- paste(test, session)
          # Clean plot names
          plot.name <- gsub("session_", "", gsub("-"," ", gsub("p25-lab-", "", gsub(".csv", "", plot.name))))
          
          
          if (show.plots) {
            # Create autocorrelation plot
            fplot <- acf.adj(autocorr,
                             plot.title = plot.name,
                             show.plot = FALSE)
            # Store plot information
            plot.list[[plot.name]] <- fplot
          }
          # Increment session
          s.c <- s.c + 1
        }
        # Store test data
        test.data[[test]] <- session.data
        
        # Store autocorrelation data
        test.autocorr[[test]] <- session.autocorr
        # Increment test index
        ix = ix + 1
        
        # define number of sessions
        n <- length(session.unc)
        
        if(grepl("characterization",test)){
          # GUM for device characterization tests
          # Define measurement equation as measurement resolution (d) plus the mean delay over all sessions
          meas.fnc <- paste("d+1/", n, "*(", paste("s",1:n, sep="", collapse="+"), ")", sep="")
          
          # Use GUM to find uncertainty and additional uncertainty properties
          test.uncertainty <- GUM(var.name=c(paste("s",1:length(session.unc),sep=""),"d"),
                                  x.i=c(unlist(lapply(session.data,mean)),0),
                                  u.i=c(unlist(session.unc),meas.res/sqrt(12)),
                                  nu.i=c(rep(length(trial.m)-1,length(session.unc)),Inf),
                                  measurement.fnc=meas.fnc)
          
          # Run validation check (via Monte Carlo simulations) to see how well 95% Confidence Level achieved by GUM approximation
          test.uncertainty$valid <- GUM.validate(var.name=c(paste("s",1:length(session.unc),sep=""),"d"),
                                     x.i=c(unlist(lapply(session.data,mean)),0),
                                     u.i=c(unlist(session.unc),meas.res/sqrt(12)),
                                     nu.i=c(rep(length(trial.m)-1,length(session.unc)),9999),
                                     type=c(rep("A",length(session.unc)),"A"),
                                     distribution= c(rep("Normal",length(session.unc)),"Uniform"),
                                     measurement.fnc=meas.fnc)
          # Initialize temporary vector
          tmp.vec<-as.data.frame(test.uncertainty$contributions)
          # Add new factor to uncertainty contributions
          tmp.vec[["c"]]<-NA
          # Update uncertainty contributions
          test.uncertainty$contributions<-as.matrix(tmp.vec)
          
          # Initialize temporary vector
          tmp.vec<-as.data.frame(test.uncertainty$sensitivities)
          # Add new factor to uncertainty sensitivities
          tmp.vec[["c"]]<-NA
          
          # Update uncertainty sensitivities
          test.uncertainty$sensitivities<-as.matrix(tmp.vec)
          
          
        }
        else{
          # GUM for Device test
          # Define system latency
          # Find characterizaion test name
          test.character <- setup$tests[grepl("characterization",setup$tests)]
          
          # Find GUM ouptut for characterization test
          GUM.character <- test.GUM[[test.character]]
          
          # Define measurement equation as measurement resolution (d) plus the mean delay over all sessions minus system latency (c)
          meas.fnc <- paste("d+1/", n, "*(", paste("s",1:n, sep="", collapse="+"), ") - c", sep="")
          
          # Use GUM to find uncertainty and additional uncertainty properties
          test.uncertainty <- GUM(var.name=c(paste("s",1:length(session.unc),sep=""),"d","c"),
                                  x.i=c(unlist(lapply(session.data,mean)),0,GUM.character$y),
                                  u.i=c(unlist(session.unc),meas.res/sqrt(12),GUM.character$u),
                                  nu.i=c(rep(length(trial.m)-1,length(session.unc)),Inf, GUM.character$nu.eff),
                                  measurement.fnc=meas.fnc)
          
          # Run validation check (via Monte Carlo simulations) to see how well 95% Confidence Level achieved by GUM approximation
          test.uncertainty$valid <- GUM.validate(var.name=c(paste("s",1:length(session.unc),sep=""),"d", "c"),
                                     x.i=c(unlist(lapply(session.data,mean)),0, GUM.character$y),
                                     u.i=c(unlist(session.unc),meas.res/sqrt(12),GUM.character$u),
                                     nu.i=c(rep(length(trial.m)-1,length(session.unc)),9999,GUM.character$nu.eff),
                                     type=c(rep("A",length(session.unc)),"A","A"),
                                     distribution= c(rep("Normal",length(session.unc)),"Uniform","Normal"),
                                     measurement.fnc=meas.fnc)
          
        }
        # Remove msgs from list
        test.uncertainty$msgs<-NULL
        # Store test uncertainty
        test.GUM[[test]] <- test.uncertainty
        
      }
      # Store setup data
      setup.data[[gsub(" ", ".", setup$name)]] <- test.data
      if (show.plots) {
        if(no.lag.oneloc){
          filename<-paste(setup$name,"ACF thinned well.png")
        }
        else{
          print("yooooooooooooooooooooooooooooo")
          filename<-paste(setup$name,"ACF_thinned_poor.png")
        }
        
        if(no.lag.twoloc){
          filename<-paste(setup$name,"ACF thinned well.png")
        }
        else{
          filename<-paste(setup$name,"ACF_thinned_poor.png")
        }
        pic.scale<-3
        png(filename = filename,height=pic.scale*800,width=1600*pic.scale)
        # Create multiplot of all autocorrelation plots
        multiplot(plotlist = plot.list, cols = 5)
        dev.off()
      }
    }

    
    # Store GUM output as dataframe
    df <- data.frame(matrix(unlist(test.GUM),ncol=length(unlist(test.GUM$`1loc-device-characterization`)),byrow=T),stringsAsFactors = T)
    colnames(df) <- names(unlist(test.GUM$`1loc-device-characterization`))
    rownames(df) <- names(test.GUM)
    
    # print(df)
    print(df[c("y","uc","nu.eff","k","U","valid")])
    
    cat("\n-----------Checking consistency between one and two location tests-----------\n")
    # Compare between tests
    test.types<-c("UHF-Direct","UHF-Trunked","VHF-Direct","VHF-Trunked")
    for (test in test.types){
     test.dat<- df[grepl(test,rownames(df)),] 
     
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
    
    # Remove unnecessary data 
    rm(list = setdiff(ls(),keep.data))
    
    