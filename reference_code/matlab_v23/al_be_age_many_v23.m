function retstr = al_be_age_many_v23(ins,localFlag)

% Al-Be EXPOSURE AGE CALCULATOR
% MULTIPLE SAMPLE INPUT
% 
% Version 2.3
% Version 2.3 includes updated muon interaction cross-sections and default 
% Be-10 and Al-26 production rates. 
% 
% This is the wrapper script for the multiple-sample Be-Al exposure age
% calculator. It checks the input data, passes it to other functions to
% calculate the exposure ages, then repackages the data and returns the
% output HTML. Either follows from a new production rate calibration or 
% uses the default production rate calibration data set. 
%
% syntax: retstr = al_be_age_many_v23(ins,localFlag)
%
% The input structure contains:
% ins.text_block -- the big block of text from the 'sample' paste-in 
% text field in the input HTML
% form
% ins.requesting_IP, -- the IP address of the requesting
% machine handed down from the web server. This is used to write a
% log entry.
% ins.P10_St, ins.delP10_St, etc. and so on -- Be-10 production rates -
% strings
% ins.P26_St, ins.delP16_St, etc. and so on -- Al-26 same
% ins.calib_name - user-supplied name for the calibration data set
%
% localFlag is an optional diagnostic flag -- enter 1 to disable 
% web-server-specific actions.
%
% The output string retstr is an HTML document containing the results of 
% calculations. . See the MATLAB web server documentation for more info on
% exactly how this works. 
%
% Written by Greg Balco -- Berkeley Geochronology Center
% balcs@u.washington.edu
% March, 2008
% Part of what was at the time the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/math
%
% Copyright 2001-2007, University of Washington
% Copyright 2007-08, Greg Balco
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This software is under development and is not licensed for distribution. 
%
% Plotting disabled 20180828. 

% This code needs to do two things: if no calibration supplied, uses
% default calibration. If calibration supplied, uses it. 

% Notes: IT WOULD BE GOOD TO MOVE THE DATA CHECKING INTO SUBROUTINES 

% Sort local flag

if nargin < 2; localFlag = 0;end;

%% Setup cell

% 0. What version is this file. 

ver = '2.3';

% get in the correct directory

if localFlag == 0;
    cd /var/www/html/math/al_be_v23
end;

% Determine whether or not this is a calibration

if isfield(ins,'calib_name')
    % User-supplied calibration
    calibFlag = 1;
else;
    calibFlag = 0;
end;

% initialize the diagnostics string

dstring = '';

% Parse the sample text block using strtok

remains = ins.text_block;
k = 1;

while true;
	[parsed_text{k}, remains] = strtok(remains);
	if isempty(parsed_text{k}); break; end;
	k = k+1;
end;

% Now a text array called parsed_text contains all the 
% separate items from the text block as array elements.

% clear the final empty array elements left by the above loop --
numitems = size(parsed_text,2) - 1;
parsed_text = parsed_text(1:numitems);

% Here define the number of items per row -- 
% change this value if more input data added in future. 

numcols = 15; % Two columns are added here: Be and Al standards;

% Load up the constants.
% Change file name to make sure you get the right ones

load al_be_consts_v23;

% Scaling factors

sfa = ['St';'De';'Du';'Li';'Lm'];

%% ------------ DATA CHECKING AND LOADING FOR UNKNOWNS -----------------

% check for correct number of items --

if mod(numitems,numcols) ~= 0;
	retstr = dump_error_HTML('al_be_age_many_v23: Wrong total number of data elements in unknowns block -- check for missing data, extra data, or white space within a single element');
    return;
end;

% if passed that, get number of samples -- 

numsamples = numitems./numcols;

% Data checking loop. 
% Select a row, check the 15 strings to see if they are permissible, then 
% turn them into numbers. Check if the numbers are permissible. Finally,
% store them in an array for each input variable. 

