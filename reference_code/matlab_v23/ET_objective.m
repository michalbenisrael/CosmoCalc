 function miss = ET_objective(E,cs,target,dFlag);

% Forward calculator for N under a particular erosion rate.
% Calculates expected N for a particular erosion rate; returns
% difference between predicted and measured N. 
% Used to implicitly solve for E.
%
% syntax miss = ET_objective(E,cs,target,dFlag);
%
% needs:
%   E erosion rate - what is being solved for (g/cm2/yr)
%   %   target - measured number of atoms (atoms/g)
%   structure cs containing time and depth information
%       cs.tv - time vector for spallation (yr)
%       cs.P_sp_t - P_sp to match tv (or a scalar) (atoms/g/yr)
%           This is surface, not thickness-averaged, P
%       cs.z_mu - vector of depths (g/cm2) 
%       cs.P_mu_z - P(z) for muons - matches z_mu (atoms/g/yr)
%       cs.l - decay constant (1/yr)
%       cs.tsf - thickness scaling factor (nondimensional)
%       cs.L - Effective attenuation length for spallation (g/cm2)
%
% Input argument dFlag is optional. Set to 'yes' to get a structure 
% containing diagnostic information. See hard-copy docs for details. 
%
% Output argument miss is difference between predicted and measured 
% nuclide concentration (atoms/g). 
%
% Not vectorized, obviously. Scalar E only.
%
% Notes:    Integration uses analytical formula for Psp(z), 
%           trapezoidal formula for P(t),
%           and trapezoidal integration for Pmu(z). 
%           Don't send z_mu > 2e5 g/cm2.
%           P_mu_z should take account of the sample thickness, so actually
%               P_mu_z(a) is the production rate in the sample when the 
%               sample surface is at z_mu(a), not the production rate at z_mu(a). 
%           Integration accuracy is mostly determined by upstream choice 
%               of time step. 
%
% See hard-copy docs for details.
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
 

% What version?

ver = '2.0';

% Checks

if nargin < 4;
    dFlag = 'no';
end;

if size(cs.tv) ~= size(cs.P_sp_t);
    error('Mismatched tv and P_sp');
end;

if size(cs.z_mu) ~= size(cs.P_mu_z);
    error('Mismatched z_mu and P_mu_z');
end;

% 1. Forward integration for muons....by trapezoidal integration

% Find the t's corresponding to z_mu at E
t_mu = cs.z_mu./E;
% If fzero asked for a negative erosion rate,
% set Nmu to the saturation concentration and carry on. 
% Should yield a negative solution for E, thus flagging saturation.
if E <= 0;
    Nmu = cs.P_mu_z(1)./cs.l;
else;
    % Actually do it
    % muons use linear average for thickness...this is dealt with upstream
    Nmu = trapz(t_mu,(cs.P_mu_z.*exp(-cs.l.*t_mu)));
end;
% The accuracy of this is set by the spacing of z_mu upstream. See the 
% hard-copy docs for details. 

% Forward integration for spallation...using integral formula
% with average P(t) in the time step...

if length(cs.P_sp_t) > 1; % time-dependent P - average in timesteps
    P1 = cs.P_sp_t(1:end-1); P2 = cs.P_sp_t(2:end);Pav = (P1+P2)./2;
else; % non-time-dependent P, scalar
    Pav = cs.P_sp_t;
end;
% Do integration in each time step, using integral formula in depth
t1 = cs.tv(1:end-1); t2 = cs.tv(2:end);
A = (cs.l + E./cs.L);
if length(cs.P_sp_t) == 1;
    Nsp = cs.tsf.*Pav./A; % use zero-to-infinity analytical formula
else % analytical formula by pieces
    stepN = (Pav./A).*( exp(-A.*t1) - exp(-A.*t2) );
    Nsp = sum(stepN).*cs.tsf;
    % go to infinity at end of calculation
    finalt1 = max(cs.tv);
    finalP = cs.P_sp_t(end);
    finalN = (finalP./A).*(exp(-A.*finalt1));
    Nsp = Nsp + finalN;
end;
    

% Diagnostic return option
if strcmp(dFlag,'yes');
    miss.ver = ver;
    miss.Nmu = Nmu;
    miss.Nsp = Nsp;
    if length(cs.P_sp_t) == 1;
        miss.expected_Nsp = cs.tsf.*cs.P_sp_t./A;
        miss.PP = cs.P_sp_t;
    end;
    miss.A = A;
    miss.tsf = cs.tsf;
    miss.PP = cs.P_sp_t;
else;
    N = Nmu + Nsp;
    miss = target - N;
end;
