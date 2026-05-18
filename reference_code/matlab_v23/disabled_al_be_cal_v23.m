function retstr = al_be_cal_v23(ins,localFlag)

% Al-Be EXPOSURE AGE CALCULATOR
% PRODUCTION RATE CALIBRATION
% 
% Version 2.3
% Version 2.3 just has new muon interaction cross-sections. 
% 
% This is the wrapper script for the production rate calibration in the
% exposure age calculators. It checks the input calibration data, passes 
% it to other functions to calculate the production rates, then repackages
% the data and returns the output HTML. 
%
% syntax: retstr = al_be_cal_v23(ins,localFlag)
%
% The input structure contains three things: ins.calib_block, which is 
% the big block of text from the 'calibration data' field, ins.calib_name,
% which is a user-supplied text string identifying the calibration data set,
% and ins.requesting_IP, which is the IP address of the requesting
% machine handed down from the web server. The latter is used to write a
% log entry.
%
% localFlag is an optional diagnostic flag -- enter 1 to disable 
% web-server-specific actions.
%
% The output string retstr is an HTML document containing the results of 
% calculations. . See the MATLAB web server documentation for more info on
% exactly how this works. 
%
% Written by Greg Balco -- Berkeley Geochronology Center
% balcs@u.washington.edu -- balcs@bgc.org
% March, 2008
% Part of the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/
%
% Copyright 2001-2007, University of Washington
% Copyright 2007-, Greg Balco
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This software is under development and is not licensed for distribution. 


% Notes: IT WOULD BE GOOD TO MOVE THE DATA CHECKING INTO SUBROUTINES
% Fix up P10fit to handle zero-age samples -- this also requires
% mods to input data checking. 
% Get elevations from calib data set where only pressures submitted -- plot
% against pressure instead? 

% Sort local flag

if nargin < 2; localFlag = 0;end;

%% Setup cell

% 0. What version is this file. 

ver = '2.3-cal';

% get in the correct directory

if localFlag == 0;
    cd /var/www/html/math/al_be_v23
end;

% initialize the diagnostics string

dstring = '';

% Parse the calib text block using strtok

remains = ins.calib_block;
k = 1;

while true;
        [parsed_text_c{k}, remains] = strtok(remains);
        if isempty(parsed_text_c{k}); break; end;
        k = k+1;
end;

numitems_c = size(parsed_text_c,2) -1;
parsed_text_c = parsed_text_c(1:numitems_c);


% Here define the number of items per row -- 
% change this value if more input data added in future. 

numcols_c = 17; % Calib block has additional two columns for truet and deltruet

% Load up the constants.
% Change file name to make sure you get the right ones

load al_be_consts_v23;

% Scaling factors

sfa = ['St';'De';'Du';'Li';'Lm'];


%% ---------- START DATA CHECKING AND LOADING FOR CALIB DATA --------------


if mod(numitems_c,numcols_c) ~= 0;
	retstr = dump_error_HTML('al_be_cal_v23: Wrong total number of data elements in calibration data block -- check for missing data, extra data, or white space within a single element');return;
end;

% if passed that, get number of samples -- 

numsamples_c = numitems_c./numcols_c;

% Data checking loop. 
% Select a row, check the strings to see if they are permissible, then 
% turn them into numbers. Check if the numbers are permissible. Finally,
% store them in an array for each input variable. 

