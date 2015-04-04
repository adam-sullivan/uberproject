# feature Selection script
#
#

#' findDayOfWeek
#' 
#' This function takes a data frame and returns the 'day of the week'.
#' 
#' @param dataFrame a data frame with the date/time (as posixct) 
#' @return weekday returns the "Mon", "Tues", etc day of the week for a given date.
#' @export
#' 

findDayOfWeek <- function(dataFrame){
  # TODO: Make sure you have the required data frame format, else display error.
  return(weekdays(as.Date(dataFrame$begintrip_at)))
}

#' findClusteredLocations
#' 
#' This function takes every start and end location in the Uber data set 
#' and attempts to define k clusters (using kmeans).  The k clusters is defined
#' above, and defaulted to 32.  
#' 
#' @param dataFrame a data frame with the date/time (as posixct) 
#' @return cluster cluster locationdocu
#' 
#' @export
findClusteredLocations <- function(dataFrame, NUMCENTERS = 32){
  locClusters <-kmeans(rbind(cbind(dataFrame$begintrip_lat, dataFrame$begintrip_lng),
                             cbind(dataFrame$dropoff_lat, dataFrame$dropoff_lng)),
                       centers=NUMCENTERS)
  
  return(list(kmeansOb = locClusters, startClusters = locClusters$cluster[1:(length(locClusters$cluster)/2)],
              endClusters = locClusters$cluster[(length(locClusters$cluster)/2 + 1):
                                                  length(locClusters$cluster)]))
}


#' Distance calculation example
#' 
#' This function accepts a start lat/long and end lat/long and returns the Haversine distance.
#' There is an additional option to use a straight euclidean distance (not recommended).
#' @param distFrame a data frame that includes dropoff_lat/long, and begintrip_lat/long.
#' @return dist the haversine or euclidean distance, in meters
#' @examples
#' timeOfDayFnc(6)
#' # [1] "morning"
#' @export
#' 
#' 
calcTripDistance <- function(distFrame,type = 'haversine'){
  #distFrame <- testData
  ## TODO: Check that the names of the data frame are valid before proceeding.
  if(type == 'haversine'){
    library(geosphere)
    dist <- distHaversine(cbind(distFrame$dropoff_lat, distFrame$dropoff_lng),
                          cbind(distFrame$begintrip_lat, distFrame$begintrip_lng))
  }
  else if(type == 'euclid'){
    dist <- sqrt((distFrame$dropoff_lat - distFrame$begintrip_lat)^2 + 
                   (distFrame$dropoff_lng - distFrame$begintrip_lng)^2)
  }
  return(dist) 
}


#' Time of Day parser
#' 
#' This function takes in an hour and parses it into a categorical variable.
#' 
#' @param hourVal A stripped out single hour.
#' @return catHour A category of the 
#' @examples
#' timeOfDayFnc(6)
#' # [1] "morning"
#' @export
#' 
timeOfDayFnc <- function(tripFrame){
  catHour <- {}
  candidateHour <- as.numeric(tripFrame)  
  if(candidateHour > 6 & candidateHour <= 10){
    catHour <- "morning"
  }
  if (candidateHour > 10  & candidateHour <= 17){
    catHour <- "afternoon"
  }
  if (candidateHour > 17 & candidateHour <= 20){
    catHour <- "evening"
  }
  if (candidateHour > 20 | candidateHour <= 1){
    catHour <- "overnight"
  }
  if (candidateHour > 1 & candidateHour <= 6){
    catHour <- "earlyMorning"
  }
  return(catHour)
}


