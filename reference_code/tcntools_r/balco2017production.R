

#' Muons production profile according to model 1A of Balco (2017)
#'
#' Compute muons production profile as a function of depth below the surface z (g/cm2)
#' and site atmospheric pressure h (hPa). According to model 1A from Balco (2017)
#'
#' Adapted from G. Balco matlab code
#'
#' Balco, G. (\strong{2017}). Production rate calculations for cosmic-ray-muon-produced 10Be and 26Al benchmarked against geological calibration data.
#' \emph{Quaternary Geochronology}, 39, 150–173.
#' https://doi.org/10.1016/j.quageo.2017.02.001
#'
#' cst is a list containing nuclide-specific constants, as follows:
#' cst$Natoms -  atom number density of the target atom (atoms/g)
#' cst$k_neg - summary cross-section for negative muon capture (atoms/muon)
#' cst$sigma190 - 190 GeV x-section for fast muon production (cm2)
#'
#' @param z depth below the surface z (g/cm2)
#' @param h site atmospheric pressure h (hPa)
#' @param cst list of nuclide specific parameters (see below)
#' @keywords
#' @export
#' @examples
#'
mu_model1a<-function(z,h,cst){

  # TODO case alpha = 1
  # TODO use for function  phi_v_slhl(z) ?

  H = (1013.25 - h)*1.019716 # figure the atmospheric depth in g/cm2

  phi_vert_slhl = phi_v_slhl(z) # find the vertical flux at SLHL

  R_vert_slhl = Rv0(z) # find the stopping rate of vertical muons at SLHL

  R_vert_site = R_vert_slhl*exp(H/LZ(z)) # find the stopping rate of vertical muons at site

  # find the flux of vertical muons at site
  fi<-function(x){return(Rv0(x)*exp(H/LZ(x)))}
  phi_vert_site=rep(0,length(z))
  for(a in 1:length(z)) {
    # integration ends at 200001 g/cm2 to avoid being asked for an zero
    # range of integration --
    # get integration tolerance -- want relative tolerance around 1 part in 10^4
    tol = phi_vert_slhl[a] * 1e-4
    temp = integrate(fi,z[a],2e5+1,abs.tol=tol)
    phi_vert_site[a] = temp$value
  }

  # invariant flux at 2e5 g/cm2 depth - constant of integration
  # calculated using commented-out formula above
  a = 258.5*(100^2.66) # à supprimer en generalisant la formule plus haut
  b = 75*(100^1.66)
  phi_200k = (a/((2e5+21000)*(((2e5+1000)^1.66) + b)))*exp(-5.5e-6 * 2e5)
  phi_vert_site = phi_vert_site + phi_200k


  # find the total flux of muons at site

  # angular distribution exponent
  nofz = 3.21 - 0.297*log((z+H)/100 + 42) + 1.21e-5*(z+H)
  # derivative of same
  dndz = (-0.297/100)/((z+H)/100 + 42) + 1.21e-5

  phi_temp = phi_vert_site * 2 * pi / (nofz+1)

  # that was in muons/cm2/s
  # convert to muons/cm2/yr

  phi = phi_temp*60*60*24*365

  #find the total stopping rate of muons at site

  R_temp = (2*pi/(nofz+1))*R_vert_site - phi_vert_site*(-2*pi*((nofz+1)^-2))*dndz

  # that was in total muons/g/s
  # convert to negative muons/g/yr

  R = R_temp*0.44*60*60*24*365

  #Now calculate the production rates.

  #Depth-dependent parts of the fast muon reaction cross-section

  Beta = 0.846 - 0.015 * log((z/100)+1) + 0.003139 * (log((z/100)+1)^2)
  Ebar = 7.6 + 321.7*(1 - exp(-8.059e-6*z)) + 50.7*(1-exp(-5.05e-7*z))

  #internally defined constants
  aalpha = 0.75

  # attention prendre en compte le cas sigma0
  sigma0 = cst$sigma190/(190^aalpha)

  if ( "sigma190" %in% names(cst)) {
    sigma0 = cst$sigma190/(190^aalpha)
  } else if ( "sigma0" %in% names(cst)) {
    sigma0=cst$sigma0
  } else {
    stop("ERROR : Undefined cross section (either sigma0 or sigma190)")
  }


  # fast muon production
  P_fast = phi*Beta*(Ebar^aalpha)*sigma0*cst$Natoms

  # negative muon capture
  P_neg = R*cst$k_neg

  #return

  out=data.frame(z,P_fast,P_neg,phi_vert_slhl,R_vert_slhl,phi_vert_site,R_vert_site,phi,R,Beta,Ebar)

  return(out)

} # end of mu_model1a






