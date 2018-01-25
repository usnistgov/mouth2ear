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


process.sessions <- function(all.setups,show.lags=F){
  # process.sessions perform uncertainty analysis and report results for list of M2E latency tests
  #
  #   process.sessions(all.setups) performs uncertainty analysis on the input test data in accordance with the Guide to the expression of uncertainty of measurement, GUM. Relies on the 
  #   functions GUM and GUM.validate from the metRology package.
  #
  #   process.sessions(all.setups, show.lags = T) prints the maximum lag for which significant autocorrelation is present for each session of each test.
  #
  # -------------------------Inputs-------------------------------------------
  #   NAME          TYPE                  DESCRIPTION
  #   all.setups    list                  List containing information for all tests. Further detailed below.
  #
  #   show.lags     Boolean               Boolean informing whether or not to print the maximum lag for which significant autocorrelation is present for each session of each test
  #
  # ----------Details on all.setups list elements:----------------------------
  #   NAME          TYPE                  DESCRIPTION
  #   name          character             Name of test setup (i.e. Single Location Cabled Tests)
  #
  #   path          character             Path where csv files containing delay values for all tests of test setup contained. Expects each test in individual folder containing a csv file for each session.
  #
  #   tests         character vector      Vector of names of the specfic tests performed in the test setup (i.e. c("Device X Direct Mode", "Device X Trunked Mode", "Device Y Direct Mode"))
  #
  #   thinning      numeric vector        Vector of degree to which the sessions of each test must be thinned to remove significant autocorrelation. For example given Device X Direct Mode must be thinned 
  #                                       by using every third data point to eliminate significant autocorrelation, Device X Trunked must be thinned by using every fifth data point, and Device Y Direct 
  #                                       Mode must be thinned by using every second data point then thinning would be c(3,5,2).
  #
  # -------------------------Outputs------------------------------------------
  #   NAME          TYPE                  DESCRIPTION
  #   thinned.data  list                  List with thinned data vectors for each session of each test of each test setup    
  #
  #   gum.data      list                  List with GUM output for each session of each test of each test setup
  #
  #   df            data.frame            Dataframe with GUM() output for all tests
  #
  #   autocorr.data list                  List with autocorr.unc() output for each session of each test of each setup
  

  # Initialize empty list to store delay values in
  setup.data <- list()
  # Initialize empty list to store GUM output in
  test.GUM <- list()
  
  # Intialize list to save test autocorrelation information
  test.autocorr <- list()
  
  # Measurement resolution
  meas.res <- 0.125e-3
  
  
  for (setup in all.setups) {
    print(paste("-----------------", setup$name, "-----------------"))
    # Initialize list to store test data (stores each session individually)
    test.data <- list()
    # List to store autocorrelation plot objects in
    plot.list <- list()
    
    
    # index for referencing thinning information
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

        
        # Store row means in session.data
        session.data[[gsub(".csv", "", session)]] <- trial.m
        
        # Find autocorrelation info
        autocorr <- autocorr.unc(trial.m)
        
        # Store session uncertainties
        session.unc[[gsub(".csv","", session)]] <- autocorr$u
        
        # Store session autocorrelation
        session.autocorr[[gsub(".csv","",session)]] <- autocorr
        
        # # Print lags
        if(show.lags){
          print(paste("---- Lag:", autocorr$lag))
        }
        
        if(autocorr$lag>0){
          # print(paste("Bad lag", test))
          print(paste("---- Lag:", autocorr$lag))
        }
        
        # Initialize plot name
        plot.name <- paste(test, session)
        # Clean plot names
        plot.name <- gsub("session_", "", gsub("-"," ", gsub("p25-lab-", "", gsub(".csv", "", plot.name))))
        

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
    
  }
  
  
  # Store GUM output as dataframe
  df <- data.frame(matrix(unlist(test.GUM),ncol=length(unlist(test.GUM$`1loc-device-characterization`)),byrow=T),stringsAsFactors = T)
  colnames(df) <- names(unlist(test.GUM$`1loc-device-characterization`))
  rownames(df) <- names(test.GUM)
  
  # return data
  return(list(thinned.data=setup.data,
              gum.data = test.GUM,
              df = df,
              autocorr.data = test.autocorr))
  
}