for a = 1:numsamples;
	si = (a-1)*numcols; % starting index
	
	% 1. Sample name. 
	
	ino = 1; % ino = item number - sample name is item no. 1
	
	% test for length
	if length(parsed_text{si+ino}) > 24;
		retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - Sample name more than 24 characters');
        return;
	end;
	
	% test for illegal characters in sample name
	% this allows letters, numbers, underscores, and dashes only. 
	if isempty(regexp(parsed_text{si+ino},'[^\w-]'));
		% pass, do assignment
		all_sample_name{a} = parsed_text{si+ino};
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in sample name - line ' int2str(a)]);
        return;
	end;
		
	% 2. Latitude
	
	ino = 2;
	
	% illegal character test -- 
	% all numerical inputs may contain digits, ., e,E +, -. 
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) > 90 | str2double(parsed_text{si+ino}) < -90);
    			retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - latitude out of bounds');
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - un-numericalizable latitude value');
            return;
		end;
		all_lat(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in latitude - line ' int2str(a)]);
        return;
	end;

	
	% 3. Longitude
	
	ino = 3;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) > 180 | str2double(parsed_text{si+ino}) < -180);
    			retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - longitude out of bounds');
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - un-numericalizable longitude value');
            return;
		end;
		all_long(a) = str2double(parsed_text{si+ino});
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in longitude - line ' int2str(a)]);
        return;
	end;

	
	% 5. Elv/pressure flag -- get this first as it affects checks for (4)
	
	ino = 5;
	
	% must match one of three possible options
	if (strcmp(parsed_text{si+ino},'std') | strcmp(parsed_text{si+ino},'ant') | strcmp(parsed_text{si+ino},'pre') );
		% pass
		all_aa{a} = parsed_text{si+ino};
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - unknown elevation/pressure flag - line ' int2str(a)]);
        return;
	end;

	% 4. Elv/pressure
	
	ino = 4;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if strcmp(all_aa{a},'std') | strcmp(all_aa{a},'ant')
			if (str2double(parsed_text{si+ino}) < -500);
    				retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - elevation too low -- line ' int2str(a)]);
                    return;
			end; 
		elseif strcmp(all_aa{a},'pre')
			if (str2double(parsed_text{si+ino}) > 1060 | str2double(parsed_text{si+ino}) < 0);
    				retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - pressure out of reasonable bounds -- line ' int2str(a)]);
                    return;
			end;
		end;	
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
				retstr = dump_error_HTML('al_be_age_many_v23: Unknowns data block - un-numericalizable elev/pressure value');
                return;
		end;
		% pack either elv or pressure field
		if strcmp(all_aa{a},'std') | strcmp(all_aa{a},'ant')
			% store the elevation value
			all_elv(a) = str2double(parsed_text{si+ino});
			all_pressure(a) = 0;
		elseif  strcmp(all_aa{a},'pre')
			% store the pressure value
			all_elv(a) = 0;
			all_pressure(a) = str2double(parsed_text{si+ino});
		end;
			
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in elevation/pressure - line ' int2str(a)]);
        return;
	end;
	
	% 6. Thickness
	
	ino = 6;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - thickness less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable thickness value - line ' int2str(a)]);
            return;
		end;
		all_thick(a) = str2double(parsed_text{si+ino});
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in thickness - line ' int2str(a)]);
        return;
	end;
	
	% 7. Density
	
	ino = 7;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - density less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable density value - line ' int2str(a)]);
            return;
		end;
		all_rho(a) = str2double(parsed_text{si+ino});
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in density - line ' int2str(a)]);
        return;
	end;
	
	% 8. Shielding
	
	ino = 8;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0 | str2double(parsed_text{si+ino}) > 1);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - shielding correction out of range - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable shielding value - line ' int2str(a)]);
            return;
		end;
		all_othercorr(a) = str2double(parsed_text{si+ino});
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in shielding correction - line ' int2str(a)]);
        return;
	end;
	
	
	% 9. Erosion rate
	
	ino = 9;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - erosion rate less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable erosion rate - line ' int2str(a)]);
            return;
		end;
		all_E(a) = str2double(parsed_text{si+ino});
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in erosion rate - line ' int2str(a)]);
        return;
	end;
	
    
    % 12. Be-10 standardization -- get this first 
	
	ino = 12;
	
	% must match something in stds structure
    
    if strmatch(parsed_text{si+ino},al_be_consts.be_stds_names,'exact');
        % pass
        all_std10{a} = parsed_text{si+ino};
    else
        % fail
        retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - unknown Be-10 reference standard identifier - line ' int2str(a)]);
        return;
    end;
    
    
    
	% 10. N10
	
	ino = 10;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - Be-10 concentration less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable Be-10 concentration - line ' int2str(a)]);
            return;
		end;
		all_N10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std10{a},al_be_consts.be_stds_names,'exact');
        this_std_cf = al_be_consts.be_stds_cfs(this_std_no);
        all_N10(a) = all_N10(a).*this_std_cf;
        
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in Be-10 concentration - line ' int2str(a)]);
        return;
	end;
	
	% 11. delN10
	
	ino = 11;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - Be-10 uncertainty less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable Be-10 uncertainty - line ' int2str(a)]);
            return;
		end;
		all_delN10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN10(a) = all_delN10(a).*this_std_cf;
        
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in Be-10 uncertainty - line ' int2str(a)]);
        return;
	end;
	
	
    % 15. Al-26 standardization -- get this first 
	
	ino = 15;
	
	% must match something in stds structure
    
     if strmatch(parsed_text{si+ino},al_be_consts.al_stds_names,'exact');
        % pass
        all_std26{a} = parsed_text{si+ino};
     else
        % fail
        retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - unknown Al-26 reference standard identifier - line ' int2str(a)]);
        return;
    end;
    
	% 13. N26
	
	ino = 13;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - Al-26 concentration less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable Al-26 concentration - line ' int2str(a)]);
            return;
		end;
		all_N26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std26{a},al_be_consts.al_stds_names,'exact');
        this_std_cf = al_be_consts.al_stds_cfs(this_std_no);
        all_N26(a) = all_N26(a).*this_std_cf;
        
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in Al-26 concentration - line ' int2str(a)]);
        return;
	end;
	
	% 14. delN26
	
	ino = 14;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - Al-26 uncertainty less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - un-numericalizable Al-26 uncertainty - line ' int2str(a)]);
            return;
		end;
		all_delN26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN26(a) = all_delN26(a).*this_std_cf;
        
    else
		% fail
		retstr = dump_error_HTML(['al_be_age_many_v23: Unknowns data block - illegal characters in Al-26 uncertainty - line ' int2str(a)]);
        return;
	end;
	
	
	% determine which nuclides were submitted --
	
	if all_N10(a) ~= 0;
		all_isN10(a) = 1; 
	else;
		all_isN10(a) = 0; 
	end;

	if all_delN10(a) ~= 0;
		all_isdelN10(a) = 1; 
	else;
		all_isdelN10(a) = 0; 
	end;
	
	if all_N26(a) ~= 0;
		all_isN26(a) = 1; 
	else;
		all_isN26(a) = 0;
	end;

	if all_delN26(a) ~= 0;
		all_isdelN26(a) = 1; 
	else;
		all_isdelN26(a) = 0; 
	end;
	
	% catch mismatches;
	
	if (~all_isN10(a) & ~all_isN26(a));
   		retstr = dump_error_HTML(['Unknowns data block - need either Be-10 or Al-26 concentration - line ' int2str(a)]); return;
	elseif (all_isN10(a) & ~all_isdelN10(a)) | (~all_isN10(a) & all_isdelN10(a));
    		retstr = dump_error_HTML(['Unknowns data block - need both Be-10 concentration and uncertainty - line ' int2str(a)]); return;
	elseif (all_isN26(a) & ~all_isdelN26(a)) | (~all_isN26(a) & all_isdelN26(a));
    		retstr = dump_error_HTML(['Unknowns data block - need both Al-26 concentration and uncertainty - line ' int2str(a)]);return;
	end;
	
	
	% I think we're done with the data checking now. 
	
