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
  #' process.sessions perform uncertainty analysis and report results for list of M2E latency tests
  #'
  #'   process.sessions(all.setups) performs uncertainty analysis on the input test data in accordance with the Guide to the expression of uncertainty of measurement, GUM. Relies on the 
  #'   functions GUM and GUM.validate from the metRology package.
  #'
  #'   process.sessions(all.setups, show.lags = T) prints the maximum lag for which significant autocorrelation is present for each session of each test.
  #'   
  #' @param   \code{show.lags}     \emph{logical.}              Informs whether or not to print the maximum lag for which significant autocorrelation is present for each session of each test
  #' @param   \code{all.setups}    \emph{list.}                  List containing information for all tests. Further detailed below.
  #'
  #'   \code{name}          \emph{character.}             Name of test setup (i.e. Single Location Cabled Tests)
  #'
  #'   \code{path}          \emph{character.}             Path where csv files containing delay values for all tests of test setup contained. Expects each test in individual folder containing a csv file for each session.
  #'
  #'   \code{tests}         \emph{character vector.}      Vector of names of the specfic tests performed in the test setup (i.e. c("Device X Direct Mode", "Device X Trunked Mode", "Device Y Direct Mode")). Must match the folder names that contain the session csv files for that test.
  #'
  #'   \code{thinning}      \emph{numeric vector.}        Vector of degree to which the sessions of each test must be thinned to remove significant autocorrelation. For example given Device X Direct Mode must be thinned 
  #'                                       by using every third data point to eliminate significant autocorrelation, Device X Trunked must be thinned by using every fifth data point, and Device Y Direct 
  #'                                       Mode must be thinned by using every second data point then thinning would be c(3,5,2).
  #'                                       
  #' @return  A list containing the following components: 
  #' @return   \code{thinned.data}  \emph{list.}                  List with thinned data vectors for each session of each test of each test setup    
  #'
  #' @return   \code{gum.data}      \emph{list.}                  List with GUM output for each session of each test of each test setup
  #'
  #' @return   \code{df}            \emph{data.frame.}           Dataframe with GUM() output for all tests
  #'
  #' @return   \code{autocorr.data} \emph{list.}                  List with autocorr.unc() output for each session of each test of each setup
  
  
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

#========================================================================================================================================================================

