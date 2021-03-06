
createParser <- function(name, fun, settings)
{
  parser <- new(Class = "Parser", name = name, fun = fun, settings = settings)
  return(parser)
}

createFilter <- function(name, fun, settings)
{
  filter <- new(Class = "Filter", name = name, fun = fun, settings = settings)
  return(filter)
}

createSmoother <- function(name, fun, settings)
{
  smoother <- new(Class = "Smoother", name = name, fun = fun, settings = settings)
  return(smoother)
}

createDetector <- function(name, fun, settings)
{
  detector <- new(Class = "EventDetector", name = name, fun = fun, settings = settings)
  return(detector)
}

# Calculates angular height and width in degrees of the eye position 
# relative to the screen/scene center or the given reference point
calcAngPos <- function(x, y, screenDist, screenDim, screenSize, refPoint = c(screenDim[1]/2, screenDim[2]/2))
{
  d <- screenDist
  w <- screenSize[1]; h <- screenSize[2]
  wPx <- screenDim[1]; hPx <- screenDim[2]
  xshift <- ((x-refPoint[1])/wPx)*w
  yshift <- ((y-refPoint[2])/hPx)*h
  xAng <- atan(xshift/d)*(180/pi)
  yAng <- atan(yshift/d)*(180/pi)
  return(list(xAng = xAng, yAng = yAng))
}

# Calculates horiz. and vert. momentum velocities (px/timeUnit) of the eye movements given by vectors <t, x, y>
calcXYShiftsVel <- function(t, x, y)
{
  samplesCnt <- length(t)
  dts <- t[-1] - t[-samplesCnt]
  dxs <- x[-1] - x[-samplesCnt]
  dys <- y[-1] - y[-samplesCnt]
  xVels <- dxs/dts
  yVels <- dys/dts
  return(list(xVels = xVels, yVels = yVels))
}

# Calculates horiz. and vert. momentum velocities (deg/timeUnit)
calcXYShiftsAngVel <- function(t, x, y, screenDist, screenDim, screenSize)
{
  samplesCnt <- length(t)
  dts <- t[-1] - t[-samplesCnt]
  d <- screenDist
  w <- screenSize[1]; h <- screenSize[2]
  wPx <- screenDim[1]; hPx <- screenDim[2]
  x1s <- x[-samplesCnt]; x2s <- x[-1]
  y1s <- y[-samplesCnt]; y2s <- y[-1]
  xshifts <- ((x2s-x1s)/wPx)*w
  yshifts <- ((y2s-y1s)/hPx)*h
  xAngs <- atan(xshifts/d)
  yAngs <- atan(yshifts/d)
  xVels <- abs(xAngs)*(180/pi)/dts
  yVels <- abs(yAngs)*(180/pi)/dts
  return(list(xVels = xVels, yVels = yVels))
}

# Calculates momentum velocities (px/timeUnit)
calcPxVel <- function(t, x, y)
{
  samplesCnt <- length(t)
  dts <- abs(t[-1] - t[-samplesCnt])
  dls <- sqrt((x[-1] - x[-samplesCnt])^2 + (y[-1] - y[-samplesCnt])^2)
  vels <- 
    res <- list(dists = dls, dts = dts, vels = dls/dts)
  res
}

# Calculates angular velocities (deg/timeUnit)
calcAngVel <- function(t, x, y, screenDist, screenDim, screenSize)
{
  samplesCnt <- length(t)
  dts <- abs(t[-1] - t[-samplesCnt])
  d <- screenDist
  w <- screenSize[1]; h <- screenSize[2]
  wPx <- screenDim[1]; hPx <- screenDim[2]
  x1s <- x[-samplesCnt]; x2s <- x[-1]
  y1s <- y[-samplesCnt]; y2s <- y[-1]
  dP0P1 <- sqrt((((x1s-wPx/2)/wPx)*w)^2 + (((y1s-hPx/2)/hPx)*h)^2)
  dP0P2 <- sqrt((((x2s-wPx/2)/wPx)*w)^2 + (((y2s-hPx/2)/hPx)*h)^2)
  alphaW <- atan(dP0P1/d)
  alphaH <- atan(dP0P2/d)
  dEyeP1 <- dP0P1/sin(alphaW)
  dEyeP2 <- dP0P2/sin(alphaH)
  dP1P2 <- sqrt((((x2s-x1s)/wPx)*w)^2 + (((y2s-y1s)/hPx)*h)^2)
  angles <- acos((dEyeP1^2 + dEyeP2^2 - dP1P2^2)/(2*dEyeP1*dEyeP2))
  res <- list(dists = angles*(180/pi), dts = dts, vels = angles*(180/pi)/dts)
  res
}