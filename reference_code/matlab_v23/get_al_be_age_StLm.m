function results = get_al_be_age_StLm(sample,consts,nuclide);

% This function calculates the exposure age of a sample and
% packages the results.
%
% syntax : results = get_al_be_age(sample,consts,nuclide);
%
% argument sample is the structure assembled upstream by al_be_age_one
% or al_be_age_many. Many required fields, see hard-copy docs for details.
%
% argument consts is typically the al_be_consts structure derived from
% make_al_be_consts_vxx.m. Many required fields, see hard-copy docs for
% details.
%
% argument nuclide is 10 or 26. Number not string. 
%
% Many dependencies.
% 
% results is a structure with many fields:
%
% Non-scaling-scheme-dependent results:
%
% results.flags: Error messages, mostly about saturation
% results.main_version: version of this function
% results.muon_version: version of P_mu_total called internally
% results.P_mu: surface production rate by muons (atoms/g/yr)
% results.thick_sf: thickness scaling factor (nondimensional)
% results.tv: time vector against which to plot Rc and P
%
% Scaling-scheme-dependent results: two of each of these fields, one for
% each scaling scheme. XX in field names below indicates a two-letter code
% identifying each scaling scheme, as follows:
% St (Stone,2000); and Lm (paleomagnetically corrected implementation 
% of Lal(1991)/Stone(2000). 
%
% results.P_XX: P(t) at site in scaling scheme XX (atoms/g/yr) (vector)
% results.t_XX: Exposure age WRT scaling scheme XX (yr)
% results.FSF_St: Effective scaling factor WRT scaling scheme XX 
% (the effective scaling factor is the SF which, when put into the simple
% age equation, yields the correct age)
% results.delt_int_XX: Internal uncertainty WRT scaling scheme XX (yr)
% results.delt_ext_XX: External uncertainty WRT scaling scheme XX (yr)
%
% Also:
% results.SF_St_nominal: Stone(2000) scaling factor (historical interest)
% 
% See hard-copy documentation for discussion of the actual method. 
%
% Written by Greg Balco -- UW Cosmogenic Nuclide Lab
% balcs@u.washington.edu
% April, 2007
% Part of the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/math
%
% Modified to ditch neutron-monitor-based scaling schemes, August 2014, by
% Greg Balco (Berkeley Geochronology Center)
%
% Copyright 2001-2007, University of Washington
% 2008-2014, Berkeley Geochronology Center
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License, version 2,
% as published by the Free Software Foundation (www.fsf.org).
% What version is this?

ver = '2.1-StLm';

% 0. Select appropriate values for nuclide of interest

if nuclide == 10;
    % Atoms/g measurement
    N = sample.N10; delN = sample.delN10; 
    % Production rates from spallation for two schemes
    P_ref_St = consts.P10_ref_St; delP_ref_St = consts.delP10_ref_St;
    P_ref_Lm = consts.P10_ref_Lm; delP_ref_Lm = consts.delP10_ref_Lm;
    % Decay constant
    l = consts.l10; 
    % Fraction spallation for Stone, 2000 scheme - historical interest
    Fsp = consts.Fsp10;
    % constants structure for muon production rate
    mconsts.Natoms = consts.Natoms10;
    mconsts.sigma190 = consts.sigma190_10;
    mconsts.delsigma190 = consts.delsigma190_10; % not used
    mconsts.k_neg = consts.k_neg10;
    mconsts.delk_neg = consts.delk_neg10; % not used
elseif nuclide == 26;
    % Atoms/g measurement
    N = sample.N26; delN = sample.delN26; 
    % Production rates for four schemes
    P_ref_St = consts.P26_ref_St; delP_ref_St = consts.delP26_ref_St;
    P_ref_Lm = consts.P26_ref_Lm; delP_ref_Lm = consts.delP26_ref_Lm;
    % Decay constant
    l = consts.l26; dell = consts.dell26; 
    % Fraction spallation for Stone, 2000 scheme - historical interest
    Fsp = consts.Fsp26;
    % constants structure for muon production rate
    mconsts.Natoms = consts.Natoms26;
    mconsts.sigma190 = consts.sigma190_26;
    mconsts.delsigma190 = consts.delsigma190_26; % not used
    mconsts.k_neg = consts.k_neg26;
    mconsts.delk_neg = consts.delk_neg26; % not used
end;

% 1. Obtain the thickness correction and the atmospheric pressure.  

% 1a. Thickness scaling factor. 

if sample.thick > 0;
    sample.thickSF = thickness(sample.thick,consts.Lsp,sample.rho);
else 
    sample.thickSF = 1;
end;

% 1b. If no pressure entered yet, create it from the elevation
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
        sample.pressure = NCEPatm_2(sample.lat,sample.long,sample.elv);
    elseif (strcmp(sample.aa,'ant'));
        sample.pressure = antatm(sample.elv);
    end;
end;

% Catch confusion with pressure submission. If sample.pressure is already 
% set, it should have a submitted value. If zero, something is wrong. 
% This should never happen in online use. 

if sample.pressure == 0;
    error(['Sample.pressure = 0 on sample ' sample.sample_name]);
end;

% Initialize the result flags. 

results.flags = [];

% 2. Make an initial guess at the age. This mainly serves to limit the
% length of the forward calculation and speed things up slightly.

% First, find P according to Stone/Lal SF, get muon production from H2002

% Actually get the full data from P_mu_total -- needed later
% Use middle of sample
mu = P_mu_total((sample.thick.*sample.rho./2),sample.pressure,mconsts,'yes');
P_mu = mu.P_fast + mu.P_neg;
% Don't double-count muons in the following line
P_St = P_ref_St * sample.thickSF * sample.othercorr * stone2000(sample.lat,sample.pressure,1);
A = l + sample.rho * sample.E ./consts.Lsp;

if (N >= ((P_St+P_mu)./A));
    % if appears to be saturated in simple-age-world, simple age equation
    % would evaluate to NaN. Avoid this.
    % set results to -1; this flags it
    t_simple = -1;
else; 
    % Actually do calculation if possible
    t_simple = (-1/A)*log(1-(N * A / (P_St+P_mu))); 
end;

% 3. Generate the paleo-rigidity record. 
% This isn't very general...requires particular time steps to take account 
% of how the paleomagnetic data is reported.

% catch for negative longitudes before Rc interpolation
if sample.long < 0; sample.long = sample.long + 360;end;

% Make the time domain for the forward age calculation. The time steps 
% follow the paleomagnetic data:
%
% 1. [0:500:6500 6900] to match Nat's K and C field derivatives
% The nominal pole positions have been resampled to these times,
% as has the solar modulation factor. 
%
% 2. [7500:1000:11500] to match Yang et al. 2000. 
% Assuming axial dipole at this point, so no pole positions,
% but solar modulation again resampled at [7500:1000:10500].
%
% 3. [12000:1000:800000] to match SINT800
%
% 4. logspace(log10(810000),7,200) gives 200 log-spaced points out
% to 10M. 99% saturation is 9.968 Myr for Be-10, 4.685 Myr for Al-26
%
% Result: 1009 elements. 
%
% As linear interpolation is used to find the age, using a 1000-yr time step
% step could affect the accuracy at the 10^-3 level in the final timestep
% given the Be-10 and Al-26 half-lives with typical erosion. This has no 
% effect on the eventual age. This would not be acceptable for short-half-life 
% nuclides, i.e. 14-C. 

% Use the non-time-dependent age t_simple to decide on a length for Rc(t). The
% factor of 1.6 is a W.A.G. Note that because the long-term magnetic field is 
% low, old PMC ages will nearly always be less than the simple age. If this goes
% wrong there is a diagnostic flag. 

mt = t_simple .* 1.6; % mt is max time. 

% Make the time vector
tv = [0:500:6500 6900 7500:1000:11500 12000:1000:800000 logspace(log10(810000),7,200)];

% clip to limit computations...
if mt < 0; % Saturated WRT simple age - use full tv
    mt = 1e7;
elseif  mt < 12000;
    mt = 12000; % Don't allow unreasonably short times
elseif mt > 1e7; 
    mt = 1e7;
end;
% now chop off tv;
clipindex = max(find(tv <= mt));
tv = tv(1:clipindex); % don't actually pad out to what mt is...lose 1 time step
% interpolate an M for tv > 7000...
% Note: this is broken in recent versions of MATLAB because consts.t_M has
% an Inf at the end. Thus a patch here. 
% temp_M = interp1(consts.t_M,consts.M,tv(16:end)); % old code

% New code
over_t_M = find(tv > consts.t_M(end-1)); % find values in tv that are greater than 801000

if isempty(over_t_M);
    % case everything in tv is < 801k
    temp_M = interp1(consts.t_M(1:(end-1)),consts.M(1:(end-1)),tv(16:end));
else;
    % case there are some elements in tv that are > 801k
    % interpolate ones that are OK first
    temp_M = interp1(consts.t_M(1:(end-1)),consts.M(1:(end-1)),tv(16:(min(over_t_M)-1)));
    % add those that are over 801 ka 
    temp_M = [temp_M zeros(size(over_t_M))+consts.M(end)];
end;


% Make up the Rc vector for Lm

% Make up the Rc vectors.
% Must now make large grids with meshgrid first

[rcx,rcy,rcz] = meshgrid(consts.lon_Rc,consts.lat_Rc,consts.t_Rc);
rcxi = zeros(1,15) + sample.long;
rcyi = zeros(1,15) + sample.lat;

 % First 15 from the IH data block
LmRc = zeros(size(tv));
% Fixed to work with new interp3
LmRc(1:15) = interp3(rcx,rcy,rcz,consts.IHRc,rcxi,rcyi,tv(1:15));
% The rest from Dunai 2001 equation 1
LmRc(16:end) = 14.9.*temp_M.*((cos(abs(d2r(sample.lat)))).^4);

% Approximate paleo-pole-positions and field strengths from KC for < 7 ka
LmLat = abs(90-angdist(sample.lat,sample.long,consts.lat_pp_KCL,consts.lon_pp_KCL));
LmRc(1:15) = 14.9.*(consts.MM0_KCL').*((cos(abs(d2r(LmLat)))).^4);              

% 4. Do the age calculation. Interestingly, because all of the P(t)
% functions are defined piecewise constant, it's not necessary to have
% a zero-finding loop. We can just calculate the cumulative integral and
% reverse-interpolate. 

% Calculate the unweighted P(t) separately to be sent back in the results.
% This is the surface production rate taking account of thickness. 
% P_St is already calculated

P_Lm = stone2000Rcsp(sample.pressure,LmRc).*P_ref_Lm.*sample.thickSF.*sample.othercorr;

% Also calculate production by muons. 
% This code uses only a highly simplified attenuation-length approximation
% for the depth dependence of production by muons. This is OK here because
% good exposure-dating sites must have low erosion rates. This
% approximation isn't good enough for erosion-rate calculations, and it's
% not used in the erosion rate calculator. 

Lmu = 1500; 
  
% Calculate N(t) including decay and erosion

dcf = exp(-tv.*l); % decay factor;
dpfs = exp(-tv.*sample.E.*sample.rho./consts.Lsp); % spallation depth dependence
dpfm = exp(-tv.*sample.E.*sample.rho./Lmu); % muon depth dependence approximation

N_St = cumtrapz(tv,(P_St.*dcf.*dpfs + P_mu.*dcf.*dpfm));
N_Lm = cumtrapz(tv,(P_Lm.*dcf.*dpfs + P_mu.*dcf.*dpfm));

% Look for saturation with respect to various scaling factors -- 
% If not saturated, get the age by reverse-interpolation.
% Note that this is not necessarily rigorous and doesn't attempt to take
% account of uncertainties in deciding if a sample is saturated. If you
% need rigorous analysis of close-to-saturation measurements, this code is
% not for you. 

if nuclide==10;nstring='Be-10';elseif nuclide==26;nstring='Al-26';end;

if N > max(N_St); 
    flag = ['Sample ' sample.sample_name ' -- ' nstring ' appears to be saturated WRT Stone(2000) SF.'];
    results.flags = [results.flags '<br>' flag];
    t_St = 0;
else;
    t_St = interp1(N_St,tv,N);
end;
    
if N > max(N_Lm); 
    flag = ['Sample ' sample.sample_name ' -- ' nstring ' appears to be saturated WRT Lal/Stone PMAG SF.'];
    results.flags = [results.flags '<br>' flag];
    t_Lm = 0;
else;
    t_Lm = interp1(N_Lm,tv,N);
end;

% Error propagation scheme. 
% This is highly simplified. We approximate the error by figuring out what the
% effective production rate is (disregarding the special depth dependence
% for muons) which gives the right age in the simple age equation. 
% Error in this taken to be linear WRT the reference production rate.
% Then we linearly propagate errors through the S.A.E. 
% We ignore the nominal error in production by muons. This is OK
% because it's small compared to the total error in the reference
% production rate. Future versions will use Monte Carlo error analysis. 

sfa = ['St';'Lm'];

for a = 1:2; % Do everything twice
    % extract t, Pref, delPref for SF
    eval(['tt = t_' sfa(a,:) ';']);
    eval(['tPref = P_ref_' sfa(a,:) ';']);
    eval(['tdelPref = delP_ref_' sfa(a,:) ';']);
    if tt > 0; % Not saturated, is an age
        % do most of computation
        FP = (N.*A)./(1 - exp(-A.*tt));
        delFP = (tdelPref / tPref) * FP;
        dtdN = 1./(FP - N.*A);  
        dtdP = -N./(FP.*FP - N.*A.*FP);
        % make respective delt's
        eval(['delt_ext_' sfa(a,:) ' = sqrt( dtdN.^2 * delN.^2 + dtdP.^2 * delFP.^2);']);
        eval(['delt_int_' sfa(a,:) ' = sqrt(dtdN.^2 * delN.^2);']);
        eval(['FP_' sfa(a,:) ' = FP;']);
    else; % t set to 0, was saturated
        eval(['delt_ext_' sfa(a,:) ' = 0;']);
        eval(['delt_int_' sfa(a,:) ' = 0;']);
        eval(['FP_' sfa(a,:) ' = 0;']);
    end;
end;

% 5. Results structure assignment

% Thickness scaling factor
results.thick_sf = sample.thickSF;

% Muons

results.P_mu = P_mu;

% Time template
results.tv = tv;

% Results x 4 by scaling factor

for a = 1:2;
    if a > 1; % No Rc record for non-time-dependent SF
        eval(['results.Rc_' sfa(a,:) ' = ' sfa(a,:) 'Rc;']);
    end;
    eval(['results.P_' sfa(a,:) ' = P_' sfa(a,:) ';']); % vector for De,Du,Li,Lm, scalar for St    
    eval(['results.t_' sfa(a,:) ' = t_' sfa(a,:) ';']); % age
    eval(['results.FSF_' sfa(a,:) ' = FP_' sfa(a,:) './(results.thick_sf.*sample.othercorr.*P_ref_' sfa(a,:) ');']); % effective SF
    eval(['results.delt_int_' sfa(a,:) ' = delt_int_' sfa(a,:) ';']);
    eval(['results.delt_ext_' sfa(a,:) ' = delt_ext_' sfa(a,:) ';']);
end;

% Lal/Stone SF for historical interest
results.SF_St_nominal = stone2000(sample.lat,sample.pressure,Fsp);

% Version
results.main_version = ver;
results.muon_version = mu.ver;

