
#' Prediction of concentration evolution  an Eulerian grid
#'
#' Exponential attenuation models for neutrons and muons
#'
#' If `ero` contains several values, the corresponding evolution in time of concentration is computed, `t` should be of same length. The first value of `ero` is used to compute a steady state initial concentration, then the evolution of concentration is computed by ero[i] is the constant erosion rate over the time interval t[i-1] to t[i]. Also in this case z should be either a unique value or the same length as t (used as calculation depth for each time step ).
#'
#' @param z depth coordinate of the profile (g/cm2)
#' @param ero erosion rate (g/cm2/a)
#' @param t time interval (a)
#' @param C0 inherited concentration constant with depth (at/g)
#' @param p production and decay parameters (4 elements vector)
#' p[1] -> unscaled spallation production rate (at/g/a)
#' p[2] -> unscaled stopped muons production rate (at/g/a)
#' p[3] -> unscaled fast muons production rate (at/g/a)
#' p[4] -> decay constant (1/a)
#' @param S scaling factors (2 elements vector)
#' S[1] -> scaling factor for spallation
#' S[2] -> scaling factor for muons
#' @param L attenuation lengths (3 elements vector)
#' L[1] -> neutrons
#' L[2] -> stopped muons
#' L[3] -> fast muons
#' @param in_ero denudation rate used to compute an initial steady-state concentration (g/cm2/a), C0 not used in this case
#' @keywords
#' @export
#' @examples
solv_conc_eul <- function(z,ero,t,C0,p,S,L,in_ero=NULL){
  p = as.numeric(p)
  L = as.numeric(L)
  S = as.numeric(S)
  if(length(ero)==1 | length(t)==1){
  # concentration acquired over the time increment
  Cspal = (S[1]*p[1])/((ero/L[1])+p[4])*exp(-1*z/L[1])*(1-exp(-1*(p[4]+(ero/L[1]))*t))
  Cstop = (S[2]*p[2])/((ero/L[2])+p[4])*exp(-1*z/L[2])*(1-exp(-1*(p[4]+(ero/L[2]))*t))
  Cfast = (S[2]*p[3])/((ero/L[3])+p[4])*exp(-1*z/L[3])*(1-exp(-1*(p[4]+(ero/L[3]))*t))
  C_produced = Cspal + Cstop + Cfast
  if (is.null(in_ero)) { # inheritance constant with depth, defined by the C0 value
    C_inherited = C0*exp(-1*p[4]*t)
  }
  else{
    Cspal_ss = (S[1]*p[1])/((in_ero/L[1])+p[4])*exp(-1*z/L[1])*(exp(-1*(p[4]+(ero/L[1]))*t))
    Cstop_ss = (S[2]*p[2])/((in_ero/L[2])+p[4])*exp(-1*z/L[2])*(exp(-1*(p[4]+(ero/L[2]))*t))
    Cfast_ss = (S[2]*p[3])/((in_ero/L[3])+p[4])*exp(-1*z/L[3])*(exp(-1*(p[4]+(ero/L[3]))*t))
    C_inherited = (Cspal_ss + Cstop_ss + Cfast_ss)

  }
  return(C_produced + C_inherited)
  }else{
    ero = as.numeric(ero)
    t = as.numeric(t)
    if (length(ero)!=length(t)){stop("When considering variable denudation rates, the time and denudation vector should have same length")}
    if (!(length(z)==1  |  length(z)== length(t))){stop("z should be unique value or same length as time vector")}
    if (length(z)==1){z = rep(z,length(t))}
    Cspal = rep(NA,length(t))
    Cstop = rep(NA,length(t))
    Cfast = rep(NA,length(t))
    Cspal[1] = (S[1]*p[1])/((ero[1]/L[1])+p[4])*exp(-1*z[1]/L[1])
    Cstop[1] = (S[2]*p[2])/((ero[1]/L[2])+p[4])*exp(-1*z[1]/L[2])
    Cfast[1] = (S[2]*p[3])/((ero[1]/L[3])+p[4])*exp(-1*z[1]/L[3])
    for (i in 2:length(t)){
      dt = t[i] - t[i-1]
      Cspal[i] = Cspal[i-1]*exp(-1*(p[4]+ero[i]/L[1])*dt) + S[1]*p[1]/(p[4]+ero[i]/L[1])*(1-exp(-1*(p[4]+ero[i]/L[1])*dt))*exp(-1*z[i]/L[1])
      Cstop[i] = Cstop[i-1]*exp(-1*(p[4]+ero[i]/L[2])*dt) + S[2]*p[2]/(p[4]+ero[i]/L[2])*(1-exp(-1*(p[4]+ero[i]/L[2])*dt))*exp(-1*z[i]/L[2])
      Cfast[i] = Cfast[i-1]*exp(-1*(p[4]+ero[i]/L[3])*dt) + S[2]*p[3]/(p[4]+ero[i]/L[3])*(1-exp(-1*(p[4]+ero[i]/L[3])*dt))*exp(-1*z[i]/L[3])
    }
    return(Cspal+Cstop+Cfast)
  }

}








