function results = get_al_be_erosion(sample,consts,nuclide);

% This function calculates the erosion rate for a sample by
% optimizing the forward model for E. It then packages the results.
%
% syntax : results = get_al_be_erosion(sample,consts,nuclide);
%
% argument sample is the structure assembled upstream by al_be_erosion_one
% or al_be_erosion_many. See the hard-copy documentation for details. 
%
% argument consts is typically the al_be_consts structure derived from
% make_al_be_consts_vxx.m. See the hard-copy documentation for details.
%
% argument nuclide is 10 or 26.
% 
% results is a structure with fields:
%
% Non-scaling-scheme-specific information:
% 
% results.flags: Non-fatal error message string, mostly to do with
% saturation
% results.main_version: version of this function
% results.obj_version: version of objective function called in the erosion
% rate calculation
% results.mu_version: version of P_mu_total called internally
% results.Pmu0: surface production rate due to muons (atoms/g/yr)
%
% Scaling-scheme-specific information:
%
% results.P_St: Surface production rate due to spallation according to 
% St scaling scheme (atoms/g/yr)
% results.Egcm2yr: 1x5 array of erosion rates calculated using the 5
% scaling schemes (g/cm2/yr) -- order of scaling schemes is St,De,Du,Li,Lm
% results.EmMyr: 1x5 array, calculated erosion rates, different units
% (m/Myr)
% results.delE_int: 1x5 array, internal uncertainties on erosion rates (m/Myr)
% results.delE_ext: 1x5 array, external uncertainties on erosion rates (m/Myr)
%
% Diagnostics:
%
% results.time_mu_precalc: time required to calculate P_mu(z) (s)
% results.fzero_status: 1x5 array containing fzero output flags
% results.fval: 1x5 array containing objective function values at solution
% results.time_fzero: 1x5 array containing optimization times
%
% See hard-copy documentation for discussion of the actual method. 
%
% Written by Greg Balco -- UW Cosmogenic Nuclide Lab
% balcs@u.washington.edu
% April, 2007
% Part of the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/math
%
% Copyright 2001-2007, University of Washington
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License, version 2,
% as published by the Free Software Foundation (www.fsf.org).
% What version is this?

ver = '2.1'; 

% -------------------- 1. INPUT CHECKING ---------------------------------

% If no pressure entered yet, create it from the elevation
% using the appropriate atmosphere

% Change in version 2: This looks up the surface pressure from 
% NCAR map to use in the standard atmosphere equation.
% Obviously, it is always better to estimate pressure from local
% station data. 
% Change in version 2.1: Uses updated pressure estimator NCEPatm_2.m

if (~isfield(sample,'pressure'));
    if (strcmp(sample.aa,'std'));
        % Old code
        % sample.pressure = stdatm(sample.elv);
        % New code
        % Negative longitude check is in NCEPatm_2.m
        sample.pressure = NCEPatm_2(sample.lat,sample.long,sample.elv);
    elseif (strcmp(sample.aa,'ant'));
        sample.pressure = antatm(sample.elv);
    end;
end;

% Catch confusion with pressure submission. If sample.pressure is already 
% set, it should have a submitted value. If zero, something is wrong. 
if isempty(sample.pressure);
    error(['Sample.pressure extant but empty on sample ' sample.sample_name]);
elseif (sample.pressure == 0);
    error(['Sample.pressure = 0 on sample ' sample.sample_name]);
end;

% Convert sample thickness to g/cm2; get thickness SF

sample.thickgcm2 = sample.thick.* sample.rho;
if sample.thick > 0;
    sample.thickSF = thickness(sample.thick,consts.Lsp,sample.rho);
else 
    sample.thickSF = 1;
end;

% Negative longitude catch

if sample.long < 0;
    sample.long = sample.long + 360;
end;

% Initialize the result flags. 

results.flags = [];

% ------------------ 2. NUCLIDE-SPECIFIC ASSIGNMENTS ---------------------

if nuclide == 10;
    N = sample.N10; 
    delN = sample.delN10;
    mc.Natoms = consts.Natoms10;
    mc.sigma190 = consts.sigma190_10;
    mc.k_neg = consts.k_neg10;
    mc.delsigma190 = consts.delsigma190_10; 
    mc.delk_neg = consts.delk_neg10; 
    l = consts.l10;
    L = consts.Lsp;
    P_ref_St = consts.P10_ref_St; delP_ref_St = consts.delP10_ref_St;
    P_ref_Du = consts.P10_ref_Du; delP_ref_Du = consts.delP10_ref_Du;
    P_ref_De = consts.P10_ref_De; delP_ref_De = consts.delP10_ref_De;
    P_ref_Li = consts.P10_ref_Li; delP_ref_Li = consts.delP10_ref_Li;
    P_ref_Lm = consts.P10_ref_Lm; delP_ref_Lm = consts.delP10_ref_Lm;
    nstring='Be-10';
