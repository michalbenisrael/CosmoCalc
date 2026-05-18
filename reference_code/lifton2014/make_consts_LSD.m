function out = make_consts_LSD()

% This function creates and saves a structure with relevant constants and
% external data for the C and Be exposure age and erosion rate calculators.  
%
% Syntax: make_conts_LSD
% (no arguments)
%
% See the code for what the constants
% actually are. 
%
%
% Written by Greg Balco -- Berkeley
% Geochronology Center
% balcs@u.washington.edu -- balcs@bgc.org
% 
% Modified by Brent Goehring -- Lamont-Doherty Earth Observatory
% goehring@ldeo.columbia.edu
% and Nat Lifton -- Purdue University
% nlifton@purdue.edu

% October 2013
% 
% Part of the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/math
%
% Copyright 2013, University of Washington, Columbia University and the
% Purdue University
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License, version 3,
% as published by the Free Software Foundation (www.fsf.org).

consts.version = '1.0';
consts.prepdate = fix(clock);


% Muon interaction cross-sections. All follow Heisinger (2002a,b).
% Note that the energy-dependence-of-muon-interaction-cross-section
% exponent alpha is treated as model-dependent -- it's internal to 
% P_mu_total.m and can't be passed.  

consts.Natoms3 = 2.006e22;
consts.Natoms10 = 2.006e22;
consts.Natoms14 = 2.006e22;
consts.Natoms26 = 1.003e22;

consts.k_neg10 = 5.05e-4; %per Balco 2010 (online publication) update of 
                        %constants file from 2.2 to 2.2.1
consts.delk_neg10 = 0.35e-4; %per Balco 2010 (online publication) update of 
                        %constants file from 2.2 to 2.2.1
consts.k_neg14 = 0.704 * 0.1828 * 0.137;
consts.delk_neg14 = 0.704 * 0.1828 * 0.0011;
consts.k_neg26 = 0.296 * 0.6559 * 0.022;
consts.delk_neg26 = 0.296 * 0.6559 * 0.002;

consts.sigma190_10 = 8.6e-29; %per Balco 2010 (online publication) update of 
                        %constants file from 2.2 to 2.2.1
consts.delsigma190_10 = 1.2e-29; %per Balco 2010 (online publication) update of 
                        %constants file from 2.2 to 2.2.1
consts.sigma190_14 = 0.45e-27;
consts.delsigma190_14 = 0.25e-27;
consts.sigma190_26 = 1.41e-27;
consts.delsigma190_26 = 0.17e-27;

% New Spallogenic Nuclide Production Cross-Sections (n & p) from Bob Reedy 9/2010

load XSectsReedyAll; 

consts.O16nxBe10 = O16nxBe10;
consts.O16pxBe10 = O16pxBe10;
consts.SinxBe10 = SinxBe10;
consts.SipxBe10 = SipxBe10;
consts.O16nn2pC14 = O16nn2pC14;
consts.O16pxC14 = O16pxC14;
consts.SinxC14 = SinxC14;
consts.SipxC14 = SipxC14;
consts.Aln2nAl26 = Aln2nAl26;
consts.AlppnAl26 = AlppnAl26;
consts.SinxAl26 = SinxAl26;
consts.SipxAl26 = SipxAl26;
consts.OnxHe3T = OnxHe3T;
consts.OpxHe3T = OpxHe3T;
consts.SinxHe3T = SinxHe3T;
consts.SipxHe3T = SipxHe3T;


% Paleomagnetic records for use in time-dependent production rate schemes
% Load the magnetic field data - 

load PMag_Sep12 %incl. Dunai version - CALS3K.3, CALS7K.2, GLOPIS-75 to 18ka, PADM2M >18 ka, 1950-2010 Rc from DGRFs
%     Dec11 version includes updated SPhi values from Usoskin et al, 2011, Journal of Geophysical Research, v. 116, no. A2. Changed end value of
%     t_M from Inf to 1e7 to enable to run in MATLAB 2012a and later. 

% Relative dipole moment and time vector
consts.M = MM0; 
consts.t_M = t_M; 
consts.t_fineRc = t_fineRc;

% These start at 7000 yr -- time slices are 100-yr from 7000 to 50000
% in order to use 100-yr-averaged data from GLOPIS-75 (to 18 ka) and PADM2M (>18 ka); subsequent time 
% slices are 50000:1000:2000000 for 
% PADM2M data; final two time points are 2001000 and 1e7. - Nat Lifton

% Cutoff rigidity blocks for past 6900 yr. 
% TTRc and IHRC are lon x lat x time blocks of Rc values for the past 
% 6900 years.
% Both are derived by Nat Lifton from the magnetic field reconstructions of
% Korte and Constable. 
% TTRC has cutoff rigidity obtained by trajectory tracing -- these are for
% the Lifton and Desilets scaling factors. IHRc has cutoff rigidity
% obtained by finding magnetic inclination and horizontal field strength
% from the field model, then applying Equation 2 of Dunai(2001). 

consts.TTRc = TTRc; % data block
consts.IHRc = IHRc; % data block
consts.lat_Rc = lat_Rc; % lat and lon indices for Rc data block
consts.lon_Rc = lon_Rc;
consts.t_Rc = t_Rc; % time vector for Rc data block


% Solar variability from Usoskin et al. 2011
% 0-11400 yr - 100-yr spacing

%Per Tatsuhiko Sato, personal communication, 2013, convert annually
%averaged Usoskin et al. (2011)
%solar modulation potential to Sato Force Field Potential due to different
%assumed Local Interstellar Spectrum and other factors

SPhi = 1.1381076.*SPhi - 1.2738468e-4.*SPhi.^2;

consts.SPhi = SPhi;
consts.SPhiInf = mean(SPhi);% Changed 12/13/11 to reflect updated SPhi values from Usoskin et al. (2011)

load Reference
%Reference values for scaling via Sato et al. (2008) spectra
consts.E = E;
consts.P3nRef = P3nRef; %3He neutron reference production in SiO2
consts.P3pRef = P3pRef; %3He proton reference production in SiO2
consts.P10nRef = P10nRef; %10Be neutron reference production in SiO2
consts.P10pRef = P10pRef; %10Be proton reference production in SiO2
consts.P14nRef = P14nRef; %14C neutron reference production in SiO2
consts.P14pRef = P14pRef; %14C proton reference production in SiO2
consts.P26nRef = P26nRef; %26Al neutron reference production in SiO2
consts.P26pRef = P26pRef; %26Al proton reference production in SiO2
consts.nfluxRef = nfluxRef; %integral reference neutron flux
consts.pfluxRef = pfluxRef; %integral reference proton flux
consts.ethfluxRef = ethfluxRef; %integral reference epithermal flux
consts.thfluxRef = thfluxRef; %integral reference thermal neutron flux
consts.mfluxRef = mfluxRef; % reference muon flux components

% Finish up

save consts_LSD consts

disp(['Constants version ' consts.version]);
disp('Saved'); 


