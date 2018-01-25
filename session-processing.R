process.sessions <- function(varin){
  # process.sessions takes in a list of setups containing tests
  
  # variable containing setup information
  all.setups <- varin$all.setups
  
  # variable to determine if autocorrelation lags should be plotted
  show.lags <- varin$show.lags
  
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
  }
  
  
  # Store GUM output as dataframe
  df <- data.frame(matrix(unlist(test.GUM),ncol=length(unlist(test.GUM$`1loc-device-characterization`)),byrow=T),stringsAsFactors = T)
  colnames(df) <- names(unlist(test.GUM$`1loc-device-characterization`))
  rownames(df) <- names(test.GUM)
  
  # return data
  return(list(raw.data=setup.data,
              gum.data = test.GUM,
              df = df,
              autocorr.data = test.autocorr))
  
}