#' Compute concentration evolution along a time-depth history
#'
#' Lagrangian formulation
#'
#' @param t time vector (a)
#' @param z depth vector (g/cm2), same length as t
#' @param C0 initial concentration (at/g)
#' @param Psp0 SLHL spallation production profile (at/g/a) at depth corresponding to z
#' @param Pmu0 muonic production profil at depth corresponding to z
#' @param lambda radioactive decay constant (1/a)
#' @param S scaling parameters for PsP0 and Pmu0 (2 columns), at times corresponding to t (same number of rows)
#' @param final if TRUE only compute the final concentration (default=FALSE)
#'
#' @return
#' @export
#'
#' @examples
solv_conc_lag <- function(t,z,C0,Psp0,Pmu0,lambda,S,final=FALSE){
  nt=length(t)
  if (!final){
    C=rep(0,nt)
    C[1]=C0
    for(i in 2:nt) {
      dt=abs(t[i]-t[i-1])
      P = ( Psp0[i-1]*S[i-1,1] + Pmu0[i-1]*S[i-1,2] + Psp0[i]*S[i,1] + Pmu0[i]*S[i,2] )/2
      C[i] = C0 + P*dt - (C0+P*dt/2)*lambda*dt
      C0 = C[i]
    }
  }
  else{
    #    C =pracma::trapz(t, (Psp0*S[,1] + Pmu0*S[,2])*exp(-1*lambda*(max(t)-t)) ) + C0*exp(-1*lambda*max(t))
    C = abs(pracma::trapz(t, (Psp0*S[,1] + Pmu0*S[,2])*exp(-1*lambda*abs(t[nt]-t)) )) + C0*exp(-1*lambda*(max(t)-min(t)))
  }
  return(C)
}






#' Compute steady state denudation using Eulerian description for the evolution of concentration
#'
#' Eulerian formulation
#'
#' @param Cobs Measured concentration (at/g)
#' @param p production and decay parameters (4 elements vector)
#' p[1] -> unscaled spallation production rate (at/g/a)
#' p[2] -> unscaled stopped muons production rate (at/g/a)
#' p[3] -> unscaled fast muons production rate (at/g/a)
#' p[4] -> decay constant (1/a)
#' @param S scaling factors (2 elements vector)
#' S[1] -> scaling factor for spallation
#' S[2] -> scaling factor for muons
#' @param L attenuation length (3 elements vector)
#' L[1] -> neutrons
#' L[2] -> stopped muons
#' L[3] -> fast muons
#' @param Cobs Uncertainty on measured concentration (at/g), optional but required ffor method MC and MCMC
#' @param method One of single (default), MC, MCMC
#' @n number of draws for MC and MCMC methods (default 10000)
#'
#' @return
#' @export
#'
#' @examples
solv_ss_eros_eul <- function(Cobs,p,S,L,Cobs_e=0,method="single",n=10000){
  Cmax = solv_conc_eul(0,0,Inf,0,p,S,L)
  if (Cobs>Cmax){stop("Observed concentration higher than theoretical maximum")}
  if (!(method %in% c("single","MC","MCMC"))){stop("Parameter method should be one of single, MC or MCMC")}
  if (method!="single" & Cobs_e==0){stop("Need to define the error on the observed concentration")}
  if (method == "single") {
    res = uniroot(fun_solv_ss_eros_eul,c(0,1),Cobs,p,S,L,tol=1e-5)
  } else if (method == "MC") {
    C0 = rtruncnorm(n,a=0,mean=Cobs,sd=Cobs_e)
    ero = rep(NA,n)
    val = rep(NA,n)
    iter = rep(NA,n)
    prec = rep(NA,n)
    for (i in 1:n){
      a = uniroot(fun_solv_ss_eros_eul,c(0,1),C0[i],p,S,L,tol=1e-6) # attention à la borne sup de l'interval que le taux d'érosion max soit assez rapide pour les cocentrations faibles
      ero[i] = a$root
      val[i] = a$f.root
      iter[i] = a$iter
      prec[i] = a$estim.prec
    }
    res = data.frame(C,ero,val,iter,prec)
  } else if (method == "MCMC") {
    ero0 = uniroot(fun_solv_ss_eros_eul,c(0,0.1),Cobs,p,S,L)$root
    binf = max(0,ero0*(1-10*Cobs_e/Cobs))
    bsup = ero0*(1+10*Cobs_e/Cobs)
    res = run_mcmc1(p,S,L,Cobs,Cobs_e,binf,bsup,n)

  }
  return(res)
}

