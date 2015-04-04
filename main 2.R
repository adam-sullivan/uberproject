# main.R 
# Script: Main API call for the Uber-Nashville package
# Author: Adam Sullivan
# Date: 4/3/15
# Rev 1

################
# Load external dependencies
library(plyr)
library(geosphere)
require(e1071)
require(caret)
require(mlogit)
require(clue)

install('uberdata/')
# Load functions
#setwd('Documents/uberproject')
#source('src/dataPreprocess.R')
#source('src/featureEngineering.R')
#source('src/Prediction.R')


# External arguments
trainMode <- TRUE
apiMode <- FALSE
saveResults <- TRUE
NUMCENTERS = 32
testFile <- 'data/hw1_test.csv'
resourceModel <- 'outputs/bestModel.Rda'
resultsFile <- "outputs/confusionMatrix.txt"



####### 
# Load in the data files

if (trainMode){
  trainData <- preprocessData('data/hw1_train.csv')
  testData <- preprocessData('data/hw1_test.csv')
  featureList <- featureEngineering(trainData,truncatedData = TRUE)
  trainFeatures <- featureList$tripData
  kmeansObject <- featureList$clusterData
  testFeatures <- featureEngineering(tripData = testData
                                     ,truncatedData = TRUE
                                     , newKmeans = kmeansObject)$tripData
  bestModel <- naiveBayesModel(trainFeatures)
  if(saveResults){
    save(bestModel,kmeansObject,file='outputs/bestModel.Rda')
  }
}



if (apiMode){
  load(resourceModel)
  testData <- preprocessData(testFile)
  testFeatures <- featureEngineering(tripData = testData,truncatedData = TRUE,newKmeans = kmeansObject)$tripData
  
}

nUsers <- length(unique(testData$uid))
tripFreq <- count(testData, .(uid))

confusionResults <- naiveBayesTimeAnalysis(bestModel, testFeatures)
sink(file=resultsFile)
confusionResults
Sys.time()
nUsers
sink(NULL)

# Summary statistics


