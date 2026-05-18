#' Compute solar modulation factor for the LSD scheme
#'
#' Adapted from the matlab code in the supplementary material of Lifton et al. (2014)
#'
#'
#'
#' @param t time (a) same as for Rc calculations
#' @keywords
#' @export
#' @examples
solar_modulation<-function(t){
  # make time vector (same as for the calculation of Rc)
  tv = c(seq(0,50,10),seq(60,50060,100),seq(51060,2000060,1000),10^seq(log10(2001060),7,length.out = 200))
  this_SPhi = rep(0,length(tv)) + Pal_LSD$SPhiInf # Solar modulation potential for Sato et al. (2008)
  this_SPhi[1:120] = Pal_LSD$SPhi # Solar modulation potential for Sato et al. (2008)
  #
  return(approx(tv,this_SPhi,t)$y)
}




#' Compute cutoff rigidities time series for the calculation of scaling factors according to Lifton et al. (2014)
#' 'LSD' scaling scheme
#'
#' Adapted from the matlab code in the supplementary material of Lifton et al. (2014)
#'
#' @param lat site latitude (deg, -90->90 southern hemisphere negative)
#' @param lon site longitude (deg, -180->180 western hemisphere negative)
#' @param time time before present (a, with respect to 2010)
#' @keywords
#' @export
#' @examples
lsdrc<-function(lat,lon,time){
  # get longitude from 0 to 360
  lon_c=lon+(lon<0)*360
  # Age Relative to t0=2010
  tv = c(seq(0,50,10),seq(60,50060,100),seq(51060,2000060,1000),10^seq(log10(2001060),7,length.out = 200))
  LSDRc = rep(0,length(tv))
  # interpolate an M for tv > 7000...
  temp_M = approx(Pal_LSD$t_M,Pal_LSD$MM0,tv[-(1:76)])$y
  # Make up the Rc vectors, work over data blocks
  tempRc=rep(0,dim(Pal_LSD$TTRc)[3])
  for(i in 1:dim(Pal_LSD$TTRc)[3]){
    tempRc[i]=pracma::interp2(Pal_LSD$lon_Rc,rev(Pal_LSD$lat_Rc),pracma::flipud(Pal_LSD$TTRc[,,i]), lon_c, lat)
  }
  LSDRc[1:76]=approx(Pal_LSD$t_Rc,tempRc,tv[1:76])$y
  #
  # Fit to Trajectory-traced GAD dipole field as f(M/M0), as long-term average.
  #
  dd = c(6.89901,-103.241,522.061,-1152.15,1189.18,-448.004)
  LSDRc[-(1:76)] = temp_M*(dd[1]*cos(d2r(lat)) +
                             dd[2]*(cos(d2r(lat)))^2 +
                             dd[3]*(cos(d2r(lat)))^3 +
                             dd[4]*(cos(d2r(lat)))^4 +
                             dd[5]*(cos(d2r(lat)))^5 +
                             dd[6]*(cos(d2r(lat)))^6)
  #
  return(approx(tv,LSDRc,time)$y)
}










##############################################################################