#' Feature Generation
#' 
#' Take a given data frame and produce a feature vector for each unique 
#' row.
#' 
#' @param tripData A data frame with dateTime, startLat/Long, stopLat/Long, and uid.
#' @param truncatedData An option to reduce the dimensionality of the return frame.
#' @return featureFrame A data frame with the equivalent features calcualted
#' @export
featureEngineering <- function(tripData,truncatedData,newKmeans = NULL){
  # Calculate the trip distance
  tripData <- tripData[tripData$dropoff_lng < 360,]
  tripData <- tripData[tripData$begintrip_lng < 360,]
  tripData$distance <- calcTripDistance(tripData,'haversine')
  
  # Parse the days and times into categorical variables
  tripData$day <- as.factor(findDayOfWeek(tripData))
  tripData$timeOfDay <- sapply(strftime(tripData$begintrip_at, format="%H"),timeOfDayFnc)
 
  # Depending on whether you're importing the kmeans object for new prediction, or making a new one
  # This will automatically create a new kmeans object if you don't supply one.
  if(is.null(newKmeans)){
  clusterData <- findClusteredLocations(tripData)
  } else {clusterData <- newKmeans}
  tripData$startCluster <- cl_predict(clusterData$kmeansOb,data.frame(tripData$begintrip_lat,tripData$begintrip_lng,check.names=TRUE))
  tripData$endCluster <- cl_predict(clusterData$kmeansOb,data.frame(tripData$dropoff_lat,tripData$dropoff_lng,check.names=TRUE))
  
  tripData$startCluster <- as.factor(tripData$startCluster)
  tripData$endCluster <- as.factor(tripData$endCluster)
  
  # Your trip history is important.  We want to know your dominant cluster, and how many times
  # you've visited your dominant cluster.  
  
  tripHistory <- ddply(.data=tripData,.(uid),summarise, numUniqueClusters= length(unique(startCluster)),
                       mostTripsToSingleCluster = max(table(startCluster)),
                       totalTrips = length(endCluster))
  tripData <- merge(tripData,tripHistory,by='uid')
  
  ## Cluster analysis 
  hclustData <- tripData[,names(tripData) %in% c("day","startCluster", "day","endCluster")]
  hclustData$day <- as.factor(hclustData$day)
  hclustData$startCluster <- as.factor(hclustData$startCluster)
  hclustData$endCluster <- as.factor(hclustData$endCluster)
  startClusterProps <- as.data.frame.matrix(prop.table(table(tripData$uid, tripData$startCluster),1))
  endClusterProps<- as.data.frame.matrix(prop.table(table(tripData$uid, tripData$endCluster),1))
  
  #### This analysis finds some global stats about each user.
  dayProps <- as.data.frame.matrix(prop.table(table(tripData$uid, tripData$day),1))
  dayProps$uid <- rownames(dayProps)
  timeProps <- as.data.frame.matrix(prop.table(table(tripData$uid, tripData$timeOfDay),1))
  timeProps$uid <- rownames(timeProps)
  startClusterProps$uid <- rownames(startClusterProps)
  endClusterProps$uid <- rownames(endClusterProps)
  mergedClusterStarts <- merge(startClusterProps,tripData)
  tripData <- merge(endClusterProps,mergedClusterStarts, by='uid')
  tripData <- merge(tripData, dayProps,by='uid')
  tripData <- merge(tripData, timeProps,by='uid')
  
  # The data frame to this point has a little bit more information than I need.
  # We can truncate the dataframe and reduce the dimensionality.  Also, make them factors.
  if(truncatedData){
    tripData <- tripData[,names(tripData) %in% c("uid","timeOfDay",
                                                 "day","startCluster",
                                                 "endCluster","numUniqueClusters")]
    tripData$timeOfDay <- as.factor(tripData$timeOfDay)
    tripData$day <- as.factor(tripData$day)
    tripData$startCluster <- as.factor(tripData$startCluster)
    tripData$endCluster <- as.factor(tripData$endCluster)
    tripData$uid <- as.factor(tripData$uid)
    tripData$numUniqueClusters <- as.factor(tripData$numUniqueClusters)
  }
  
  return(list(tripData = tripData, clusterData= clusterData))
  
  
}

