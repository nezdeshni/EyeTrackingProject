# TO DO: evaluate closeness of fixations in space by center of their mass
IVT <- function(t, x, y, filterMarkers, settings)
{
  VT <- settings$VT
  angular <- settings$angular
  screenDist <- settings$screenDist
  screenDim <- settings$screenDim
  screenSize <- settings$screenSize
  MaxTBetFix <- settings$MaxTBetFix
  MaxDistBetFix <- settings$MaxDistBetFix
  minFixLen <- settings$minFixLen
  maxGapLen <- settings$maxGapLen 
  maxVel <- settings$maxVel
  maxAccel <- settings$maxAccel
  classifyGaps <- settings$classifyGaps
  
  # 1. Velocities and accelerations estimation
  if (!angular)
  {
    vel <- calcPxVel(t, x, y)
    vel$vels <- as.numeric(smooth(vel$vels, kind = "3"))
  } 
  else
  {
    vel <- calcAngVel(t, x, y, screenDist, screenDim, screenSize)
    vel$vels <- as.numeric(smooth(vel$vels, kind = "3"))
  }
  accels <- c(((vel$vels[-1]-vel$vels[-length(vel$vels)])/vel$dts[-length(vel$dts)]), 0)
  # 2. Classification stage: getting raw event markers
  gapMarkers <- ifelse(filterMarkers@filterMarkersData != filterMarkers@markerNames$ok, "GAP", "NOT GAP")
  rawEventMarkers <- ifelse(gapMarkers[-length(gapMarkers)] == "GAP", "GAP", ifelse(vel$vels <= VT, "Fixation", "Saccade"))
  # 3. Post-processing stage
  
  
  evmarks <- data.frame(firstEv = rawEventMarkers[-length(rawEventMarkers)], secondEv = rawEventMarkers[-1])
  transitions <- apply(evmarks, MARGIN = 1, function(x) {if (x[2] != x[1]) {1} else {0}})
  group <- c(1,cumsum(transitions)+1)
  events <- data.frame(t = t[-length(t)], x = x[-length(t)], y = y[-length(t)], dls = vel$dists, dts = vel$dts, vel = vel$vels, accel = accels, evm = rawEventMarkers, gr = group)
  eventGroups <- split(events, group)
  fixationGroups <- list()
  saccadeGroups <- list()
  gapGroups <- list()
  artifactGroups <- list()
  eventMarkers <- new(Class = "EventMarkers")
  eventMarkersGroups <- list()
  group <- 0
  newGroups <- c()
  newEvents <- c()
  lastGroup = NA
  for (gr in 1:length(eventGroups))
  {
    currentGroup <- eventGroups[[gr]]$evm[1]
    # ���� ������� ������ ������� - ��������
    if (currentGroup == "Fixation")
    {
      # �� ��������� � ������������
      fixLen <- eventGroups[[gr]]$t[nrow(eventGroups[[gr]])]-eventGroups[[gr]]$t[1]
      # ���� �������� ��������, �� ������������� � ��� ��������
      if (fixLen < minFixLen)
      {
        artifactGroups <- append(artifactGroups, eventGroups[gr])
        group <- group + 1
        newGroups <- c(newGroups, rep(group, nrow(eventGroups[[gr]])))
        newEvents <- c(newEvents, rep(eventMarkers@markerNames$artifact, nrow(eventGroups[[gr]])))
        #eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$artifact, nrow(eventGroups[[gr]])))
      }
      # ���� �������� �� ��������
      if (fixLen >= minFixLen)
      {
        anyGroupBefore <- !is.na(lastGroup)
        prevGroupIsSaccade <- F
        anyFixBefore <- F
        fixCloseInTime <- F
        fixCloseInSpace <- F
        
        if (anyGroupBefore) {prevGroupIsSaccade <- (lastGroup == "Saccade")}
        if (prevGroupIsSaccade) {anyFixBefore <- (length(fixationGroups) != 0)}
        if (anyFixBefore) 
        {
          fixTime <- eventGroups[[gr]]$t[1]
          lastFixation <- tail(fixationGroups, n = 1)[[1]]
          lastFixTime <- lastFixation$t[nrow(lastFixation)]
          fixCloseInTime <- (lastFixTime - fixTime <= MaxTBetFix)
        }
        if (fixCloseInTime) 
        {
          fixPos <- c(eventGroups[[gr]]$x[1], eventGroups[[gr]]$y[1])
          lastFixPos <- c(lastFixation$x[nrow(lastFixation)], lastFixation$y[nrow(lastFixation)])
          if (!angular)
          {
            pxVel <- calcPxVel(t = c(lastFixTime, fixTime),
                               x = c(lastFixPos[1], fixPos[1]),
                               y = c(lastFixPos[2], fixPos[2]))
            dist <- pxVel$dist
          }
          else
          {
            angVel <- calcAngVel(t = c(lastFixTime, fixTime), 
                                 x = c(lastFixPos[1], fixPos[1]), 
                                 y = c(lastFixPos[2], fixPos[2]),
                                 screenDist,
                                 screenDim,
                                 screenSize)
            dist <- angVel$dist
          }
          fixCloseInSpace <- (dist <= MaxDistBetFix)
        }
        if (fixCloseInSpace)
        {
          # �� ���������� ������� ������������� ��� �������� ������
          newEvents[tail(newEvents, nrow(saccadeGroups[[length(saccadeGroups)]]))] <- rep(nrow(eventMarkers@markerNames$artifact, saccadeGroups[[length(saccadeGroups)]]))
          artifactGroups <- append(artifactGroups, saccadeGroups[length(saccadeGroups)])
          eventMarkersGroups[length(eventMarkersGroups)] <- list(rep(eventMarkers@markerNames$artifact, length(eventMarkersGroups[[length(eventMarkersGroups)]])))
          saccadeGroups <- saccadeGroups[-length(saccadeGroups)]

          # � ������� �������� ������������� ��� ����������� ����������
          lastFixation <- list(rbind(lastFixation, eventGroups[[gr]]))
          fixationGroups[length(fixationGroups)] <- lastFixation
          lastGroup <- "Fixation"
          eventMarkersGroups <- append(eventMarkersGroups, list(rep(eventMarkers@markerNames$fixation, nrow(eventGroups[[gr]]))))
        }
        
        if (!anyGroupBefore | !prevGroupIsSaccade | !anyFixBefore | !fixCloseInTime | !fixCloseInSpace)
        {
          # �� ��������� ������ �������� ������� ���������
          fixationGroups <- append(fixationGroups, eventGroups[gr])
          lastGroup <- "Fixation"
          eventMarkersGroups <- append(eventMarkersGroups, list(rep(eventMarkers@markerNames$fixation, nrow(eventGroups[[gr]]))))
        }
      }
    }
    # ���� ������� ������ ������� - �������
    if (currentGroup == "Saccade")
    {
      # �� ��������� ��������� maxVel � maxAccel
      maxSaccadeVel <- max(eventGroups[[gr]]$vel)
      maxSaccadeAccel <- max(abs(eventGroups[[gr]]$accel))
      
      # � ���� ������� ��������� (�������� ������ � ����������� ���������� �������� ��� ���������), 
      # �� ��������� ������ ���������� ���� ��������
      if (maxSaccadeVel > maxVel | maxSaccadeAccel > maxAccel)
      {
        artifactGroups <- append(artifactGroups, eventGroups[gr])
        eventMarkersGroups <- append(eventMarkersGroups, list(rep(eventMarkers@markerNames$artifact, nrow(eventGroups[[gr]]))))
      }
      #	���� ������� �� ���������
      else
      {
        # �� ���� ���������� ������ - �������, �� ��������� ��������� ������� �������� ������� �������
        if (!is.na(lastGroup) & lastGroup == "Saccade")
        {
          lastSaccade <- list(rbind(saccadeGroups[[length(saccadeGroups)]], eventGroups[[gr]]))
          saccadeGroups[length(saccadeGroups)] <- lastSaccade
          lastGroup <- "Saccade"
          lastMarkers <- list(c(eventMarkersGroups[[length(eventMarkersGroups)]], rep(eventMarkers@markerNames$saccade, nrow(eventGroups[[gr]]))))
          eventMarkersGroups[length(eventMarkersGroups)] <- lastMarkers
        }
        else
          # ����� ��������� ������ ������ ������� ��������
        {
          saccadeGroups <- append(saccadeGroups, eventGroups[gr])
          lastGroup <- "Saccade"
          eventMarkersGroups <- append(eventMarkersGroups, list(rep(eventMarkers@markerNames$saccade, nrow(eventGroups[[gr]]))))
        }
      }    
    }
    # ���� ������� ������ ������� - �������
    if (currentGroup == "GAP")
    {
      if (classifyGaps)
      {
        # �� ��������� �� ��������� maxGapLen, ������� �� ������� ��� �� �������
        gapLen <- eventGroups[[gr]]$t[nrow(eventGroups[[gr]])]-eventGroups[[gr]]$t[1]
        # ���� �������, ��� lastGroup = NA, ��� ������ �������� ���������
        # �� �������������� ��� ��� �������
        if (gapLen > maxGapLen | is.na(lastGroup) | gr == length(eventGroups))
        {
          gapClass <- "GAP"
        }
        # ���� �� �������, � ������ �� �������� ���������, � ������ �� �������� ������
        # �� �������������� ������� �� �������� �������, ������� � ��������� 
        if (gapLen <= maxGapLen & gr != length(eventGroups) & !is.na(lastGroup))
        {
          
          if (lastGroup != "GAP" & eventGroups[[gr+1]]$evm[1] != "GAP")
          {
            lastSmpBeforeGap <- eventGroups[[gr-1]][nrow(eventGroups[[gr-1]]),]
            firstSmpAfterGap <- eventGroups[[gr+1]][1,]
            t1 <- lastSmpBeforeGap$t
            t2 <- firstSmpAfterGap$t
            pos1 <- c(lastSmpBeforeGap$x, lastSmpBeforeGap$y)
            pos2 <- c(firstSmpAfterGap$x, firstSmpAfterGap$y)
            if (t2-t1 <= MaxTBetFix)
            {
              if (!angular)
              {
                pxVel <- calcPxVel(t = c(t2, t1),
                                   x = c(pos2[1], pos1[1]),
                                   y = c(pos2[2], pos1[2]))
                dist <- pxVel$dist
              }
              else
              {
                angVel <- calcAngVel(t = c(t2, t1),
                                     x = c(pos2[1], pos1[1]),
                                     y = c(pos2[2], pos1[2]),
                                     screenDist,
                                     screenDim,
                                     screenSize)
                dist <- angVel$dist
              }
              # ���� ������� � ��������� ������ ������ �� ������� � ������������, 
              # �� �� ���������������� ��� ��������
              if (dist <= MaxDistBetFix)
              {
                gapClass <- "Fixation"
              }
              else
                # ���� �� ������ � ������������, �� ������� ���������������� ��� �������
              {
                gapClass <- "Saccade"
              }
            }
            else
              # ���� �� ������ �� �������, �� ������� ���������������� ��� �������
            {
              gapClass <- "Saccade"
            }
          }
          if (lastGroup == "GAP" | eventGroups[[gr+1]]$evm[1] == "GAP")
          {
            gapClass <- "GAP"
          }
        }
      }
      else
      {
        gapClass <- "GAP"
      }
      
      # ��������� ������������� �������� ��������� ������� ��� ������ � ���� ��� ����� ������ �������
      # ���� ������� - ������� �������, �� ��������� ������ ���������
      if (gapClass == "GAP")
      {
        gapGroups <- append(gapGroups, eventGroups[gr])
        lastGroup <- "GAP"
        eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$gap, nrow(eventGroups[[gr]])))
      }
      # ���� ������� - ��������
      if (gapClass == "Fixation")
      {
        # �� ���� ��������� ������ - ��������, �� ��������� ������ �������� � ��� ������
        if (lastGroup == "Fixation")
        {
          lastFixation <- rbind(eventGroups[[gr-1]], eventGroups[[gr]])
          fixationGroups[length(fixationGroups)] <- list(lastFixation)
          lastGroup <- "Fixation"
          eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$fixation, nrow(eventGroups[[gr]])))
        }
        # ����� ��������� ����� ������ � ������ ��������
        else
        {
          fixationGroups <- append(fixationGroups, eventGroups[gr])
          lastGroup <- "Fixation"
          eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$fixation, nrow(eventGroups[[gr]])))
        }
      }
      # ���� ������� - �������
      if (gapClass == "Saccade")
      {
        # �� ���� ��������� ������ - �������, �� ��������� ������ �������� � ��� ������
        if (lastGroup == "Saccade")
        {
          lastSaccade <- rbind(eventGroups[[gr-1]], eventGroups[[gr]])
          saccadeGroups[length(saccadeGroups)] <- list(lastSaccade)
          lastGroup <- "Saccade"
          eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$saccade, nrow(eventGroups[[gr]])))
        }
        # ����� ��������� ����� ������ � ������ ������
        if (lastGroup == "Fixation" | lastGroup == "GAP")
        {
          saccadeGroups <- append(saccadeGroups, eventGroups[gr])
          lastGroup <- "Saccade"
          eventMarkersGroups <- append(eventMarkersGroups, rep(eventMarkers@markerNames$saccade, nrow(eventGroups[[gr]])))
        }
      }
    }
  }
  eventMarkers@eventMarkersData <- unlist(eventMarkersGroups)
  res <- list(eventMarkers = eventMarkers,
              eventGroups = 
                list(
                  fixationGroups = fixationGroups, 
                  saccadeGroups = saccadeGroups,
                  glissadeGroups = NA,
                  smoothPursuitGroups = NA,
                  gapGroups = gapGroups, 
                  artifactGroups = artifactGroups
                )
  )
  return(res)
}