#' scaling_lsd
#'
#' Implements the Lifton-Sato-Dunai scaling scheme from Lifton et al. (2014)
#'
#' Compute the scaling paramters for both the Sf (flux based) and Sa (flux ad cross-section based, nuclide dependent) schemes.
#'
#' Lifton, N., Sato, T., & Dunai, T. J. (2014).
#' Scaling in situ cosmogenic nuclide production rates using analytical approximations to atmospheric cosmic-ray fluxes.
#' Earth and Planetary Science Letters, 386, 149–160.
#' https://doi.org/10.1016/j.epsl.2013.10.052
#'
#' Initial Matlab code from Lifton et al. (2014)
#'
#' @param h atmospheric pressure (hPa)
#' @param Rc cutoff rigidity (GV)
#' @param SPhi solar modulation potential (Phi, see source paper)
#' @param w fractional water content of ground (nondimensional)
#'
#' @return
#' @export
#'
#' @examples
scaling_lsd<- function(h,Rc,SPhi,w){
  # Written by Nat Lifton 2013, Purdue University
  # nlifton@purdue.edu
  # Based on code by Greg Balco -- Berkeley Geochronology Lab
  # balcs@bgc.org
  # April, 2007
  # Part of the CRONUS-Earth online calculators:
  #      http://hess.ess.washington.edu/math
  #
  # Copyright 2001-2013, University of Washington, Purdue University
  # All rights reserved
  # Developed in part with funding from the National Science Foundation.
  #
  # This program is free software you can redistribute it and/or modify
  # it under the terms of the GNU General Public License, version 3,
  # as published by the Free Software Foundation (www.fsf.org).

  # define structures to store results
  scaling=data.frame(matrix(NA, nrow=length(Rc), ncol=13))
  colnames(scaling)<-c("Rc","sp","He","Be","C","Al","eth","th","muTotal","mn","mp","mnabs","mpabs")
  scaling$Rc=Rc
  #
  Site=list()

  if (w < 0) {w = 0.066}  # default gravimetric water content for Sato et al. (2008)

  # reference muon flux
  mfluxRef = Ref_LSD$mfluxRef
  muRef = (unlist(mfluxRef$neg) + unlist(mfluxRef$pos))

  # reference values for nuclide of interest or flux
  HeRef = Ref_LSD$P3nRef + Ref_LSD$P3pRef
  BeRef = Ref_LSD$P10nRef + Ref_LSD$P10pRef
  CRef = Ref_LSD$P14nRef + Ref_LSD$P14pRef
  AlRef = Ref_LSD$P26nRef + Ref_LSD$P26pRef
  SpRef = Ref_LSD$nfluxRef + Ref_LSD$pfluxRef # Sato et al. (2008) Reference hadron flux integral >1 MeV

  EthRef = Ref_LSD$ethfluxRef
  ThRef = Ref_LSD$thfluxRef

  # Site nucleon fluxes

  NSite = sato_neutrons(h,Rc,SPhi,w)
  NlowSite = sato_neutrons_low(h,Rc,SPhi,w)
  PSite = sato_protons(h,Rc,SPhi)

  # Site omnidirectional muon flux
  mflux = sato_muons(h,Rc,SPhi) #Generates muon flux at site from Sato et al. (2008) model
  muSite = (mflux$flux_diff_neg + mflux$flux_diff_pos)



  #Nuclide-specific scaling factors as f(Rc)
  scaling$He = (NSite$scaling$P3n + PSite$scaling$P3p)/HeRef
  scaling$Be =  (NSite$scaling$P10n + PSite$scaling$P10p)/BeRef
  scaling$C =  (NSite$scaling$P14n + PSite$scaling$P14p)/CRef
  scaling$Al =  (NSite$scaling$P26n + PSite$scaling$P26p)/AlRef
  scaling$sp = ((NSite$scaling$nflux + PSite$scaling$pflux))/SpRef # Sato et al. (2008) Reference hadron flux integral >1 MeV
  #
  scaling$eth = NlowSite$flux$ethflux/EthRef #Epithermal neutron flux scaling factor as f(Rc)
  scaling$th  = NlowSite$flux$thflux/ThRef#Thermal neutron flux scaling factor as f(Rc)
  #
  #
  Site$E = NSite$E #Nucleon flux energy bins

  #Differential muon flux scaling factors as f(Energy, Rc)
  Site$muE = mflux$E  #Muon flux energy bins (in MeV)
  Site$mup = mflux$p  #Muon flux momentum bins (in MeV/c)

  muSF = matrix(rep(0,length(Rc)*length(Site$muE)),nrow=length(Rc),ncol=length(Site$muE))
  for (i in 1:length(Rc)){
    muSF[i,] = muSite[i,]/muRef
  }

  Site$muSF=muSF

  #Integral muon flux scaling factors as f(Rc)
  scaling$muTotal = mflux$flux_int$total/unlist(mfluxRef$total) #Integral total muon flux scaling factor
  scaling$mn      = mflux$flux_int$neg/unlist(mfluxRef$nint) #Integral neg muon flux scaling factor
  scaling$mp      = mflux$flux_int$pos/unlist(mfluxRef$pint) #Integral pos muon flux scaling factor
  scaling$mnabs   = mflux$flux_int$neg #Integral neg muon flux
  scaling$mpabs   = mflux$flux_int$pos #Integral pos muon flux

  Site$scaling=scaling
  return(Site)

}