#' Muons production profile according to model 1B of Balco (2017)
#'
#' Compute muons production profile as a function of depth below the surface z (g/cm2)
#' and site atmospheric pressure h (hPa). According to model 1B from Balco (2017)
#'
#' Adapted from G. Balco matlab code
#'
#' Balco, G. (\strong{2017}). Production rate calculations for cosmic-ray-muon-produced 10Be and 26Al benchmarked against geological calibration data.
#' \emph{Quaternary Geochronology}, 39, 150–173.
#' https://doi.org/10.1016/j.quageo.2017.02.001
#'
#' cst is a list containing nuclide-specific constants, as follows:
#' cst$Natoms -  atom number density of the target atom (atoms/g)
#' cst$k_neg - summary cross-section for negative muon capture (atoms/muon)
#' cst$sigma190 - 190 GeV x-section for fast muon production (cm2)
#'
#' @param z depth below the surface z (g/cm2)
#' @param h site atmospheric pressure h (hPa)
#' @param Rc cutoff rigidity (GV)
#' @param Sphi solar modulation parameter
#' @param cst list of nuclide specific parameters (see below)
#' @keywords
#' @export
#' @examples
#'
mu_model1b<-function(z,h,Rc,Sphi,cst){

  # figure the atmospheric depth in g/cm2
  H = (1013.25 - h)*1.019716
  Href = 1013.25

  # find the omnidirectional flux at the site
  mflux = sato_muons(h,Rc,Sphi) #Generates muon flux at site from Sato et al. (2008) model
  mfluxRef =  sato_muons(Href,0,462.04)
  # plot(tmp[["consts"]][["mfluxRef"]][["E"]][[1]],tmp[["consts"]][["mfluxRef"]][["pos"]][[1]],type="l",log="xy")
  # lines(mfluxRef[["E"]],mfluxRef[["flux_diff_pos"]],col="red")
  # plot(tmp[["consts"]][["mfluxRef"]][["E"]][[1]],tmp[["consts"]][["mfluxRef"]][["neg"]][[1]],type="l",log="xy")
  # lines(mfluxRef[["E"]],mfluxRef[["flux_diff_neg"]],col="red")

  phi_site = (mflux$flux_diff_neg + mflux$flux_diff_pos)
  phiRef = (mfluxRef$flux_diff_neg + mfluxRef$flux_diff_pos)

  # find the vertical flux at SLHL
  a = 258.5*(100^2.66)
  b = 75*(100^1.66)

  phi_vert_slhl = (a/((z+21000)*(((z+1000)^1.66) + b)))*exp(-5.5e-6 * z)

  # Convert E to Range
  Temp = E2R(mflux$E)
  RTemp = Temp$R

  #Set upper limit to stopping range to test comparability with measurements
  StopLimit = 10
  # find the stopping rate of vertical muons at site
  # find all ranges <10 g/cm2
  stopindex = RTemp<StopLimit

  SFmu = phi_site/phiRef

  SFmuslow = sum(phi_site[stopindex]/sum(phiRef[stopindex]))

  #   Prevent depths less than the minimum range in E2R to be used below
  z[z < min(RTemp)] = min(RTemp)

  # Find scaling factors appropriate for energies associated with stopping
  # muons at depths z
  Rz = approx(RTemp,SFmu,z)$y

  Rz[Rz>SFmuslow] = SFmuslow

  RzSpline = splinefun(RTemp, SFmu)

  # find the stopping rate of vertical muons at the site, scaled from SLHL
  # this is done in a subfunction Rv0, because it gets integrated below.
  R_vert_slhl = Rv0(z)
  R_vert_site = R_vert_slhl*Rz


  # find the flux of vertical muons at site
  fi<-function(x){return(Rv0(x)*RzSpline(x))}
  phi_vert_site=rep(0,length(z))
  for(a in 1:length(z)) {
    # integration ends at 200001 g/cm2 to avoid being asked for an zero
    # range of integration --
    # get integration tolerance -- want relative tolerance around 1 part in 10^4
    tol = phi_vert_slhl[a] * 1e-4
    temp = integrate(fi,z[a],2e5+1,abs.tol=tol)
    phi_vert_site[a] = temp$value
  }

  # invariant flux at 2e5 g/cm2 depth - constant of integration
  # calculated using commented-out formula above
  a = 258.5*(100^2.66)
  b = 75*(100^1.66)
  phi_200k = (a/((2e5+21000)*(((2e5+1000)^1.66) + b)))*exp(-5.5e-6 * 2e5)
  phi_vert_site = phi_vert_site + phi_200k

  # find the total flux of muons at site

  # angular distribution exponent
  nofz = 3.21 - 0.297*log((z+H)/100 + 42) + 1.21e-5*(z+H)
  # derivative of same
  dndz = (-0.297/100)/((z+H)/100 + 42) + 1.21e-5

  phi_temp = phi_vert_site*2*pi/(nofz+1)

  # that was in muons/cm2/s
  # convert to muons/cm2/yr

  phi = phi_temp*60*60*24*365

  R_temp = (2*pi/(nofz+1))*R_vert_site - phi_vert_site*(-2*pi*((nofz+1)^-2))*dndz

  # that was in total muons/g/s
  # convert to negative muons/g/yr

  R = R_temp*0.44*60*60*24*365

  # Attenuation lengths
  LambdaMu =(Href-h)/(log(phi_site)-log(phiRef))

  # Now calculate the production rates.

  # Depth-dependent parts of the fast muon reaction cross-section

  # Per John Stone, personal communication 2011 - see text
  aalpha = 1.0
  Beta = 1.0

  Ebar = 7.6 + 321.7*(1 - exp(-8.059e-6*z)) + 50.7*(1-exp(-5.05e-7*z))

  # internally defined constants

  # GB modified here to pass consts as does v 1.2 of P_mu_total.m
  Natoms = cst$Natoms
  k_neg = cst$k_neg

  # attention prendre en compte le cas sigma0
  sigma0 = cst$sigma190/(190^aalpha)

  if ( "sigma190" %in% names(cst)) {
    sigma0 = cst$sigma190/(190^aalpha)
  } else if ( "sigma0" %in% names(cst)) {
    sigma0=cst$sigma0
  } else {
    stop("ERROR : Undefined cross section (either sigma0 or sigma190)")
  }

  # fast muon production

  P_fast = phi*Beta*(Ebar^aalpha)*sigma0*Natoms

  # negative muon capture

  P_neg = R*k_neg

  #return

  out=data.frame(z,P_fast,P_neg,phi_vert_slhl,R_vert_slhl,phi_vert_site,R_vert_site,phi,R,Beta,Ebar)


  return(out)

} # end of mu_model1b




