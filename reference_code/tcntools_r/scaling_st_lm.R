#' Compute scaling parameters according to Stone (2000) (st)
#'
#' This function compute spallation and muons scaling factors according to Equations 2 and 3 from Stone (2000)
#'
#' @param P pressure (hPa)
#' @param lat Latitude (deg)
#' @keywords
#' @export
#' @examples
#' scaling_st
scaling_st<-function(P,lat){
  lat=abs(lat)
  Vlat=c(0,10,20,30,40,50,60)
  Va=c(31.8518,34.3699,40.3153,42.0983,56.7733,69.0720,71.8733)
  Vb=c(250.3193,258.4759,308.9894,512.6857,649.1343,832.4566,863.1927)
  Vc=c(-0.083393,-0.089807,-0.106248,-0.120551,-0.160859,-0.199252,-0.207069)
  Vd=c(7.4260e-5,7.9457e-5,9.4508e-5,1.1752e-4,1.5463e-4,1.9391e-4,2.0127e-4)
  Ve=c(-2.2397e-8,-2.3697e-8,-2.8234e-8,-3.8809e-8,-5.0330e-8,-6.3653e-8,-6.6043e-8)
  VM=c(0.587,0.600,0.678,0.833,0.933,1.000,1.000)
  #
  a=approx(Vlat,Va,xout=lat,rule=2,method="linear")$y
  b=approx(Vlat,Vb,xout=lat,rule=2,method="linear")$y
  c=approx(Vlat,Vc,xout=lat,rule=2,method="linear")$y
  d=approx(Vlat,Vd,xout=lat,rule=2,method="linear")$y
  e=approx(Vlat,Ve,xout=lat,rule=2,method="linear")$y
  Nneutrons=a + (b * exp(-1*P/150.)) + (c*P) + (d*P^2) + (e*P^3)
  #
  M=approx(Vlat,VM,xout=lat,rule=2,method="linear")$y
  Nmuons=M*exp((1013.25 - P)/242)
  res = data.frame(Nneutrons,Nmuons)
  return(res)
}






#' Compute scaling parameter for the lm scheme (Lal/Stone time dependent)
#'
#' Adapted from G. Balco matlab code (http://hess.ess.washington.edu/math)
#'
#' @param h atmospheric pressure (hPa)
#' @param Rc cutoff rigidity (GV)
#' @keywords
#' @export
#' @examples
#' scaling_lm
scaling_lm<-function(h,Rc){
  if (length(h)>1) {stop("Function not vectorized for atmospheric pressure")}
  # build the scaling factor = f(rigidity) function up to 14.9 GV
  ilats_d = c(0,10,20,30,40,50,60)
  ilats_r = d2r(ilats_d)
  # convert latitude to rigidity using Elsasser formula (from Sandstrom)
  iRcs = 14.9*((cos(ilats_r))^4)
  # constants from Table 1 of Stone(2000)
  a = c(31.8518, 34.3699, 40.3153, 42.0983, 56.7733, 69.0720, 71.8733)
  b = c(250.3193, 258.4759, 308.9894, 512.6857, 649.1343, 832.4566, 863.1927)
  c = c(-0.083393, -0.089807, -0.106248, -0.120551, -0.160859, -0.199252, -0.207069)
  d = c(7.4260e-5, 7.9457e-5, 9.4508e-5, 1.1752e-4, 1.5463e-4, 1.9391e-4, 2.0127e-4)
  e = c(-2.2397e-8, -2.3697e-8, -2.8234e-8, -3.8809e-8, -5.0330e-8, -6.3653e-8, -6.6043e-8)
  # Apply Eqn. (2) of Stone (2000)
  sf = a + (b * exp(h/(-150))) + (c*h) + (d*(h^2)) + (e*(h^3))
  # Extend to zero rigidity - scaling factor does not change from that at 60 degrees
  iRcs[8] = 0
  sf[8] = sf[7]
  # Extend to 21 GV by fitting a log-log line to the latitude 0-20 values,
  # i.e. where rigidity is greater than 10 GV. According to Quemby and Wenk,
  # as summarized  in Sandstrom, log(rigidity) vs. log(nucleon intensity)
  # ought to be linear above 10 GV. Note that this is speculative, but
  # relatively unimportant, as the approximation is pretty much only used
  # for low latitudes for a short time in the Holocene.
  fits=lm(log10(sf[1:3])~log10(iRcs[1:3]))
  add_iRcs=c(30,28,26,24,22,21,20,19,18,17,16)
  add_sf = exp( log(sf[1]) + fits$coefficients[2]*( log10(add_iRcs) - log10(iRcs[1]) ) )
  sf = c(add_sf,sf)
  iRcs = c(add_iRcs,iRcs)
  tmp = data.frame(iRcs,sf)
  tmp =tmp[order(iRcs),]
  #  interpolate
  return(approx(tmp[,1],tmp[,2],Rc)$y)
}