elseif nuclide == 26;
    N = sample.N26; 
    delN = sample.delN26;
    mc.Natoms = consts.Natoms26;
    mc.sigma190 = consts.sigma190_26;
    mc.k_neg = consts.k_neg26;
    mc.delsigma190 = consts.delsigma190_26; 
    mc.delk_neg = consts.delk_neg26; 
    l = consts.l26;
    L = consts.Lsp;
    P_ref_St = consts.P26_ref_St; delP_ref_St = consts.delP26_ref_St;
    P_ref_Du = consts.P26_ref_Du; delP_ref_Du = consts.delP26_ref_Du;
    P_ref_De = consts.P26_ref_De; delP_ref_De = consts.delP26_ref_De;
    P_ref_Li = consts.P26_ref_Li; delP_ref_Li = consts.delP26_ref_Li;
    P_ref_Lm = consts.P26_ref_Lm; delP_ref_Lm = consts.delP26_ref_Lm;
    nstring='Al-26';
end;

% ---------------------- 3. INITIAL GUESS ---------------------------------

P_mu_0_diag = P_mu_total(0,sample.pressure,mc,'yes');

P_temp = (P_ref_St.*stone2000(sample.lat,sample.pressure,1).*sample.thickSF.*sample.othercorr)...
    + P_mu_0_diag.P_fast + P_mu_0_diag.P_neg;
E_lal = L.*(P_temp./N - l);

x0 = E_lal;
    
% -------------------- 4. GET THE EROSION RATES -----------------------------

% Make P(t). Go out to 10M. See the hard-copy documentation for this
% function and get_al_be_age.m for more details. 

tv = [0:500:6500 6900 7500:1000:11500 12000:1000:800000 logspace(log10(810000),7,200)];
temp_M = interp1(consts.t_M,consts.M,tv(16:end));

% Lifton
LiRc = zeros(size(tv));
LiRc(1:15) = interp3(consts.lon_Rc,consts.lat_Rc,consts.t_Rc,consts.TTRc,sample.long,sample.lat,tv(1:15));
% The rest using Equation 6 of Lifton et al. 2005
LiRc(16:end) = 15.765.*temp_M.*((cos(abs(d2r(sample.lat)))).^3.8);

% Desilets
DeRc = LiRc; % Beginning is the same;
% apply Desilets and Zreda 2003 Equation 19
% Note that latitude has to be clipped at 55 for this to work. 
DeLat = min([abs(sample.lat) 55]);
ee = [-4.3077e-3 2.4352e-2 -4.6757e-3 3.3287e-4 -1.0993e-5 1.7037e-7 -1.0043e-9];
ff = [1.4792e1 -6.6799e-2 3.5714e-3 2.8005e-5 -2.3902e-5 6.6179e-7 -5.0283e-9];
DeRc(16:end) = (ee(1)+ff(1).*temp_M) + ...
                (ee(2)+ff(2).*temp_M).*(DeLat.^1) + ...
                (ee(3)+ff(3).*temp_M).*(DeLat.^2) + ...
                (ee(4)+ff(4).*temp_M).*(DeLat.^3) + ...
                (ee(5)+ff(5).*temp_M).*(DeLat.^4) + ...
                (ee(6)+ff(6).*temp_M).*(DeLat.^5) + ...
                (ee(7)+ff(7).*temp_M).*(DeLat.^6);
  
% Dunai
DuRc = zeros(size(tv));
DuRc(1:15) = interp3(consts.lon_Rc,consts.lat_Rc,consts.t_Rc,consts.IHRc,sample.long,sample.lat,tv(1:15));
% The rest from Dunai 2001 equation 1
DuRc(16:end) = 14.9.*temp_M.*((cos(abs(d2r(sample.lat)))).^4);