#########################################################################
LZ<-function(z){
  # Balco 2017 matlab code
  # this subfunction returns the effective atmospheric attenuation length for
  # muons of range Z
  # define range/momentum relation
  # table for muons in standard rock in Groom and others 2001

  # col 1 : momentum (MeV/c)
  # col 2 : range  (g/cm2)

  data = as.data.frame(matrix(c(4.704e1, 8.516e-1,
                                5.616e1, 1.542e0,
                                6.802e1, 2.866e0,
                                8.509e1, 5.698e0,
                                1.003e2, 9.145e0,
                                1.527e2, 2.676e1,
                                1.764e2, 3.696e1,
                                2.218e2, 5.879e1,
                                2.868e2, 9.332e1,
                                3.917e2, 1.524e2,
                                4.945e2, 2.115e2,
                                8.995e2, 4.418e2,
                                1.101e3, 5.534e2,
                                1.502e3, 7.712e2,
                                2.103e3, 1.088e3,
                                3.104e3, 1.599e3,
                                4.104e3, 2.095e3,
                                8.105e3, 3.998e3,
                                1.011e4, 4.920e3,
                                1.411e4, 6.724e3,
                                2.011e4, 9.360e3,
                                3.011e4, 1.362e4,
                                4.011e4, 1.776e4,
                                8.011e4, 3.343e4,
                                1.001e5, 4.084e4,
                                1.401e5, 5.495e4,
                                2.001e5, 7.459e4,
                                3.001e5, 1.040e5,
                                4.001e5, 1.302e5,
                                8.001e5, 2.129e5),ncol=2,byrow=TRUE))
  colnames(data) <- c("momentum","range")

  # obtain momenta  using log-linear interpolation
  P_MeVc = exp(approx(log(data$range),log(data$momentum),log(z),rule=2)$y)

  # obtain attenuation lengths
  out = 263 + 150 * (P_MeVc/1000)

  return(out)
}