#' Function to be solved by solv_ss_eros_eul when method="single"
#' @param ero
#' @param Cobs
#' @param p
#' @param S
#' @param L
#'
#' @keywords internal
#'
fun_solv_ss_eros_eul <- function(ero,Cobs,p,S,L){
  C = solv_conc_eul(0,ero,4.55e9,0,p,S,L)
  return((C-Cobs)/Cobs)
}

#' Likelihood function : P(obs|params) for solv_ss_eros_eul when method="MCMC"
#' @keywords internal
likelihood1 <- function(ero,p,S,L,Cobs,Cobs_e){
  C = solv_conc_euler(0,ero,4.55e9,0,p,S,L)
  chi2 = (C-Cobs)^2/Cobs_e^2
  res = (-1*chi2/2) + log(1/(sqrt(2*pi)*Cobs_e))
  return(res)
}
#' Prior distribution  P(params) for solv_ss_eros_eul when method="MCMC"
#' @keywords internal
prior1 <- function(ero,binf,bsup){
  return(dunif(ero, min=binf, max=bsup, log = T)) # log prior
}
#' Un-normalized posterior : numerator of Bayes formula : P(obs|params)*P(params) for solv_ss_eros_eul when method="MCMC"
##->  likelihood*prior (but we work with log)
#' @keywords internal
posterior1 <- function(ero,p,S,L,Cobs,Cobs_e,binf,bsup){
  return (likelihood1(ero,p,S,L,Cobs,Cobs_e) + prior1(ero,binf,bsup)) # log posterior
}
#' Proposal function for solv_ss_eros_eul when method="MCMC"
#' @keywords internal
proposal1 <- function(ero,binf,bsup){
  return(rtruncnorm(1,a=binf,b=bsup,mean=ero,sd=(bsup-binf)/20))
}
#' RUN MCMC function for solv_ss_eros_eul when method="MCMC"
#' @keywords internal
run_mcmc1 <- function(p,S,L,Cobs,Cobs_e,binf,bsup,n){
  # start chain
  chain = as.data.frame(matrix(NA,nrow=n,ncol=3))
  colnames(chain) <- c("ero","posterior","probab")
  chain$ero[1] = proposal1(runif(1,binf,bsup),binf,bsup)
  chain$posterior[1] = posterior1(chain$ero[1],p,S,L,Cobs,Cobs_e,binf,bsup)
  for (i in 1:(n-1)){
    #    if (i%%(round(iter*1/100)+1)==0) {cat(round(i/iter*100),"%  -")}
    proposal = proposal1(chain$ero[i],binf,bsup)
    pst = posterior1(proposal,p,S,L,Cobs,Cobs_e,binf,bsup)
    probab = exp(pst - chain$posterior[i]) # ratio of posterior probability proposal/current
    chain$probab[i]=probab
    if (runif(1) < probab){
      chain$ero[i+1] = proposal
      chain$posterior[i+1] = pst
    }else{
      chain$ero[i+1] = chain$ero[i]
      chain$posterior[i+1] = chain$posterior[i]
    }
  } # end loop
  return(chain)
} # end function run_mcmc













