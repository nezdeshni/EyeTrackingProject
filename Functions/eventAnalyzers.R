analyzeFixation <- function(group, data, settings)
{
  if (group == 1)
  {
    prevEventGroup <- NA
  }
  prevEventGroup <- group - 1
  if (any(data$eventMarkers == "Gap"))
  {
    valCode <- 0
  }
  else
  {
    valCode <- 1
  }
  onset <- data$time[1]
  offset <- tail(data$time, 1)
  duration <- offset - onset
  if (!settings$angular)
  {
    startPositionX <- data$porx[1]
    startPositionY <- data$pory[1]
    endPositionX <- tail(data$porx, 1)
    endPositionY <- tail(data$pory, 1)
    positionX <- mean(data$porx)
    positionY <- mean(data$pory)
    dispersionX <- sd(data$porx)
    dispersionY <- sd(data$pory)
    radius <- mean(sqrt((positionX - data$porx)^2 + (positionY - data$pory)^2))
  }
  else
  {
    position <- calcAngPos(data$porx, data$pory, 
                           screenDist = settings$screenDist, 
                           screenDim = settings$screenDim, 
                           screenSize = settings$screenSize, 
                           refPoint = c(settings$screenDim[1]/2, settings$screenDim[2]/2))
    startPositionX <- position$xAng[1]
    startPositionY <- position$yAng[1]
    endPositionX <- position$xAng[length(position$xAng)]
    endPositionY <- position$yAng[length(position$yAng)]
    positionX <- mean(position$xAng)
    positionY <- mean(position$yAng)
    dispersionX <- sd(position$xAng)
    dispersionY <- sd(position$yAng)
    radius <- mean(sqrt((positionX - position$xAng)^2 + (positionY- position$yAng)^2))
  }
  if ("pupxsize" %in% colnames(data))
  {
    if ("pupysize" %in% colnames(data))
    {
      # estimate mean and sd of pupil size
      meanPupilSize <- (mean(data$pupxsize, na.rm = T) + mean(data$pupysize, na.rm = T))/2
      sdPupilSize <- (sd(data$pupxsize, na.rm = T) + sd(data$pupysize, na.rm = T))/2
    }
    else
    {
      # estimate mean and sd of pupil size
      meanPupilSize <- mean(data$pupxsize, na.rm = T)
      sdPupilSize <- sd(data$pupxsize, na.rm = T)
    }
  }
  else
  {
    meanPupilSize <- NA
    sdPupilSize <- NA
  }
  fixParams <- list(eventGroup = group, valCode = valCode, prevEventGroup = prevEventGroup, 
                    startPositionX = startPositionX, startPositionY = startPositionY,
                    endPositionX = endPositionX, endPositionY = endPositionY,
                    positionX = positionX, positionY = positionY,
                    dispersionX = dispersionX, dispersionY = dispersionY, radius = radius, 
                    onset = onset, offset = offset, duration = duration,
                    meanPupilSize = meanPupilSize, sdPupilSize = meanPupilSize)
  return(fixParams)
}