#########################################################################
Rv0<-function(z){
  # Balco 2017 matlab code
  # this subfunction returns the stopping rate of vertically traveling muons
  # as a function of depth z at sea level and high latitude.

  a = exp(-5.5e-6*z)
  b = z + 21000
  c = (z + 1000)^1.66 + 1.567e5
  dadz = -5.5e-6 * exp(-5.5e-6*z)
  dbdz = 1
  dcdz = 1.66*(z + 1000)^0.66

  out = -5.401e7 * (b*c*dadz - a*(c*dbdz + b*dcdz))/(b^2 * c^2)
  return(out)
}


###################################################
E2R<-function(x){
  # this subfunction returns the range and energy loss values for
  # muons of energy E in MeV

  # define range/energy/energy loss relation
  # table for muons in standard rock
  # http://pdg.lbl.gov/2010/AtomicNuclearProperties/ Table 281

  data =matrix(c(1.0e1, 8.400e-1, 6.619,
                 1.4e1, 1.530e0, 5.180,
                 2.0e1, 2.854e0, 4.057,
                 3.0e1, 5.687e0, 3.157,
                 4.0e1, 9.133e0, 2.702,
                 8.0e1, 2.675e1, 2.029,
                 1.0e2, 3.695e1, 1.904,
                 1.4e2, 5.878e1, 1.779,
                 2.0e2, 9.331e1, 1.710,
                 3.0e2, 1.523e2, 1.688,
                 4.0e2, 2.114e2, 1.698,
                 8.0e2, 4.418e2, 1.775,
                 1.0e3, 5.534e2, 1.808,
                 1.4e3, 7.712e2, 1.862,
                 2.0e3, 1.088e3, 1.922,
                 3.0e3, 1.599e3, 1.990,
                 4.0e3, 2.095e3, 2.038,
                 8.0e3, 3.998e3, 2.152,
                 1.0e4, 4.920e3, 2.188,
                 1.4e4, 6.724e3, 2.244,
                 2.0e4, 9.360e3, 2.306,
                 3.0e4, 1.362e4, 2.383,
                 4.0e4, 1.776e4, 2.447,
                 8.0e4, 3.343e4, 2.654,
                 1.0e5, 4.084e4, 2.747,
                 1.4e5, 5.495e4, 2.925,
                 2.0e5, 7.459e4, 3.187,
                 3.0e5, 1.040e5, 3.611,
                 4.0e5, 1.302e5, 4.037,
                 8.0e5, 2.129e5, 5.748),ncol=3,byrow=TRUE)

  # units are range in g cm-2 (column 2)
  # energy in MeV (column 1)
  # Total energy loss/g/cm2 in MeV cm2/g(column 3)

  # deal with zero situation
  x[x<10] = 1

  # obtain ranges
  # use log-linear interpolation
  R = exp(approx(log(data[,1]),log(data[,2]),log(x),rule=2)$y)
  Eloss = exp(approx(log(data[,1]),log(data[,3]),log(x),rule=2)$y)
  res=data.frame(cbind(R,Eloss))
  colnames(res)<-c("R","Eloss")
  return(res)
}


##########################################################################
# Heisinger et al. (2002a) eqs 1 and 2 input in g/cm2
phi_v_slhl<-function(z){
  a = 258.5*(100^2.66)
  b = 75*(100^1.66)
  out = (a/((z+21000)*(((z+1000)^1.66) + b)))*exp(-5.5e-6 * z)
  return(out)
}

