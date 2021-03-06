
saccadesAnalyser <- function(saccades, eventMarkerNames, settings, grNums)
{
  sacParams <- data.frame(eventNum = NA, valCode = NA, prevEventNum = NA,
                          prevEvent = factor(NA, levels = c(eventMarkerNames$fixation, eventMarkerNames$saccade,
                                                            eventMarkerNames$glissade, eventMarkerNames$smoothPursuit, 
                                                            eventMarkerNames$gap, eventMarkerNames$artifact)),
                          startPositionX = NA, startPositionY = NA, 
                          endPositionX = NA, endPositionY = NA,
                          onset = NA, offset = NA, duration = NA, 
                          amplitudeX = NA, amplitudeY = NA, amplitude = NA,
                          peakVelocity = NA, peakAcceleration = NA, asymmetry = NA, length = NA,
                          curvature = NA, orientXAxis = NA)
  for (i in 1:length(saccades))
  {
    eventNum <- as.numeric(names(saccades[i]))
    if (eventNum == 1)
    {
      prevGroup <- NA
      prevEventNum <- NA
      prevEvent <- NA
    }
    else
    {
      prevGroup <- eventNum - 1
      foundGroups <- lapply(grNums, FUN = function(x) 
      {
        which(lapply(x, FUN = function(x) {any(x == prevGroup)}) == T)
      }
      )
      if (length(which(lapply(foundGroups, length) != 0) != 0))
      {
        prevEventNum <- as.numeric(names(foundGroups[[which(lapply(foundGroups, length) != 0)]]))
        prevEvent <- names(which(lapply(foundGroups, length) != 0))
      }
      else
      {
        prevEventNum <- NA
        prevEvent <- NA
      }
    }
    
    if (any(saccades[[i]]$evm == "GAP"))
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
      startPositionX <- saccades[[i]]$x[1]
      # startPositionY - ��������� ������������ ������� ����� � ��������
      startPositionY <- saccades[[i]]$y[1]
      # startPositionX - �������� �������������� ������� ����� � ��������
      endPositionX <- saccades[[i]]$x[nrow(saccades[[i]])]
      # startPositionY - �������� ������������ ������� ����� � ��������
      endPositionY <- saccades[[i]]$y[nrow(saccades[[i]])]
      # amplitudeX - �������� �������� ������� ����� �� X � ��������
      amplitudeX <- abs(endPositionX - startPositionX)
      # amplitudeY - �������� �������� ������� ����� �� Y � ��������
      amplitudeY <- abs(endPositionY - startPositionY)
      # amplitudeY - �������� �������� ������� ����� �� ��������� ����� �� �������� ����� � ��������
      amplitude <- sqrt(amplitudeX^2 + amplitudeY^2)
      # length - ����� ����� ���� � ��������
      length <- sum(sqrt((saccades[[i]]$x[-1]-saccades[[i]]$x[-length(saccades[[i]]$x)])^2 + (saccades[[i]]$y[-1]-saccades[[i]]$y[-length(saccades[[i]]$y)])^2))
      # length <- sum(saccades[[i]]$dls)
      # curvature - �������� �������:
      # ������������� - ����� �������, ������� �� � ���������
      ## ����� ����������� � ����� ������� ������:
      ## ��. http://www.citr.auckland.ac.nz/~rklette/Books/MK2004/pdf-LectureNotes/22slides.pdf, page 9 
      curvature <- length/amplitude
    }
    else
    {
      position <- calcAngPos(saccades[[i]]$x, saccades[[i]]$y, 
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
      #length <- sum(saccades[[i]]$dls)
      curvature <- length/amplitude
    }
    # onset - ����� ������ �������
    onset <- saccades[[i]]$t[1]
    # offset - ����� ��������� �������
    offset <- saccades[[i]]$t[nrow(saccades[[i]])]
    # duration - ������������ �������
    duration <- offset - onset
    # peakVelocity - ������������ ��������
    peakVelocity <- max(saccades[[i]]$vel)
    # peakAcceleration - ������������ ���������
    peakAcceleration <- max(abs(saccades[[i]]$accel))
    # asymmetry - ����������� ����������������� ��� ��������� � ���������� �� ����� �������
    asymmetry <- sum(saccades[[i]]$dts[which(saccades[[i]]$accel > 0)])/sum(saccades[[i]]$dts[which(saccades[[i]]$accel < 0)])
    # orientation - ����, ������������ ����� ������, ����������� ����� ������ � ����� �������, � ���� X
    dy <- saccades[[i]]$y[1] - saccades[[i]]$y[nrow(saccades[[i]])]
    dx <- saccades[[i]]$x[nrow(saccades[[i]])] - saccades[[i]]$x[1]
    orientXAxis <- atan2(y = dy, x = dx) * (180/pi)
    sacParams <- rbind(sacParams, list(eventNum, valCode, 
                                       prevEventNum, prevEvent, 
                                       startPositionX, startPositionY, 
                                       endPositionX, endPositionY,
                                       onset, offset, duration,
                                       amplitudeX, amplitudeY, amplitude,
                                       peakVelocity, peakAcceleration, asymmetry, length,
                                       curvature, orientXAxis))
  }
  return(sacParams)
}