acf.adj <- function(autocorr,plot.title = "",lag.max=NULL,show.plot=TRUE){
  #' Plots estimates of autocorrelation generated from autocorr.unc()
  #'
  #' Similar to R default acf() function, can also plot arbitrary bound lines. Useful when plotting the cut off lag proposed by Zhang in Calculation of the uncertainty of the mean of autocorrelated measurements (2006).
  #'
  #' -------------------------Inputs-------------------------------------------
  #'   NAME          TYPE                  DESCRIPTION
  #'   autocorr      list                  Output of autocorr.unc(y) (see below), where y is a vector of the relevant data
  #'
  #'   plot.title    character             Title of the desired ACF plot
  #'
  #'   lag.max       Numeric               Maximum lag to be shown in ACF plot
  #'
  #'   show.plot     Boolean               Show plot in Rstudio window or not
  #'
  #' -------------------------Outputs-------------------------------------------
  #'   NAME          TYPE                  DESCRIPTION
  #'   fplot         ggplot                Plot object of ACF plot
  
  
  if(is.null(lag.max)){
    # If lag.max not set, initiate it to a quarter of the size of the data
    lag.max <- length(autocorr$rho)/4
  }
  # Set xvalues
  xvals <- 1:lag.max
  # Define sample
  sample <- autocorr$rho[xvals]
  # Define bound
  bound <- 1.96*autocorr$sigma[xvals]
  # Define normal bound
  norm.bnd <- 1.96/sqrt(length(autocorr$rho))
  
  # Define lag
  lag <- autocorr$lag
  
  # Initiate plot
  g <- ggplot() 
  # Plot
  fplot<- g + 
    # Plot autocorrelation bars
    geom_col(aes(x=xvals, y= sample)) +
    # Plot bound lines
    # geom_line(aes(x=xvals,y=bound,color="red"),linetype="dotted",size = 1.5) + geom_line(aes(x=xvals,y=-bound,color="red"),linetype="dotted",size=1.5) + 
    geom_line(aes(x=xvals,y=bound,color="red"),size = 1.5) + geom_line(aes(x=xvals,y=-bound,color="red"),size=1.5) + 
    # Plot normal bound lines
    geom_hline(yintercept=norm.bnd) + geom_hline(yintercept=-norm.bnd) +
    # Plot lag line
    geom_vline(xintercept=lag,color="blue") + 
    # Remove legend
    theme(legend.position = "none") +
    # plot title
    ggtitle(plot.title)+
    xlab("") + ylab("")
  if(show.plot){
    print(fplot)
  }
  return(fplot)
  
}
#========================================================================================================================================================================
autocorr.unc <- function(y) {
  #' Determine if data autocorrelated and calculate corrected uncertainty autocorrelated data
  #'
  #' -------------------------Inputs-------------------------------------------
  #'   NAME          TYPE                  DESCRIPTION
  #'   y             numeric vector        Vector of data on which to calculate sample autocorrelation and uncertainty
  #'
  #' -------------------------Outputs------------------------------------------
  #'   NAME          TYPE                  DESCRIPTION
  #'   u             Numeric               Uncertainty corrected for autocorrelation if significant autocorrelation detected
  #'
  #'   lag           Numeric               Maximum lag for which significant autocorrelation present (i.e. element k and element k+lag have significant autocorrelation)
  #'
  #'   rho           Numeric vector        Sample autocorrelation
  #'
  #'   sigma         Numeric Vector        Sample autocorrelation variance estimator
  #'
  #'   r             Numeric               Ratio between uncertainty of corrected uncertainty versus uncorrected uncertainty
  #'
  #'---------------- Referenced equations from---------------------------------
  #' Zhang NF (2006) Calculation of the uncertainty of the mean of autocorrelated measurements. Metrologia 43(4):S276. URL https://stacks.iop.org/0026-1394/43/i=4/a=S15
  
  
  
  # remove na values from y
  y <- y[!is.na(y)]
  
  # Calculate the standard deviation of y, na values removed
  s.y <- sd(y, na.rm = T)
  
  # sample mean of y
  m.y <- mean(y, na.rm = T)
  
  # length of y
  n <- length(y)
  
  # initialize sample autocorrelation vector of na
  rho <- c(rep(NA, n))
  
  # sample autocorrelation variance estimator
  sigma <- c(rep(NA, n))
  
  for (i in 1:n) {
    sv <- 0
    
    if (i<n) {
      for (k in (1:(n - i))) {
        # NOTE: bug here when i==n, then k is in c(1,0)...need some way to stop this...
        sv <- sv + (y[k] - m.y) * (y[k + i] - m.y)
      }
    }
    # sample autocorrelation from equation 10
    rho[i] <- sv / ((n - 1) * s.y ^ 2)
    
    
    # Sample autocorrelation variance estimator (equation 17)
    if (i == 1) {
      sigma[i] <- 1 / sqrt(n)
    }
    else{
      sigma[i] <- sqrt((1 + 2 * sum(rho[1:(i - 1)] ^ 2)) / n)
    }
    
  }
  
  # Cut off lag, equation 16
  lim <- which(abs(rho) > 1.96 * sigma)
  
  # If no autocorrelation, return normal uncertainty
  if (length(lim) > 0) {
    n.c <- lim[length(lim)]
  }
  else{
    n.c <- 0
    u <- s.y / sqrt(n)
    lag <- 0
    r <- 1
    return(list(
      u = u,
      lag = lag,
      rho = rho,
      sigma = sigma,
      r = r
    ))
  }
  # Upper bound, equation 17
  lag <- min(c(n.c, floor(n / 4)))
  dv = seq(n - 1, n - lag, -1)
  # Ratio from equation 20
  r = 1 + 2 * (dv %*% rho[1:lag]) / n
  
  # uncertainty squared estimator equation 19
  u.2 <- r * (s.y ^ 2) / n
  
  # standard deviation estimator
  if(u.2>0){
    u <- sqrt(u.2)
  }
  else{
    u<- NaN
  }
  return(list(
    u = u,
    lag = lag,
    rho = rho,
    sigma = sigma,
    r = r
  ))
}