analyzeSaccade <- function(group, data, settings)
{
  if (group == 1)
  {
    prevEventGroup <- NA
  }
  prevEventGroup <- group - 1
  if (any(data$eventMarkers == "Gap"))
  {
    valCode <- 0
  }
  else
  {
    valCode <- 1
  }
  
  if (!settings$angular)
  {
    # startPositionX - ��������� �������������� ������� ����� � ��������
    startPositionX <- data$porx[1]
    # startPositionY - ��������� ������������ ������� ����� � ��������
    startPositionY <- data$pory[1]
    # startPositionX - �������� �������������� ������� ����� � ��������
    endPositionX <- tail(data$porx, 1)
    # startPositionY - �������� ������������ ������� ����� � ��������
    endPositionY <- tail(data$pory, 1)
    # amplitudeX - �������� �������� ������� ����� �� X � ��������
    amplitudeX <- abs(endPositionX - startPositionX)
    # amplitudeY - �������� �������� ������� ����� �� Y � ��������
    amplitudeY <- abs(endPositionY - startPositionY)
    # amplitudeY - �������� �������� ������� ����� �� ��������� ����� �� �������� ����� � ��������
    amplitude <- sqrt(amplitudeX^2 + amplitudeY^2)
    # length - ����� ����� ���� � ��������
    length <- sum(sqrt((data$porx[-1]-data$porx[-length(data$porx)])^2 + (data$pory[-1]-data$pory[-length(data$pory)])^2))
    # curvature - �������� �������:
    # ������������� - ����� �������, ������� �� � ���������
    ## ����� ����������� � ����� ������� ������:
    ## ��. http://www.citr.auckland.ac.nz/~rklette/Books/MK2004/pdf-LectureNotes/22slides.pdf, page 9 
    curvature <- length/amplitude
    vels <- calcPxVel(t = data$time, x = data$porx, y = data$pory)$vels
  }
  else
  {
    position <- calcAngPos(data$porx, data$pory, 
                           screenDist = settings$screenDist, 
                           screenDim = settings$screenDim, 
                           screenSize = settings$screenSize, 
                           refPoint = c(settings$screenDim[1]/2, settings$screenDim[2]/2))
    startPositionX <- position$xAng[1]
    startPositionY <- position$yAng[1]
    endPositionX <- position$xAng[length(position$xAng)]
    endPositionY <- position$yAng[length(position$yAng)]
    amplitudeX <- abs(endPositionX - startPositionX)
    amplitudeY <- abs(endPositionY - startPositionY)
    amplitude <- sqrt(amplitudeX^2 + amplitudeY^2)
    length <- sum(sqrt((position$xAng[-1]-position$xAng[-length(position$xAng)])^2 + (position$yAng[-1]-position$xAng[-length(position$yAng)])^2))
    curvature <- length/amplitude
    vels <- calcAngVel(t = data$time, x = data$porx, y = data$pory, 
                       screenDist = settings$screenDist, 
                       screenDim = settings$screenDim, 
                       screenSize = settings$screenSize)$vels
  }
  # onset - ����� ������ �������
  onset <- data$time[1]
  # offset - ����� ��������� �������
  offset <- tail(data$time, 1)
  # duration - ������������ �������
  duration <- offset - onset
  # peakVelocity - ������������ ��������

  peakVelocity <- max(vels)
  # peakAcceleration - ������������ ���������
  dts1 <- data$porx[-length(data$porx)]-data$porx[-1]
  dts2 <- dts1[-1] + dts1[-length(dts1)]
  dvs <- vels[-1] - vels[-length(vels)]
  accels <- dvs/dts2
  peakAcceleration <- max(accels)
  # asymmetry - ����������� ����������������� ��� ��������� � ���������� �� ����� �������
  asymmetry <- sum(dts[which(accel > 0)])/sum(dts[which(accel < 0)])
  # orientation - ����, ������������ ����� ������, ����������� ����� ������ � ����� �������, � ���� X
  dx <- tail(data$porx, 1) - data$porx[1]
  dy <- data$pory[1] - tail(data$pory, 1)
  orientXAxis <- atan2(y = dy, x = dx) * (180/pi)
  sacParams <- data.frame(eventGroup = NA, valCode = NA, prevEventGroup = NA,
                          startPositionX = NA, startPositionY = NA, 
                          endPositionX = NA, endPositionY = NA,
                          onset = NA, offset = NA, duration = NA, 
                          amplitudeX = NA, amplitudeY = NA, amplitude = NA,
                          peakVelocity = NA, peakAcceleration = NA, asymmetry = NA, length = NA,
                          curvature = NA, orientXAxis = NA)
}

standardAnalyzer <- function(data, eventMarkerNames, settings)
{
  sampleGroups <- split(data, data$eventGroups)
  fixationsParams <- list()
  saccadesParams <- list()
  for (gr in 1:length(sampleGroups))
  {
    if (sampleGroups[[gr]]$eventMarkers[1] == eventMarkerNames$fixation)
    {
      params <- analyzeFixation(group = names(sampleGroups[gr])[1], data = sampleGroups[[gr]], settings = settings)
      fixationsParams <- append(fixationsParams, params)
    }
    if (sampleGroups[[gr]]$eventMarkers[1] == eventMarkerNames$saccade)
    {
      params <- analyzeSaccade(group = names(sampleGroups[gr])[1], data = sampleGroups[[gr]], settings = settings)
      saccadesParams <- append(saccadesParams, params)
    }
  }
  return(f = fixationsParams, s = saccadesParams)
}

test <- getDataFrame(res@eyesDataObject, eye = "left")
test$eventGroups

## CORE ANALYZER ##
coreAnalyzer <- function(DataRecord, settings)
{
  if (DataRecord@eyesDataObject@conditions@conditions$eye == "left")
  {
    data <- getDataFrame(DataRecord, eye = "left")
    DataRecord@analysisResults$leftEventData <- standardAnalyzer(data, settings)
  }
  if (DataRecord@eyesDataObject@conditions@conditions$eye == "right")
  {
    data <- getDataFrame(DataRecord, eye = "right")
    DataRecord@analysisResults$rightEventData <- standardAnalyzer(data, settings)
  }
  if (DataRecord@eyesDataObject@conditions@conditions$eye == "both")
  {
    dataLeft <- getDataFrame(DataRecord, eye = "left")
    dataRight <- getDataFrame(DataRecord, eye = "right")
    DataRecord@analysisResults$leftEventData <- analyzer(dataLeft, settings)
    DataRecord@analysisResults$rightEventData <- analyzer(dataRight, settings)
  }
  return(DataRecord)
}
