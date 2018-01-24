acf.adj <- function(autocorr,plot.title = "",lag.max=NULL,show.plot=TRUE){
  # # Similar to acf() function, also plots arbitrary bound lines 
  # autocorr expected to be output from autocorr.unc
  
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


multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  # Multiple plot function
  #
  # ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
  # - cols:   Number of columns in layout
  # - layout: A matrix specifying the layout. If present, 'cols' is ignored.
  #
  # If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
  # then plot 1 will go in the upper left, 2 will go in the upper right, and
  # 3 will go all the way across the bottom.
  #
  
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

autocorr.unc <- function(y) {
  # Calculate uncertainty corrected for correlation within the data
  # Referenced equations from "Calculations of the uncertainty of mean of
  # autocorrelated measurements"
  
  # y is a vector of values on which to estimate the autocorrelation
  
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