end;

% ---------- DONE DATA CHECKING AND LOADING FOR UNKNOWNS -----------------

% ----------- DATA CHECKING AND LOADING FOR CALIBRATION DATA -------------

if calibFlag == 1; 
    % User-supplied calibration
    % Lots of stuff to do
    
    % Start by checking the long input strings
    
    % test for illegal characters in calibration data set name
	% this allows letters, numbers, white space, underscores, and dashes only. 
	if isempty(regexp(ins.calib_name,'[^\w\s-]'));
		% pass, do assignment
		outstr.calib_name = ins.calib_name;
    else
		% fail
		retstr = dump_error_HTML(['Illegal characters in calibration data set name - stick with letters, numbers, dashes']);return;
	end;
    
    % test for illegal characters in calibration tracking string
	% this allows letters, numbers, white space, underscores, and dashes only. 
	if isempty(regexp(ins.trace_string,'[^\w\s-.:]'));
		% pass, do assignment
		outstr.trace_string = ins.trace_string;
    else
		% fail
		retstr = dump_error_HTML(['Illegal characters in calibration data set name - stick with letters, numbers, dashes']);return;
	end;
    
    % Loop through the scaling factors and extract stuff
    items = strvcat('P10_','delP10_','P26_','delP26_');
    for sf = 1:5;
        for item = 1:4;
            % Get the item
            this_item_name = [deblank(items(item,:)) sfa(sf,:)];
            eval(['this_item_str = ins.' this_item_name ';']);
            % Check  - allow digits and decimal point
            if isempty(regexp(this_item_str,'[^\d.]'));
                % pass
                % test for bounds
                if (str2double(this_item_str) < 0);
                    retstr = dump_error_HTML(['Production rate inputs - ' this_item_name ' less than zero']);return;
                end; 
                % cover other eventualities
                if isnan(str2double(this_item_str));
                    retstr = dump_error_HTML(['Production rate inputs - ' this_item_name ' can''t be numericalized']);return;
                end;
                % Pass all - assign
                eval(['cal_data.' this_item_name ' = str2double(this_item_str);']);
            else
                % fail
                retstr = dump_error_HTML(['Production rate inputs - illegal characters in ' this_item_name]);return;
            end;        
        end;
    end;
    
    % Place stuff in consts structure
    
    for sf = 1:5;
        eval(['al_be_consts.P10_ref_' sfa(sf,:) ' = cal_data.P10_' sfa(sf,:) ';']);
        eval(['al_be_consts.delP10_ref_' sfa(sf,:) ' = cal_data.delP10_' sfa(sf,:) ';']);
        eval(['al_be_consts.P26_ref_' sfa(sf,:) ' = cal_data.P26_' sfa(sf,:) ';']);
        eval(['al_be_consts.delP26_ref_' sfa(sf,:) ' = cal_data.delP26_' sfa(sf,:) ';']);
    end;
    
    % Set the output calibration string description
    outstr.cal_string = ['Using user-supplied calibration data set<br>Name: ' outstr.calib_name '<br>Trace string: ' outstr.trace_string];