eventGroupsAnalyser <- function(eventGroups, eventMarkerNames, settings)
{
  fixations <- eventGroups$fixationGroups
  saccades <- eventGroups$saccadeGroups
  glissades <- eventGroups$glissadeGroups
  smoothPursuits <- eventGroups$smoothPursuitGroups
  gaps <- eventGroups$gapGroups
  artifacts <-  eventGroups$artifactGroups
  
  if (!is.na(fixations)[1]) {fixGrNums <- lapply(fixations, FUN = function(x) {unique(x$gr)})} else {fixGrNums <- list()}
  if (!is.na(saccades)[1]) {saccGrNums <- lapply(saccades, FUN = function(x) {unique(x$gr)})} else {saccGrNums <- list()}
  if (!is.na(glissades)[1]) {glisGrNums <- lapply(glissades, FUN = function(x) {unique(x$gr)})} else {glisGrNums <- list()}
  if (!is.na(smoothPursuits)[1]) {smPurGrNums <- lapply(smoothPursuits, FUN = function(x) {unique(x$gr)})} else {smPurGrNums <- list()}
  if (!is.na(gaps)[1]) {gapGrNums <- lapply(gaps, FUN = function(x) {unique(x$gr)})} else {gapGrNums <- list()}
  if (!is.na(artifacts)[1]) {artGrNums <- lapply(artifacts, FUN = function(x) {unique(x$gr)})} else {artGrNums <- list()}
  grNums <- list(fixGrNums, saccGrNums, glisGrNums, smPurGrNums, gapGrNums, artGrNums)
  names(grNums) <- c(eventMarkerNames$fixation, eventMarkerNames$saccade, 
                     eventMarkerNames$glissade, eventMarkerNames$smoothPursuit, 
                     eventMarkerNames$gap, eventMarkerNames$artifact)
  
  # fixations parameters estimation stage
  fixParams <- fixationsAnalyser(fixations, eventMarkerNames, settings, grNums)
  
  # saccades parameters estimation stage
  sacParams <- saccadesAnalyser(saccades, eventMarkerNames, settings, grNums)
  
  return(list(f = fixParams[-1,], 
              s = sacParams[-1,]))
  #               g = glisParams[-1,], 
  #               sp = smoothPurParams[-1,], 
  #               g = gapParams[-1,], 
  #               a = artParams[-1,]))
}



res <- eventGroupsAnalyser(eventGroups = events@analysisResults$leftEventData,
                           eventMarkerNames = events@eyesDataObject@leftEventMarkers@markerNames,
                           settings = list(angular = T,
                                           screenDist = 70,
                                           screenDim = c(1280, 1024),
                                           screenSize = c(33.7, 27)))
hist(res$s$curvature, breaks = 100)