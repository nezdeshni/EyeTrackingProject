# TO DO: estimate max saccade acceleration
IVT <- function(t, x, y, filterMarkers, VT, angular = F, screenDist, screenDim, screenSize, 
                MaxTBetFix, MaxDistBetFix, minFixLen, maxGapLen, maxVel, maxAccel)
{
  # 1. Velocities estimation
  if (!angular)
  {
    vel <- calcPxVel(t, x, y)
  } 
  else
  {
    vel <- calcAngVel(t, x, y, screenDist, screenDim, screenSize)
  }
  
  # 2. Classification stage: getting raw event markers
  markers1 <- ifelse(x == 0 & y == 0, filterMarkers@markerNames$zeroes, filterMarkers@markerNames$ok)
  if (!is.na(screenDim)[1])
  {
    markers2 <- ifelse(x > screenDim[1] | y > screenDim[2], filterMarkers@markerNames$outOfBounds, filterMarkers@markerNames$ok)
    markers1[which(markers1 == filterMarkers@markerNames$ok)] <- markers2[which(markers1 == filterMarkers@markerNames$ok)]
  }
  gapMarkers <- ifelse(markers1 != filterMarkers@markerNames$ok, "GAP", "NOT GAP")
  rawEventMarkers <- ifelse(gapMarkers[-length(gapMarkers)] == "GAP", "GAP", ifelse(vel$vels <= VT, "Fixation", "Saccade"))
  
  # 3. Post-processing stage
  evmarks <- data.frame(firstEv = rawEventMarkers[-length(rawEventMarkers)], secondEv = rawEventMarkers[-1])
  transitions <- apply(evmarks, MARGIN = 1, function(x) {if (x[2] != x[1]) {1} else {0}})
  group <- c(1,cumsum(transitions)+1)
  events <- data.frame(t = t[-length(t)], x = x[-length(t)], y = y[-length(t)], vel = vel$vels, evm = rawEventMarkers, gr = group)
  eventGroups <- split(events, group)
  fixationGroups <- list()
  saccadeGroups <- list()
  gapGroups <- list()
  artifactGroups <- list()
  lastGroup = NA
  for (gr in 1:length(eventGroups))
  {
    currentGroup <- eventGroups[[gr]]$evm[1]
    # ���� ������� ������ ������� - ��������
    if (currentGroup == "Fixation")
    {
      # �� ��������� � ������������
      fixLen <- eventGroups[[gr]]$t[nrow(eventGroups[[gr]])]-eventGroups[[gr]]$t[1]
      # ���� �������� ��������, �� ���������� �
      # ���� �������� �� ��������
      if (fixLen >= minFixLen)
      {
        # � �� ����� ��� �� ���� �������� ������ �������
        if (is.na(lastGroup))
        {
          # �� ��������� ������ �������� ������� ���������
          fixationGroups <- append(fixationGroups, eventGroups[gr])
          lastGroup <- "Fixation"
        }
        # � ���������� ������ - �������
        if (lastGroup == "Saccade")
        {
          # � ��� ���� ���������� �������� �� �����
          if (length(fixationGroups) != 0)
          {
            # �� ���������� ����� � ������� ������ ������� ��������
            fixTime <- eventGroups[[gr]]$t[1]
            fixPos <- c(eventGroups[[gr]]$x[1], eventGroups[[gr]]$y[1])
            # � ����� ����� � ������� ����� ��������� ������������ ��������
            lastFixation <- tail(fixationGroups, n = 1)[[1]]
            lastFixTime <- lastFixation$t[nrow(lastFixation)]
            lastFixPos <- c(lastFixation$x[nrow(lastFixation)], lastFixation$y[nrow(lastFixation)])
            # � ���������, ������ �� ��� ��� �������� �� ������� � ������������
            if (lastFixTime - fixTime <= MaxTBetFix)
            {
              # ���� ��� ������ �� �������, �� ��������� ���������� � ������������
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
              # ���� ��� ������ � � ������������
              if (dist <= MaxDistBetFix)
              {
                # �� ���������� ������� ������������� ��� �������� ������
                artifactGroups <- saccadeGroups[length(saccadeGroups)]
                saccadeGroups <- saccadeGroups[-length(saccadeGroups)]
                # � ������� �������� ������������� ��� ����������� ����������
                lastFixation <- rbind(lastFixation, eventGroups[[gr]])
                fixationGroups[length(fixationGroups)] <- list(lastFixation)
                lastGroup <- "Fixation"
              }
              # ���� ��� �� ������ � ������������, �� ��������� ������ �������� ������� ���������
              else
              {
                fixationGroups <- append(fixationGroups, eventGroups[gr])
                lastGroup <- "Fixation"
              }
            }
            else
              # ���� ��� �� ������ �� �������, �� ��������� ������ �������� ������� ���������
            {
              fixationGroups <- append(fixationGroups, eventGroups[gr])
              lastGroup <- "Fixation"
            }
          }
          # ���� �������� ����� �� ���� ����������, �� ��������� ������ �������� ������� ���������
          else
          {
            fixationGroups <- append(fixationGroups, eventGroups[gr])
            lastGroup <- "Fixation"
          }
        }
        # ���� ���������� ������� - �������, �� ��������� ������ �������� ������� ���������
        if (lastGroup == "GAP")
        {
          fixationGroups <- append(fixationGroups, eventGroups[gr])
          lastGroup <- "Fixation"
        }
      }
    }
    # ���� ������� ������ ������� - �������
    if (currentGroup == "Saccade")
    {
      # �� ��������� ��������� maxVel � maxAccel
      maxSaccadeVel <- max(eventGroups[[gr]]$vel)
      maxSaccadeAccel <- 0
      
      # � ���� ������� ��������� (�������� �� ������ � ����������� ���������� �������� ��� ���������), 
      # �� ��������� ������ ���������� ���� ��������
      if (maxSaccadeVel > maxVel | maxSaccadeAccel > maxAccel)
      {
        # anomaly!
        artifactGroups <- append(artifactGroups, eventGroups[gr])
      }
      #	���� ������� ���������, �� ��������� ������ ������ ������� ��������
      else
      {
        saccadeGroups <- append(saccadeGroups, eventGroups[gr])
        lastGroup <- "Saccade"
      }    
    }
    # ���� ������� ������ ������� - �������
    if (currentGroup == "GAP")
    {
      # �� ��������� �� ��������� maxGapLen, ������� �� ������� ��� �� �������
      gapLen <- eventGroups[[gr]]$t[nrow(eventGroups[[gr]])]-eventGroups[[gr]]$t[1]
      # ���� �������, ��� lastGroup = NA, ��� ������ �������� ���������
      # �� ��������� ������ �������� gapGroup = groups[[x]] � ��������� ������ ��������� gapGroups
      if (gapLen > maxGapLen | is.na(lastGroup) | gr == length(eventGroups))
      {
        gapClass <- "GAP"
      }
      # ���� �� �������, � ������ �� �������� ���������, � ������ �� �������� ������
      # �� �������������� ������� �� �������� �������, ������� � ��������� 
      if (gapLen <= maxGapLen & gr != length(eventGroups) & !is.na(lastGroup))
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
      # ��������� ������������� �������� ��������� ������� ��� ������ � ���� ��� ����� ������ �������
      # ���� ������� - ������� �������, �� ��������� ��� �������� ������ ���������
      if (gapClass == "GAP")
      {
        gapGroups <- append(gapGroups, eventGroups[gr])
        lastGroup <- "GAP"
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
        }
        # ����� ��������� ����� ������ � ������ ��������
        else
        {
          fixationGroups <- append(fixationGroups, eventGroups[gr])
          lastGroup <- "Fixation"
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
        }
        # ����� ��������� ����� ������ � ������ ������
        if (lastGroup == "Fixation" | lastGroup == "GAP")
        {
          saccadeGroups <- append(saccadeGroups, eventGroups[gr])
          lastGroup <- "Saccade"
        }
      }
    }
  }
  
  res <- list(fixations = fixationGroups, saccades = saccadeGroups, gaps = gapGroups, artifacts = artifactGroups)
  return(res)
  
  # 7. Events' parameters estimation stage
  
  # 8. Return eventMarkers and eventData objects
}