else
    % Use default calibration -- don't do anything, just say so
    outstr.cal_string = ['Using default calibration data set'];
end;

% ----------- DONE CALIB DATA CHECKING AND LOADING 

%% ------------- START SAMPLE CALCULATIONS --------------------------------

% Now do some calculations

% main calculation loop

for a = 1:numsamples;
	% create the sample structure;
	sample.sample_name = all_sample_name{a};
	sample.lat = all_lat(a);
	sample.long = all_long(a);
	sample.aa = all_aa{a};
	if strcmp(all_aa{a},'std') | strcmp(all_aa{a},'ant')
			% store the elevation value
			sample.elv = all_elv(a);
	elseif  strcmp(all_aa{a},'pre')
			% store the pressure value
			sample.pressure = all_pressure(a);
	end;
	sample.thick = all_thick(a);
	sample.rho = all_rho(a);
	sample.othercorr = all_othercorr(a);
	sample.E = all_E(a);
	if all_isN10(a);
		sample.N10 = all_N10(a);
		sample.delN10 = all_delN10(a);
	end;
	if all_isN26(a);
		sample.N26 = all_N26(a);
		sample.delN26 = all_delN26(a);
	end;
	
	% Get the exposure ages;
	
	if (all_isN10(a)); be_results = get_al_be_age(sample,al_be_consts,10); end;
	if (all_isN26(a)); al_results = get_al_be_age(sample,al_be_consts,26); end;
	
	% if both nuclides, get the ratios and uncertainty therein;

	clear drdN26 drdN10;
	if (all_isN10(a) & all_isN26(a));
    		r2610(a) = sample.N26./sample.N10;
    		drdN26 = 1./sample.N10;
    		drdN10 = -sample.N26./(sample.N10.^2);
    		delR(a) = sqrt( (sample.delN10.*drdN10).^2 + (sample.delN26.*drdN26).^2 );
	end;
	
	
	% sort the results that will appear in multiple-sample output;
   
    
	if(all_isN10(a));
        % Non-SF-dependent
        thick_sf(a) = be_results.thick_sf;
        P10_mu(a) = be_results.P_mu;
        % Scalar producion rate from Stone/Lal
        P10_St(a) = be_results.P_St;
		% SF-dependent
        for b = 1:5;
            eval(['t10_' sfa(b,:) '(a) = be_results.t_' sfa(b,:) ';']);
            eval(['FSF10_' sfa(b,:) '(a) = be_results.FSF_' sfa(b,:) ';']);
            eval(['delt10_int_' sfa(b,:) '(a) = be_results.delt_int_' sfa(b,:) ';']);
            eval(['delt10_ext_' sfa(b,:) '(a) = be_results.delt_ext_' sfa(b,:) ';']);
        end;
        % Add output flags to dstring
        if ~isempty(be_results.flags);
            dstring = [dstring ' ' be_results.flags '<br>'];
        end;
	end;
    
	if(all_isN26(a));
		% Non-SF-dependent
        thick_sf(a) = al_results.thick_sf;
        P26_mu(a) = al_results.P_mu;
        % Scalar producion rate from Stone/Lal
        P26_St(a) = al_results.P_St;
		% SF-dependent
        for b = 1:5;
            eval(['t26_' sfa(b,:) '(a) = al_results.t_' sfa(b,:) ';']);
            eval(['FSF26_' sfa(b,:) '(a) = al_results.FSF_' sfa(b,:) ';']);
            eval(['delt26_int_' sfa(b,:) '(a) = al_results.delt_int_' sfa(b,:) ';']);
            eval(['delt26_ext_' sfa(b,:) '(a) = al_results.delt_ext_' sfa(b,:) ';']);
        end;
        % Add output flags to dstring
        if ~isempty(al_results.flags);
            dstring = [dstring ' ' al_results.flags '<br>'];
        end;
	end;
	
	
	clear sample;
	
