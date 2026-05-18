function out = P10fit(tryP,sites,consts,dFlag)

% Computes least-squares misfit between calculated and true ages for a
% particular value of the reference spallogenic production rate
%
% syntax: out = pfit(tryP,sites,dFlag, mask);
% 
% tryP is the value of the reference production rate
% sites is a data structure with all of the input data
% consts is the al-be constants data file
% dFlag is either 0 or 1
%
% if dflag = 0, out is 5 misfit statistics
%
% if dFlag = 1, out is a data structure with the predicted ages of
% the sites and their uncertainties.
% 
% This version spits out 5 outputs so can't be used with fzero or whatever.
% This version -- no mask capability. 

% Note: need to add code to this so that it deals with zero-age calibration
% measurements. 
% 
% Greg Balco
% Berkeley Geochronology Center
% Last checked June 2016

ver = '2.2-dev';

if nargin < 4; dFlag = 0; end;

npts = length(sites.lat);

% Scaling factors

sfa = ['St';'De';'Du';'Li';'Lm'];

for sf = 1:5; 
    % Create output structure
    eval(['ages.calct_' sfa(sf,:) ' = zeros(1,npts);']);
    eval(['ages.delcalct_' sfa(sf,:) ' = zeros(1,npts);']);
    % Place the supplied production rate into the constants
    eval(['consts.P10_ref_' sfa(sf,:) ' = tryP;']);
end;

% Forward calculate the ages

for a = 1:npts;
    % Load the input data structure
    sample.sample_name = 'Irrelevant';
    
    sample.lat = sites.lat(a);
    sample.long = sites.long(a);
    
    sample.aa = sites.aa{a};
    if strcmp(sites.aa{a},'std') | strcmp(sites.aa{a},'ant')
			% store the elevation value
			sample.elv = sites.elv(a);
	elseif  strcmp(sites.aa{a},'pre')
			% store the pressure value
			sample.pressure = sites.pressure(a);
	end;
    
    sample.thick = sites.thick(a);
    sample.rho = sites.rho(a);
    sample.othercorr = sites.othercorr(a);
    sample.E = sites.E(a);
    
    sample.N10 = sites.N10(a);
    sample.delN10 = sites.delN10(a); 
    % Don't do Al-26
    sample.N26 = 0;
    sample.delN26 = 0;
    
    % get the data
    
    results = get_al_be_age(sample,consts,10);
    
    % store the age and uncertainty
    for sf = 1:5;
        % What to do in zero-age situation?
        eval(['ages.calct_' sfa(sf,:) '(a) = results.t_' sfa(sf,:) ';']);
        % Use the internal uncertainty
        eval(['ages.delcalct_' sfa(sf,:) '(a) = results.delt_int_' sfa(sf,:) ';']);
    end;
end;

% Done calculating ages
% Now calculate the misfits
    
for sf = 1:5;
    
    eval(['this_ages = ages.calct_' sfa(sf,:) ';']);
    eval(['this_delages = ages.delcalct_' sfa(sf,:) ';']);
    
    % Vector direction flips;
    this_ages = reshape(this_ages,size(sites.truet));
    this_delages = reshape(this_delages,size(sites.deltruet));
    
    eval(['chi2_' sfa(sf,:) ' = ((this_ages-sites.truet)./(sqrt(this_delages.^2 + sites.deltruet.^2))).^2;']);
    
end;
    
if dFlag == 1;
    out = ages;
    out.P10fit_ver = ver;
    out.get_age_ver = results.main_version;
    out.muon_ver = results.muon_version;
elseif dFlag == 0;
    % Out is the reduced chi-square statistic, basically
	for sf = 1:5;
        if npts > 1;
            eval(['out.' sfa(sf,:) '= sum(chi2_' sfa(sf,:) ')./(npts-1);']);
        else
            eval(['out.' sfa(sf,:) '= sum(chi2_' sfa(sf,:) ');']);
            out.errors = 'Note: only one calibration sample -- reduced chi-squared is meaningless';
        end;
    end;
end;
    
