# Prediction.R
#
#
#' Naive Bayes Model
#' 
#' This function takes in a data frame and returns back a naive bayes model.
#' 
#' @param testTrip a data frame generated from the dataProcess functions.
#' @return nbModel The entire S3 object for the NB model
#' @export
naiveBayesModel <- function(testTrip){
  #TODO: Make the Laplace parameter programmable
  #TODO: Make the formula programmable
  nbModel <- naiveBayes(timeOfDay  ~ uid + day + numUniqueClusters + startCluster, data = testTrip,laplace = 10)
  return(nbModel)
}


#' naiveBayesTimeAnalysis
#' 
#' This function takes a model and testData, and returns a confusion matrix with 
#' corresponding classification errors..
#' 
#' @param model a naive bayes model
#' @param testData the input features from the testing data set.
#' @return cfMatrix The confusion matrix from the NB analysis.
#' @export
#' 
naiveBayesTimeAnalysis <- function(model, testData){
  require(e1071)
  nbPreds <- predict(model,testData)
  cfMatrix <- confusionMatrix(table(nbPreds, testData$timeOfDay))
  return(cfMatrix)
}


#' Bayesian Hiearchial multinomial logistic regression
#' 
#' Exploratory function.  No guarantee on code safety, included for demonstration.
#' This function was my top pick for being able to model the dropoff location.  
#' It creates a list structure (one for each unique ID) as the input and predictor variable.
#' The output is MCMC samples for the estimates for beta.
#' 
#' @param testTrip an input of the shortened feature vector
#' @return outMCMCs The multinomial Bayesian model chains for the estimates for beta.
#' 
#' 
#' @export
#' 
multinomialHierBayesModel <- function(testTrip){
  
  listOfUids <- unique(testTrip$uid)
  regdata <- NULL 
  for (i in 1:100) { 
    filter <- testTrip$uid==listOfUids[i] 
    y <- tabulate(testTrip$endCluster[filter],32)
    X <- cbind( 
      as.matrix(testTrip[filter,names(testTrip) %in% c("timeOfDay",
                                                       "day","startCluster","numUniqueClusters")]))
    regdata[[i]] <- list(y=y, X=X) 
  }
  
  mcmc <- list(R=1000,use=10)
  outMCMCs = rhierMnlRwMixture(Data=list(p=32,lgtdata = regdata), Mcmc = mcmc)
  return(outMCMCs)
  
}

#'  Multinomial logistic regression
#'  
#' This function is another exploratory attempt at using hiearachial logistic regression.
#' Using the endCluster's as the variable to be predicted, it's still exploratory and 
#' not to be used.
#' @param testTrip an input of the shortened feature vector
#' @return cModel The model S3 object.
#' 
#' @export
#' 
mlogitModel <- function(testTrip){
  # TODO: check that the testTrip frame works.
  require("nnet")
  summary(multinom(endCluster ~ startCluster, data = testTrip))
  
  tD <- mlogit.data(testTrip,choice="endCluster", shape='wide',id.var='uid')
  cModel <- mlogit(endCluster ~ 1 | timeOfDay + startCluster, tD)
  #cModel <- mlogit(endCluster ~ startCluster | startCluster, tD)
  myPreds <- predict(cModel,tD)
  mapPreds <- colnames(myPreds)[apply(myPreds,1,which.max)]
  return(cModel)
}