end; % End of main calculation loop -- 

% ---------------- DONE DOING AGE CALCULATIONS ------------------------

% -------------- START CALCULATION OUTPUT ASSEMBLY ---------------------

% start output string extraction...

% A. Things that are the same for all samples and can be extracted from the most 
% recent results set:

outstr.wrapper_version = ver;
outstr.consts_version = al_be_consts.version;
if (all_isN10(a));
    outstr.main_version = be_results.main_version;
    outstr.muon_version = be_results.muon_version;
else
    outstr.main_version = al_results.main_version;
    outstr.muon_version = al_results.muon_version;
end;
	
% B. Strings for exposure-age reporting. 

% Correction factors, Be-10 results, Lal/Stone production rate scaling

outstr.results_10_ntd = '';

for a = 1:numsamples;
	if (all_isN10(a));
		% if Be-10 data, write a full line
        % Line is sample_name - t10_St - delt10_int_St - delt10_ext_St -
        % thickSF - othercorr - P10_sp - P10_mu
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
		temp = [temp '</td><td>' sprintf('%8.4f',thick_sf(a))];
        temp = [temp '</td><td>' sprintf('%8.4f',all_othercorr(a))];
		temp = [temp '</td><td>' sprintf('%8.3f',P10_mu(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt10_int_St(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',t10_St(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt10_ext_St(a))];
        temp = [temp '</td><td>' sprintf('%8.2f',P10_St(a)) '</td></tr>'];
        outstr.results_10_ntd = [outstr.results_10_ntd temp];
	else 
		% if no Be-10 data, write a table line anyway
    	outstr.results_10_ntd = [outstr.results_10_ntd '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% Al-26 results, Lal/Stone production rate scaling.

outstr.results_26_ntd = '';

for a = 1:numsamples;
	if (all_isN26(a));
		% if Al-26 data, write a full line
        % Line is sample_name - t26_St - delt26_int_St - delt26_ext_St -
        % thickSF - othercorr - P26_sp - P26_mu
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
		temp = [temp '</td><td>' sprintf('%8.4f',thick_sf(a))];
        temp = [temp '</td><td>' sprintf('%8.4f',all_othercorr(a))];
		temp = [temp '</td><td>' sprintf('%8.3f',P26_mu(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt26_int_St(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',t26_St(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt26_ext_St(a))];
        temp = [temp '</td><td>' sprintf('%8.2f',P26_St(a)) '</td></tr>'];
		outstr.results_26_ntd = [outstr.results_26_ntd temp];
	else 
		% if no Al-26 data, write a table line anyway
    	outstr.results_26_ntd = [outstr.results_26_ntd '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% Be-10 results, time-dependent scaling schemes

outstr.results_10_td = '';

for a = 1:numsamples;
	if (all_isN10(a));
		% if Be-10 data, write a full line
        % Line is sample_name - t10_De - delt10_ext_De - t10_Du -
        % delt10_ext_Du - t10_Li - delt10_ext_Li
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
		temp = [temp '</td><td>' sprintf('%8.0f',t10_De(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt10_ext_De(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',t10_Du(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt10_ext_Du(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',t10_Li(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt10_ext_Li(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',t10_Lm(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt10_ext_Lm(a)) '</td></tr>'];
		outstr.results_10_td = [outstr.results_10_td temp];
	else 
		% if no Be-10 data, write a table line anyway
    	outstr.results_10_td = [outstr.results_10_td '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% Al-26 results, time-dependent scaling schemes

outstr.results_26_td = '';

for a = 1:numsamples;
	if (all_isN26(a));
		% if Al-26 data, write a full line
        % Line is sample_name - t26_De - delt26_ext_De - t26_Du -
        % delt26_ext_Du - t26_Li - delt26_ext_Li
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
		temp = [temp '</td><td>' sprintf('%8.0f',t26_De(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',delt26_ext_De(a))];
		temp = [temp '</td><td>' sprintf('%8.0f',t26_Du(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt26_ext_Du(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',t26_Li(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt26_ext_Li(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',t26_Lm(a))];
        temp = [temp '</td><td>' sprintf('%8.0f',delt26_ext_Lm(a)) '</td></tr>'];
		outstr.results_26_td = [outstr.results_26_td temp];
	else 
		% if no Al-26 data, write a table line anyway
    	outstr.results_26_td = [outstr.results_26_td '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% 26/10 ratio and uncertainty

outstr.results_R = '';

for a = 1:numsamples;
	if (all_isN10(a) & all_isN26(a));
    		temp = ['<tr><td>' all_sample_name{a} '</td><td align=center>'];
		temp = [temp sprintf('%4.2f',r2610(a)) ' +/- ' sprintf('%4.2f',delR(a)) '</td></tr>'];
	else;
    		temp = ['<tr><td>' all_sample_name{a} '</td><td align=center> -- </td></tr>'];
	end;
	outstr.results_R = [outstr.results_R temp];
end;


% All plotting disabled 20180828. 

if 0;

% Make the splot. 

% First, figure out which samples have both measurements.

cs = all_isN10 & all_isN26; % cs = can splot
cs_index = find(cs);

if isempty(cs_index);
	% no samples to splot
	outstr.splotName = '(No Al-26 / Be-10 plot)';
	outstr.splotGmtName = '';
	outstr.splotPsName = ''; 
else
	% splot the samples. 
	% create the data structure --
	% first the scalar elements --
	pdata.l10 = al_be_consts.l10;
    pdata.l26 = al_be_consts.l26;
    pdata.Lsp = al_be_consts.Lsp;
	% now the vector elements --
	pdata.N26_norm = all_N26(cs_index) ./ (P26_St(cs_index)+P26_mu(cs_index));
    pdata.N10_norm = all_N10(cs_index) ./ (P10_St(cs_index)+P10_mu(cs_index));
    pdata.delN10_norm = pdata.N10_norm .* all_delN10(cs_index) ./ all_N10(cs_index);
    pdata.delN26_norm = pdata.N26_norm .* all_delN26(cs_index) ./ all_N26(cs_index);

	% call the plotting function --
	splotNameString = makeEplot(pdata,localFlag);
    
	% assign the output variables -- 
    outstr.splotName = ['<img src=/scratch/' splotNameString '.jpg width=500>'];
	outstr.splotGmtName =  ['<a href=/scratch/' splotNameString '.gmt>GMT code for this plot (includes the x,y data)</a>'];
	outstr.splotPsName = ['<a href=/scratch/' splotNameString '.ps>Postscript version of this plot</a>'];
end;     

% If there is only one sample, make bonus plots: Rc(t), P(t), and SF
% comparison plot.

% Start with the P(t) plot.

if numsamples == 1;
    
    % determine which results to use...
    
    if exist('be_results','var');
        isPos10 = (max([be_results.t_St be_results.t_De be_results.t_Du be_results.t_Li be_results.t_Lm]) > 0);
    else 
        isPos10 = 0;
    end;
    if exist('al_results','var');
        isPos26 = (max([al_results.t_St al_results.t_De al_results.t_Du al_results.t_Li al_results.t_Lm]) > 0);
    else 
        isPos26 = 0;
    end;   
    
    if isPos10 > 0;
        PTresults = be_results;
    elseif isPos26 > 0;
        PTresults = al_results;
    end;
    
    if exist('PTresults');
        PTdata.tv = PTresults.tv; 
    
        PTdata.Rc_De = PTresults.Rc_De;
        PTdata.Rc_Du = PTresults.Rc_Du;
        PTdata.Rc_Li = PTresults.Rc_Li;
        PTdata.Rc_Lm = PTresults.Rc_Lm;
    
        PTdata.P10_St = PTresults.P_St;
        PTdata.P10_De = PTresults.P_De;
        PTdata.P10_Du = PTresults.P_Du;
        PTdata.P10_Li = PTresults.P_Li;
        PTdata.P10_Lm = PTresults.P_Lm;
    
        PTNameString = makePofTplot(PTdata,localFlag);
    
        outstr.tplotName = ['<img src=/scratch/' PTNameString '.jpg width=500>'];
        outstr.tplotGmtName =  ['<a href=/scratch/' PTNameString '.gmt>GMT code for this plot (includes the x,y data points)</a>'];
        outstr.tplotPsName = ['<a href=/scratch/' PTNameString '.ps>Postscript version of this plot</a>'];
    else
        outstr.tplotName = 'Nothing to plot';
        outstr.tplotGmtName =  '';
        outstr.tplotPsName = '';
    end;
else % Multiple samples; no plot
    outstr.tplotName = 'Multiple samples -- no plot';
    outstr.tplotGmtName =  '';
    outstr.tplotPsName = '';
end;
   

% Followed by the age-comparison plot

if numsamples == 1;
    if exist('be_results','var');
        % load Be structure
        for a = 1:5;
            eval(['compData10.t(a) = be_results.t_' sfa(a,:) ';']);
            eval(['compData10.delt_int(a) = be_results.delt_int_' sfa(a,:) ';']);
            eval(['compData10.delt_ext(a) = be_results.delt_ext_' sfa(a,:) ';']);
        end;
    else
        compData10 = 0;
    end;
    if exist('al_results','var');
        % load Al structure
        for a = 1:5;
            eval(['compData26.t(a) = al_results.t_' sfa(a,:) ';']);
            eval(['compData26.delt_int(a) = al_results.delt_int_' sfa(a,:) ';']);
            eval(['compData26.delt_ext(a) = al_results.delt_ext_' sfa(a,:) ';']);
        end;
    else
        compData26 = 0;
    end; 
    
    compNameString = makeCplot(compData10,compData26,localFlag);
    
    if compNameString == 0;
        outstr.cplotName = 'Nothing to plot';
        outstr.cplotGmtName =  '';
        outstr.cplotPsName = '';
    else
        outstr.cplotName = ['<img src=/scratch/' compNameString '.jpg width=500>'];
        outstr.cplotGmtName =  ['<a href=/scratch/' compNameString '.gmt>GMT code for this plot (includes the x,y data points)</a>'];
        outstr.cplotPsName = ['<a href=/scratch/' compNameString '.ps>Postscript version of this plot</a>'];
    end;
else % Multiple samples, no plot
    outstr.cplotName = ['Multiple samples -- no comparison plot'];
    outstr.cplotGmtName =  [''];
    outstr.cplotPsName = [''];
end;

end;

% Dummy plot strings

outstr.cplotName = 'Plotting discontinued in this version. Use version 3 instead.';
outstr.cplotGmtName =  '';
outstr.cplotPsName = '';

outstr.tplotName = 'Plotting discontinued in this version. Use version 3 instead.'; 
outstr.tplotGmtName =  ''; 
outstr.tplotPsName = '';

outstr.splotName = 'Plotting discontinued in this version. Use version 3 instead.'; 
outstr.splotGmtName =  ''; 
outstr.splotPsName = '';


% ----------------- END OUTPUT STRING ASSEMBLY ------------------------
    
% ---------------- BEGIN FINAL DATA DUMP ------------------------------

% dump whatever diagnostics exist -- 

outstr.dstring = dstring;

if localFlag == 0;
    
    % Dump to locations data file.  
    dump_location_v2('t',all_lat,all_long);

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
    else
        this_ip = 'Bad_address';
    end;

    % do the log entry for each sample
    for a = 1:numsamples;
        log_entry = [this_ip ' t_many_v23 ' sprintf('%.4f',all_lat(a)) ' ' sprintf('%.4f',all_long(a)) ];
        log_entry = [log_entry ' ' sprintf('%i ',fix(clock))];
	
        write_to_log(log_entry);
    end;

    % Increment the call count
    
    increment_call_count();
    
    % Return the output HTML. 
    if numsamples == 1;
       templatefile = '/var/www/html/math/al_be_v23/al_be_out_full_v23.html';
    else
        templatefile = '/var/www/html/math/al_be_v23/al_be_out_v23.html';
    end;
    retstr = htmlrep(outstr, templatefile);
else
    retstr = outstr;
end;

% ---------------- END FINAL DATA DUMP ----------------------------