for a = 1:numsamples_c;
	si = (a-1)*numcols_c; % starting index
	
	% 1. Sample name. 
	
	ino = 1; % ino = item number - sample name is item no. 1
	
	% test for length
	if length(parsed_text_c{si+ino}) > 24;
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - sample name more than 24 characters - line ' int2str(a)]);return;
	end;
	
	% test for illegal characters in sample name
	% this allows letters, numbers, underscores, and dashes only. 
	if isempty(regexp(parsed_text_c{si+ino},'[^\w-]'));
		% pass, do assignment
		calib.sample_name{a} = parsed_text_c{si+ino};
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in sample name - line ' int2str(a)] );return;
	end;
		
	% 2. Latitude
	
	ino = 2;
	
	% illegal character test -- 
	% all numerical inputs may contain digits, ., e,E +, -. 
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) > 90 | str2double(parsed_text_c{si+ino}) < -90);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - latitude out of bounds - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable latitude value - line ' int2str(a)] );return;
		end;
		calib.lat(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in latitude - line ' int2str(a)] );return;
	end;

	
	% 3. Longitude
	
	ino = 3;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) > 180 | str2double(parsed_text_c{si+ino}) < -180);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - longitude out of bounds - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable longitude - line ' int2str(a)] );return;
		end;
		calib.long(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in longitude - line ' int2str(a)] );return;
	end;

	
	% 5. Elv/pressure flag -- get this first as it affects checks for (4)
	
	ino = 5;
	
	% must match one of three possible options
	if (strcmp(parsed_text_c{si+ino},'std') | strcmp(parsed_text_c{si+ino},'ant') | strcmp(parsed_text_c{si+ino},'pre') );
		% pass
		calib.aa{a} = parsed_text_c{si+ino};
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - unknown elv/pressure flag - line ' int2str(a)] );return;
	end;

	% 4. Elv/pressure
	
	ino = 4;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if strcmp(calib.aa{a},'std') | strcmp(calib.aa{a},'ant')
			if (str2double(parsed_text_c{si+ino}) < -500);
                retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - elevation too low - line ' int2str(a)] );return;
			end; 
		elseif strcmp(calib.aa{a},'pre')
			if (str2double(parsed_text_c{si+ino}) > 1060 | str2double(parsed_text_c{si+ino}) < 0);
                retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - pressure out of reasonable bounds - line ' int2str(a)] );return;
			end;
		end;	
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable elv/pressure value - line ' int2str(a)] );return;
		end;
		% pack either elv or pressure field
		if strcmp(calib.aa{a},'std') | strcmp(calib.aa{a},'ant')
			% store the elevation value
			calib.elv(a) = str2double(parsed_text_c{si+ino});
			calib.pressure(a) = 0;
		elseif  strcmp(calib.aa{a},'pre')
			% store the pressure value
			calib.elv(a) = 0;
			calib.pressure(a) = str2double(parsed_text_c{si+ino});
		end;
			
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in elevation - line ' int2str(a)] );return;
	end;
	
	% 6. Thickness
	
	ino = 6;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - thickness less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable thickness - line ' int2str(a)] );return;
		end;
		calib.thick(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in thickness - line ' int2str(a)] );return;
	end;
	
	% 7. Density
	
	ino = 7;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - density less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable density - line ' int2str(a)] );return;
		end;
		calib.rho(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in density - line ' int2str(a)] );return;
	end;
	
	% 8. Shielding
	
	ino = 8;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0 | str2double(parsed_text_c{si+ino}) > 1);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - shielding out of range - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable shielding - line ' int2str(a)] );return;
		end;
		calib.othercorr(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in shielding - line ' int2str(a)] );return;
	end;
	
	
	% 9. Erosion rate
	
	ino = 9;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - erosion rate less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable erosion rate - line ' int2str(a)] );return;
		end;
		calib.E(a) = str2double(parsed_text_c{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in erosion rate - line ' int2str(a)] );return;
	end;
	
    
    % 12. Be-10 standardization -- get this first 
	
	ino = 12;
	
	% must match something in stds structure
    
    if strmatch(parsed_text_c{si+ino},al_be_consts.be_stds_names,'exact');
        % pass
        calib.std10{a} = parsed_text_c{si+ino};
    else
        % fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - unknown Be-10 standardization identifier - line ' int2str(a)] );return;
    end;
    
    
	% 10. N10
	
	ino = 10;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Be-10 concentration less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable Be-10 concentration - line ' int2str(a)] );return;
		end;
		calib.N10(a) = str2double(parsed_text_c{si+ino});
        
        % Restandardize
        this_std_no = strmatch(calib.std10{a},al_be_consts.be_stds_names,'exact');
        this_std_cf = al_be_consts.be_stds_cfs(this_std_no);
        calib.N10(a) = calib.N10(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in Be-10 concentration - line ' int2str(a)] );return;
	end;
	
	% 11. delN10
	
	ino = 11;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Be-10 uncertainty less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable Be-10 uncertainty - line ' int2str(a)] );return;
		end;
		calib.delN10(a) = str2double(parsed_text_c{si+ino});
        
        % Restandardize
        calib.delN10(a) = calib.delN10(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in Be-10 uncertainty - line ' int2str(a)] );return;
	end;
	
	
    % 15. Al-26 standardization -- get this first 
	
	ino = 15;
	
	% must match something in stds structure
    
     if strmatch(parsed_text_c{si+ino},al_be_consts.al_stds_names,'exact');
        % pass
        calib.std26{a} = parsed_text_c{si+ino};
     else
        % Allow for possibility that it's zero
        if strcmp(parsed_text_c{si+ino},'0');
             % Assign default
             calib.std26{a} = 'KNSTD';
        else
            % fail
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - unknown Al-26 standardization - line ' int2str(a)] );return;
        end;
    end;
    
	% 13. N26
	
	ino = 13;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Al-26 concentration less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable Al-26 concentration - line ' int2str(a)] );return;
		end;
		calib.N26(a) = str2double(parsed_text_c{si+ino});
        
        % Restandardize
        this_std_no = strmatch(calib.std26{a},al_be_consts.al_stds_names,'exact');
        this_std_cf = al_be_consts.al_stds_cfs(this_std_no);
        calib.N26(a) = calib.N26(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in Al-26 concentration - line ' int2str(a)] );return;
	end;
	
	% 14. delN26
	
	ino = 14;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Al-26 uncertainty less than zero - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable Al-26 uncertainty - line ' int2str(a)] );return;
		end;
		calib.delN26(a) = str2double(parsed_text_c{si+ino});
        
        % Restandardize
        calib.delN26(a) = calib.delN26(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in Al-26 uncertainty - line ' int2str(a)] );return;
	end;
	
	% 16. truet
    
    ino = 16;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) <= 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - true exposure age <= 0 - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable true exposure age - line ' int2str(a)] );return;
		end;
		calib.truet(a) = str2double(parsed_text_c{si+ino});

    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in true exposure age - line ' int2str(a)] );return;
	end;
    
    
    % 17. deltruet
    
    ino = 17;
	
	if isempty(regexp(parsed_text_c{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text_c{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - uncertainty in true exposure age < 0 - line ' int2str(a)] );return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text_c{si+ino}));
            retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - un-numericalizable uncert in true age - line ' int2str(a)] );return;
		end;
		calib.deltruet(a) = str2double(parsed_text_c{si+ino});

    else
		% fail
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - illegal characters in uncert in true exposure age - line ' int2str(a)] );return;
	end;
    
    
	% determine which nuclides were submitted --
	
	if calib.N10(a) ~= 0;
		calib_isN10(a) = 1; 
    else
		calib_isN10(a) = 0; 
	end;

	if calib.delN10(a) ~= 0;
		calib_isdelN10(a) = 1; 
    else
		calib_isdelN10(a) = 0; 
	end;
	
	if calib.N26(a) ~= 0;
		calib_isN26(a) = 1; 
    else
		calib_isN26(a) = 0;
	end;

	if calib.delN26(a) ~= 0;
		calib_isdelN26(a) = 1; 
    else
		calib_isdelN26(a) = 0; 
	end;
	
	% catch mismatches;
	
	if (~calib_isN10(a) & ~calib_isN26(a));
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - need either Be-10 or Al-26 concentration - line ' int2str(a)] );return;
	elseif (calib_isN10(a) & ~calib_isdelN10(a)) | (~calib_isN10(a) & calib_isdelN10(a));
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Need both Be-10 concentration and uncertainty - line ' int2str(a)] );return;
	elseif (calib_isN26(a) & ~calib_isdelN26(a)) | (~calib_isN26(a) & calib_isdelN26(a));
        retstr = dump_error_HTML(['al_be_cal_v23: Calibration data block - Need both Al-26 concentration and uncertainty - line ' int2str(a)] );return;
	end;
	
	
	% I think we're done with the data checking now. 
	
end;


% ---------- DONE DATA CHECKING AND LOADING FOR CALIB DATA ---------------


%% ---------- DO THE CALIBRATION ------------------------------------------

    % 1. DO THE CALIBRATION
    
    % OK. Now the structure called 'calib' can be passed repeatedly to
    % P10fit.
    % Define the range of P to consider
    minP = 3; maxP = 5; % Remember operating in 07KNSTD space
    tryP = minP:0.25:maxP; 
    
    for sf = 1:5;
        eval(['fit_' sfa(sf,:) ' = zeros(size(tryP));']);
    end;
    
    tic;
    % Get the fits 
    for a = 1:length(tryP);
        out = P10fit(tryP(a),calib,al_be_consts);
        for sf = 1:5;
            eval(['fit_' sfa(sf,:) '(a) = out.' sfa(sf,:) ';']);
        end;
    end;
    outstr.calib_calc_time = num2str(toc);
    
    if localFlag == 2;
        % This is for debugging.
        retstr.x = tryP;
        for sf = 1:5;
            eval(['retstr.fit_' sfa(sf,:) ' = fit_' sfa(sf,:) ';']);
        end;
        return;
    end;
            
    
    % Do the minimization;
    
    for sf = 1:5;
        % Get the data out
        eval(['thisF = fit_' sfa(sf,:) ';']);
        % Filter to range of 10;
        threshold = 10;
        aa = 1;
        while 1;
            mask = find((thisF-min(thisF)) < threshold);
            if size(mask) >= 5;
                % pass, continue
                break;
            end;
            % not pass, increase threshold
            threshold = threshold * 2;
            if aa > 5; 
                mask = 1:length(thisF); % use all
                break;
            end;
            aa = aa + 1;
        end;
                    
        thisx = tryP(mask); thisy = thisF(mask);
        % 3rd order polynomial fit
        pf = polyfit(thisx,thisy,3); % 3rd order
        % Take the derivative
        dpf = [3*pf(1) 2*pf(2) pf(3)];
        % Minimize
        temp = roots(dpf); 
        thisP10 = temp(find(temp < maxP & temp > minP));
        if length(thisP10) > 1; 
            retstr = dump_error_HTML('Calib data fitting - Too many maxima/minima in reasonable range');return;
        end;
        if length(thisP10) < 1;
            retstr = dump_error_HTML('Calib data fitting - couldn''t find best-fit P in reasonable range');return;
        end;
        eval(['cal_P10_' sfa(sf,:) ' = thisP10;']);
        eval(['pf_' sfa(sf,:) ' = pf;']);
       
        if localFlag == 1;
            % Diagnostic plotting
            cols = ['krgbc'];
            figure(1);
            plot(tryP,thisF,[cols(sf) 'o']); hold on;
            fineP = minP:0.01:maxP;
            plot(fineP,polyval(pf,fineP),cols(sf));
        end;

        % get reduced chi2
        this_chi2 = polyval(pf,thisP10);
         

        % approximate error limits by where reduced chi^2 is min + 1
        clear temp;
        pf2 = pf; 
        pf2(end) = pf(end) - (this_chi2+1);
        
        
        temp = roots(pf2);
        
        closeness = abs(temp - thisP10);
        P10bounds = temp(find(closeness < max(closeness)));
        delP10 = abs(diff(P10bounds)./2);
        eval(['cal_delP10_' sfa(sf,:) ' = delP10;']);
        chisquareds(sf) = this_chi2;
        
    end;
    
    % 2. PUT THE NEW PRODUCTION RATES IN THE CONSTS STRUCTURE
    
    for sf = 1:5;
        eval(['al_be_consts.P10_ref_' sfa(sf,:) ' = cal_P10_' sfa(sf,:) ';']);
        eval(['al_be_consts.delP10_ref_' sfa(sf,:) ' = cal_delP10_' sfa(sf,:) ';']);
        % Al-26 production rates - hard coded 26/10 ratio -- not good
        eval(['al_be_consts.P26_ref_' sfa(sf,:) ' = cal_P10_' sfa(sf,:) '.*(6.1.*1.106);']);
        eval(['al_be_consts.delP26_ref_' sfa(sf,:) ' = cal_delP10_' sfa(sf,:) '.*(6.1.*1.106);']);
    end;  
    
    % Now we are ready to calculate ages. Woohoo!
    
    % 3. OUTPUT STRING DUMP 
    
    % Table form results. This is outstr.calib_results_text.
    % Row format is:
    % <tr> <td>SF</td> <td>P10</td> <td>+/-</td> <td>delP10</td> <td>pcterr</td> <td>reducedchi2</td>
    % <td>P26</td> <td>+/-</td> <td>delP26</td> </tr>
    outstr.calib_results_text = '';
    
    for sf = 1:5;
        eval(['this_P10 = cal_P10_' sfa(sf,:) ';']);
        eval(['this_delP10 = cal_delP10_' sfa(sf,:) ';']);
        eval(['this_P26 = al_be_consts.P26_ref_' sfa(sf,:) ';']);
        eval(['this_delP26 = al_be_consts.delP26_ref_' sfa(sf,:) ';']);
        pcte = 100.*this_delP10./this_P10;
        
        this_str = ['<tr align=center><td align=left>' sfa(sf,:) '</td><td>' sprintf('%0.2f',this_P10) '</td>'];
        this_str = [this_str '<td>+/-</td><td>' sprintf('%0.2f',this_delP10) '</td>'];
        this_str = [this_str '<td>' sprintf('%0.1f',pcte) '</td><td>' sprintf('%0.2f',chisquareds(sf)) '</td>'];
        this_str = [this_str '<td>' sprintf('%0.2f',this_P26) '</td><td>+/-</td>'];
        this_str = [this_str '<td>' sprintf('%0.2f',this_delP26) '</td></tr>'];
        
        outstr.calib_results_text = [outstr.calib_results_text this_str];
    end;
    
    % Don't forget the name
    
    % test for illegal characters in calibration data set name
	% this allows letters, numbers, underscores, white space, and dashes only. 
	if isempty(regexp(ins.calib_name,'[^\w\s-]'));
		% pass, do assignment
		outstr.calib_name = ins.calib_name;
    else
		% fail
        retstr = dump_error_HTML(['Illegal characters in calibration data set name -- letters, numbers, dashes, underscores only']);return;
	end;
    
    % And also the hidden variables to pass to the exposure age calculation
    
    outstr.calib_results_vars = '';
    
    for sf = 1:5;
        eval(['this_P10 = cal_P10_' sfa(sf,:) ';']);
        eval(['this_delP10 = cal_delP10_' sfa(sf,:) ';']);
        eval(['this_P26 = al_be_consts.P26_ref_' sfa(sf,:) ';']);
        eval(['this_delP26 = al_be_consts.delP26_ref_' sfa(sf,:) ';']);
        
        this_str = ['<input type="hidden" name="P10_' sfa(sf,:) '" value="' sprintf('%0.5f',this_P10) '">'];
        this_str = [this_str '<input type="hidden" name="delP10_' sfa(sf,:) '" value="' sprintf('%0.5f',this_delP10) '">'];
        this_str = [this_str '<input type="hidden" name="P26_' sfa(sf,:) '" value="' sprintf('%0.5f',this_P26) '">'];
        this_str = [this_str '<input type="hidden" name="delP26_' sfa(sf,:) '" value="' sprintf('%0.5f',this_delP26) '">'];

        outstr.calib_results_vars = [outstr.calib_results_vars this_str];
    end;
    
    % and the version numbers
    outstr.calib_ver = ver;
    
    % 4. DIAGNOSTIC PLOTS
    
    % 4a. HTML display of fitting plot. This is outstr.calib_fit_plot_text.
    
    % Assemble data structure
    fit_plot.x1 = tryP;
    fit_plot.x2 = minP:0.05:maxP;
    for sf = 1:5;
        eval(['fit_plot.y1_' sfa(sf,:) ' = fit_' sfa(sf,:) ';']);
        eval(['fit_plot.y2_' sfa(sf,:) ' = polyval(pf_' sfa(sf,:) ',fit_plot.x2);']);
    end;
    
    % make plot
    fplotNameString = makeCalOptPlot(fit_plot,localFlag);
    
    % assign the output string -- 
    outstr.calib_fit_plot_text = ['<img src=/scratch/' fplotNameString '.png width=400><br>'];
	outstr.calib_fit_plot_text = [outstr.calib_fit_plot_text '<a href=/scratch/' fplotNameString '.gmt>GMT code for this plot (includes the x,y data)</a><br>'];
	outstr.calib_fit_plot_text = [outstr.calib_fit_plot_text '<a href=/scratch/' fplotNameString '.ps>Postscript version of this plot</a><br>'];
    
    % 4b. HTML display of fit vs. elevation. This is outstr.calib_elevation_plot_text. 
    
    % Assemble data structure
    % Elevations
    elv_data.elvs = calib.elv;
    % Deal with data where pressure was sent in
    need_elvs = find(calib.elv == 0);
    if ~isempty(need_elvs);
        for a = 1:length(need_elvs);
            new_elv(a) = fzero(@(x) stdatm(x)-calib.pressure(need_elvs(a)),0);
        end;
        elv_data.elvs(need_elvs) = new_elv;
    end;
    % Everything else
    for sf = 1:5;
    % P errors
        eval(['elv_data.delPpct_' sfa(sf,:) ' = cal_delP10_' sfa(sf,:) './cal_P10_' sfa(sf,:) ';']);
        
        % t/truet data
        eval(['temp_results = P10fit(cal_P10_' sfa(sf,:) ',calib,al_be_consts,1);']);
        eval(['this_t = temp_results.calct_' sfa(sf,:) ';']);
        eval(['this_delt = temp_results.delcalct_' sfa(sf,:) ';']);
   
        r = this_t./calib.truet;
        drdcalc = (1./calib.truet);
        drdtrue = (this_t./(calib.truet.^2));
        delr = sqrt( (this_delt.*drdcalc).^2 + (calib.deltruet.*drdtrue).^2);
        
        eval(['elv_data.r_' sfa(sf,:) ' = r;']);
        eval(['elv_data.delr_' sfa(sf,:) ' = delr;']);
     end;
    
     % make plot
    elvplotNameString = makeElvPlot(elv_data,localFlag);
    
    % assign the output string -- 
    outstr.calib_elevation_plot_text = ['<img src=/scratch/' elvplotNameString '.png width=700><br>'];
	outstr.calib_elevation_plot_text = [outstr.calib_elevation_plot_text '<a href=/scratch/' elvplotNameString '.gmt>GMT code for this plot (includes the x,y data)</a><br>'];
	outstr.calib_elevation_plot_text = [outstr.calib_elevation_plot_text '<a href=/scratch/' elvplotNameString '.ps>Postscript version of this plot</a><br>'];
    
    % Assign some other out versions
    outstr.P10fit_ver = temp_results.P10fit_ver;
    outstr.get_age_ver = temp_results.get_age_ver;
    outstr.muon_ver = temp_results.muon_ver;
    outstr.consts_ver = al_be_consts.version;
    
    % Make up a trace string to send along to the eventual result page
    
    outstr.trace_string = [' Versions: Cal ' outstr.calib_ver ' P10fit ' outstr.P10fit_ver ' Get-age ' outstr.get_age_ver ' Muons ' outstr.muon_ver ' Consts ' outstr.consts_ver];
    outstr.trace_string = ['Calc date: ' date outstr.trace_string];
    
% ----------- DONE WITH CALIBRATION --------------------------------------
    
% ---------------- BEGIN FINAL DATA DUMP ------------------------------

% dump whatever diagnostics exist -- 

outstr.dstring = dstring;

if localFlag == 0;
    
    % Dump to locations data file. 
    % DISABLED -- DON'T BOTHER FOR CALIBRATION DATA. 

    %dump_location_v2('t',all_lat,all_long);

    % Do some cleanup -- kill image files older than 1 week 

    wscleanup('*.jpg',24*7,'/var/www/html/scratch/');
    wscleanup('*.jpeg',24*7,'/var/www/html/scratch/');
    wscleanup('*.gmt',24*7,'/var/www/html/scratch/');   
    wscleanup('*.ps',24*7,'/var/www/html/scratch/');

    % Write to log file

    % validate requesting_ip form input 

    ip_pattern = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

    if regexp(ins.requesting_ip,ip_pattern);
        this_ip = ins.requesting_ip;
        outstr.this_ip = this_ip;
    else
        this_ip = 'Bad_address';
        outstr.this_ip = 'Bad address';
    end;

    % do the log entry for each sample
    
    for a = 1:numsamples_c;
        log_entry = [this_ip ' cal_v23 ' sprintf('%.4f',calib.lat(a)) ' ' sprintf('%.4f',calib.long(a)) ];
        log_entry = [log_entry ' ' sprintf('%i ',fix(clock))];
	
        write_to_log(log_entry);
    end;

    % Increment the call count
    
    increment_call_count();
    
    % Return the output HTML. 

    templatefile = '/var/www/html/math/al_be_v23/al_be_multiple_cal_v23.html';

    retstr = htmlrep(outstr, templatefile);
else
    retstr = outstr;
end;

% ---------------- END FINAL DATA DUMP ----------------------------
