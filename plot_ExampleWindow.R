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
print("Reading tx envelope")
tx.df <- scan("tx_env.csv",sep=",")
# rx.df<- read.csv("rx_env.csv")