% Paleomagnetically-corrected Lal
% Same as Dunai > 7 ka
LmRc = DuRc;
% Approximate paleo-pole-positions and field strengths from KC for < 7 ka
LmLat = abs(90-angdist(sample.lat,sample.long,consts.lat_pp_KCL,consts.lon_pp_KCL));
LmRc(1:15) = 14.9.*(consts.MM0_KCL').*((cos(abs(d2r(LmLat)))).^4);              
                
% Also need solar modulation for Lifton SF's
this_S = zeros(size(LiRc)) + consts.SInf;
this_S(1:19) = consts.S;

% Get P_sp(t). No thickness corrections at this point. 
P_De = desilets2006sp(sample.pressure,DeRc).*P_ref_De.*sample.othercorr;
P_Du = dunai2001sp(sample.pressure,DuRc).*P_ref_Du.*sample.othercorr;
P_Li = lifton2006sp(sample.pressure,LiRc,this_S).*P_ref_Li.*sample.othercorr;
P_Lm = stone2000Rcsp(sample.pressure,LmRc).*P_ref_Lm.*sample.othercorr;
P_St = stone2000(sample.lat,sample.pressure,1).*P_ref_St.*sample.othercorr; % scalar

% Precompute P_mu(z) to ~200,000 g/cm2
% This log-spacing setup for the step size has relative accuracy near 
% 1e-3 at 1000 m/Myr erosion rate. 
% start at the mid-depth of the sample.
z_mu = [0 logspace(0,5.3,100)]+(sample.thickgcm2./2);
P_mu_z = zeros(size(z_mu));
% remember P_mu_total is not vectorized, must loop
tic;
for a = 1:length(z_mu); 
    P_mu_z(a) = P_mu_total(z_mu(a),sample.pressure,mc);
end;
time_mu_precalc = toc;

% Yet another constants block for ET_objective.m
c3.tv = tv;
c3.z_mu = z_mu-(sample.thickgcm2./2); % take 1/2 depth away again so t will match P
c3.P_mu_z = P_mu_z;
c3.l = l;
c3.tsf = sample.thickSF;
c3.L = L;

% Finally, ask fzero for the erosion rates. 

opts = optimset('fzero');
opts = optimset(opts,'tolx',1e-8,'display','off');

c3.P_sp_t = P_De;
tic;
[x_De,fval_De,exitflag_De,output] = ...
	 fzero(@(x) ET_objective(x,c3,N),x0,opts);
opt_time_De = toc;
% diagnostics
diag_De = ET_objective(x_De,c3,N,'yes');

c3.P_sp_t = P_Du;
tic;
[x_Du,fval_Du,exitflag_Du,output] = ...
	 fzero(@(x) ET_objective(x,c3,N),x0,opts);
opt_time_Du = toc;
diag_Du = ET_objective(x_Du,c3,N,'yes');

c3.P_sp_t = P_Li;
tic;
[x_Li,fval_Li,exitflag_Li,output] = ...
	 fzero(@(x) ET_objective(x,c3,N),x0,opts);
opt_time_Li = toc;
diag_Li = ET_objective(x_Li,c3,N,'yes');


c3.P_sp_t = P_Lm;
tic;
[x_Lm,fval_Lm,exitflag_Lm,output] = ...
	 fzero(@(x) ET_objective(x,c3,N),x0,opts);
opt_time_Lm = toc;
diag_Lm = ET_objective(x_Lm,c3,N,'yes');

% The following is a messy hack to try to get the fzero calculation for
% St to converge more reliably. This seems to be a problem with
% converting from MATLAB fzero to Octave fzero.
%x0 = x_Lm;
x0 = [0 x_Lm.*2];

c3.P_sp_t = P_St;
tic;
[x_St,fval_St,exitflag_St,output] = ...
	 fzero(@(x) ET_objective(x,c3,N),x0,opts);
opt_time_St = toc;
diag_St = ET_objective(x_St,c3,N,'yes');

% -------------------- 5. ERROR PROPAGATION ---------------------------

sfa = ['St';'De';'Du';'Li';'Lm'];

% Common information

Pmu0 = P_mu_z(1);
delPfast = P_mu_0_diag.P_fast .* (mc.delsigma190 ./ mc.sigma190);
delPneg = P_mu_0_diag.P_neg .* (mc.delk_neg ./ mc.k_neg);
delPmu0 = sqrt(delPfast.^2 + delPneg.^2);

% Do everything 5 times

for a = 1:5;

    % SF - varying variable assignments
    eval(['diag = diag_' sfa(a,:) ';']);
    eval(['thisx = x_' sfa(a,:) ';']);
    eval(['rel_delP0 = (delP_ref_' sfa(a,:) './P_ref_' sfa(a,:) ');']);
    
    % Conditional on actually having a result --
    % this is the saturation check
    if thisx > 0;
        % find what Lmu ought to be 
        Lmu = thisx ./ ((Pmu0./diag.Nmu) - l);

        % Find what P0 ought to be
        Psp0 = diag.Nsp.*(l + (thisx./L));
        delPsp0 = Psp0 .* rel_delP0;
    
        % Find the derivatives with respect to the uncertain parameters.  
        % Here we're calculating centered derivatives using fzero and
        % the subfunction E_simple. 
        
        xx0_up = [0 thisx];
        xx0_down = [thisx 1e6];
        
        if (sign(E_simple(xx0_up(1),Psp0,Pmu0,L,Lmu,l,(N+delN))) * ...
                sign(E_simple(xx0_up(2),Psp0,Pmu0,L,Lmu,l,(N+delN)))) <= 0
            % Case OK bounds for fzero, use centered diff        
            xup = fzero(@(y) E_simple(y,Psp0,Pmu0,L,Lmu,l,(N+delN)),xx0_up);
            xdown = fzero(@(y) E_simple(y,Psp0,Pmu0,L,Lmu,l,(N-delN)),xx0_down);
            dEdN = (1e4./(sample.rho.*2.*delN)) .* ( xup - xdown );
        else
            % Case overlaps saturation? Use half-diff
            xdown = fzero(@(y) E_simple(y,Psp0,Pmu0,L,Lmu,l,(N-0.1*delN)),xx0_down);
            dEdN = (1e4./(sample.rho.*delN)) .* ( thisx - xdown );
        end;

        dEdPsp0 = (1e4./(sample.rho.*2.*delPsp0)) .* ...
            ( (fzero(@(y) E_simple(y,(Psp0+delPsp0),Pmu0,L,Lmu,l,N),thisx)) - ...
            (fzero(@(y) E_simple(y,(Psp0-delPsp0),Pmu0,L,Lmu,l,N),thisx)) );

        dEdPmu0 = (1e4./(sample.rho.*2.*delPmu0)) .* ...
            ( (fzero(@(y) E_simple(y,Psp0,(Pmu0+delPmu0),L,Lmu,l,N),thisx)) - ...
            (fzero(@(y) E_simple(y,Psp0,(Pmu0-delPmu0),L,Lmu,l,N),thisx)) );

        % Add in quadrature to get the uncertainties. 

        delE_ext = sqrt( (dEdPsp0.*delPsp0).^2 + (dEdPmu0.*delPmu0).^2 + (dEdN.*delN).^2 );
        delE_int = abs(dEdN .* delN);
    
        % SF-specific assignments

        eval(['delE_ext_' sfa(a,:) ' = delE_ext;']);
        eval(['delE_int_' sfa(a,:) ' = delE_int;']);
    else;
        flag = ['Sample ' sample.sample_name ' -- ' nstring ' appears to be saturated WRT ' sfa(a,:) ' SF (or there is a problem with the solver).'];
        results.flags = [results.flags '<br>' flag];
        eval(['x_' sfa(a,:) ' = 0;']);
        eval(['delE_ext_' sfa(a,:) ' = 0;']);
        eval(['delE_int_' sfa(a,:) ' = 0;']);
    end;
    % end of uncertainty block
end;

% ----------------------------- 6. REPORT -------------------------------

% Non-scaling-scheme-dependent 
results.main_version = ver;	% version of this function
results.obj_version = diag.ver; % version of objective function
results.mu_version = P_mu_0_diag.ver; % version of P_mu_total
results.Pmu0 = Pmu0; % Surface production rate due to muons;
% Scaling-scheme-dependent
results.P_St = P_St; % Non-time-dependent surface production rate;
results.Egcm2yr = [x_St x_De x_Du x_Li x_Lm];	% erosion rate in gcm2/yr, 5 schemes
results.EmMyr = results.Egcm2yr * 1e4 / sample.rho;	% erosion rate in m/Myr
results.delE_int =	[delE_int_St delE_int_De delE_int_Du delE_int_Li delE_int_Lm];	% internal error in m/Myr
results.delE_ext =	[delE_ext_St delE_ext_De delE_ext_Du delE_ext_Li delE_ext_Lm];	% external error in m/Myr
% diagnostics
results.fzero_status = [exitflag_St exitflag_De exitflag_Du exitflag_Li exitflag_Lm];% exit status of fzero
results.fval = [fval_St fval_De fval_Du fval_Li fval_Lm];	% objective function value from fzero
results.time_fzero = [opt_time_St opt_time_De opt_time_Du opt_time_Li opt_time_Lm]; % elapsed time of optimization
results.time_mu_precalc = time_mu_precalc; % elapsed time of P_mu(z) precalculation

% results.flags already contains whatever it's gonna contain. 

% ----------------------------- SUBROUTINES -------------------------------

% -------------------------------------------------------------------------

function out = E_simple(x,Psp,Pmu,Lsp,Lmu,l,target);

% calculates miss between N computed with simple erosion rate expression
% and measured N
%
% Used in simplified error-propagation scheme
%
% x is erosion rate (g/cm2/yr)

N = (Psp./(l + x./Lsp)) + (Pmu./(l + x./Lmu));

out = N - target;

% ------------------------------------------------------------------------


