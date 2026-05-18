function retstr = al_be_erosion_many_v23(ins,localFlag)

% Al-Be EROSION RATE CALCULATOR
% MULTIPLE SAMPLE INPUT
% 
% Version 2.3
% Version 2.3 has updated muon interaction cross-sections and default
% production rates for Al-26 and Be-10. The latter are from the 'primary'
% calibration data set of Borchers and others (2016). 
%
% This is the wrapper script for the multiple-sample Be-Al erosion rate
% calculator. It checks the input data, passes it to other functions to
% calculate the erosion rates, then repackages the data and returns the
% output HTML. 
%
% syntax: retstr = al_be_erosion_many_v23(ins,localFlag)
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
% localFlag is an optional argument for local diagnostic use. Set to 1 
% to disable server-specific operations. Not well generalized, may still
% produce errors on many systems. 
%
% The output string retstr is an HTML document. See the MATLAB web server 
% documentation for more info on exactly how this works. 
%
% Written by Greg Balco -- UW Cosmogenic Nuclide Lab
% balcs@u.washington.edu
% March, 2007
% Part of the CRONUS-Earth online calculators: 
%      http://hess.ess.washington.edu/math
%
% Copyright 2001-2007, University of Washington
% 2007-, Greg Balco
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License, version 2,
% as published by the Free Software Foundation (www.fsf.org).
%
% Plotting disabled 20180828.

if nargin < 2; localFlag = 0;end;

% 0. What version is this file. 

ver = '2.3';

% get in the correct directory

% get in the correct directory

if localFlag == 0;
    cd /var/www/html/math/al_be_v23
end;

% Determine whether or not this is a calibration

if isfield(ins,'calib_name')
    % User-supplied calibration
    calibFlag = 1;
else
    calibFlag = 0;
end;

% initialize the diagnostics string

dstring = '';

% Parse the text block using strtok

remains = ins.text_block;
k = 1;

while true;
	
	[parsed_text{k}, remains] = strtok(remains);
	if isempty(parsed_text{k}); break; end;
	k = k+1;
end;
	
% now a text array called parsed_text contains all the 
% separate items from the text block as array elements.

% clear the final empty array element left by the above loop --
numitems = size(parsed_text,2) - 1;
parsed_text = parsed_text(1:numitems);  

% Here define the number of items per row -- 
% change this value if more input data added in future. 

numcols = 14; % Two columns added for Be and Al standards

% Load up the constants.
% Change file name to make sure you get the right ones

load al_be_consts_v23;

% Scaling factors

sfa = ['St';'De';'Du';'Li';'Lm'];

%% ------------ DATA CHECKING AND LOADING FOR UNKNOWNS -----------------

% check for correct number of items --

if mod(numitems,numcols) ~= 0;
    retstr = dump_error_HTML('al_be_erosion_many_v23: Wrong total number of data elements -- check for missing data, extra data, or white space within a single element');return;
end;

% if passed that, get number of samples -- 

numsamples = numitems./numcols;

% Elaborate data checking loop. 
% Select a row, check the 14 strings to see if they are permissible, then 
% turn them into numbers. Check if the numbers are permissible. Finally,
% store them in an array for each input variable. 

for a = 1:numsamples;
	si = (a-1)*numcols; % starting index
	
	% 1. Sample name. 
	
	ino = 1; % item number
	
	% test for length
	if length(parsed_text{si+ino}) > 24;
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Sample name more than 24 characters - line ' int2str(a)]); return;
	end;
	
	% test for illegal characters in sample name
	% this allows letters, numbers, underscores, and dashes only. 
	if isempty(regexp(parsed_text{si+ino},'[^\w-]'));
		% pass, do assignment
		all_sample_name{a} = parsed_text{si+ino};
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in sample name - line ' int2str(a)]); return;
	end;
		
	% 2. Latitude
	
	ino = 2;
	
	% illegal character test -- 
	% all numerical inputs may contain digits, ., e,E +, -. 
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) > 90 | str2double(parsed_text{si+ino}) < -90);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Latitude out of bounds - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable latitude - line ' int2str(a)]); return;
		end;
		all_lat(a) = str2double(parsed_text{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in latitude - line ' int2str(a)]); return;
	end;

	
	% 3. Longitude
	
	ino = 3;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) > 180 | str2double(parsed_text{si+ino}) < -180);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - longitude out of bounds - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable longitude - line ' int2str(a)]); return;
		end;
		all_long(a) = str2double(parsed_text{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in longitude - line ' int2str(a)]); return;
	end;

	
	% 5. Elv/pressure flag -- get this first as it affects checks for (4)
	
	ino = 5;
	
	% must match one of three possible options
	if (strcmp(parsed_text{si+ino},'std') | strcmp(parsed_text{si+ino},'ant') | strcmp(parsed_text{si+ino},'pre') );
		% pass
		all_aa{a} = parsed_text{si+ino};
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unknown elv/pressure flag - line ' int2str(a)]); return;
	end;

	% 4. Elv/pressure
	
	ino = 4;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if strcmp(all_aa{a},'std') | strcmp(all_aa{a},'ant')
			if (str2double(parsed_text{si+ino}) < -500);
                retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - elevation too low - line ' int2str(a)]); return;
			end; 
		elseif strcmp(all_aa{a},'pre')
			if (str2double(parsed_text{si+ino}) > 1060 | str2double(parsed_text{si+ino}) < 0);
                retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - pressure out of reasonable range - line ' int2str(a)]); return;
			end;
		end;	
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable elv/pressure value - line ' int2str(a)]); return;
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
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in elv/pressure field - line ' int2str(a)]); return;
	end;
	
	% 6. Thickness
	
	ino = 6;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - thickness less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable thickness - line ' int2str(a)]); return;
		end;
		all_thick(a) = str2double(parsed_text{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in thickness field - line ' int2str(a)]); return;
	end;
	
	% 7. Density
	
	ino = 7;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - density less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable density - line ' int2str(a)]); return;
		end;
		all_rho(a) = str2double(parsed_text{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in density field - line ' int2str(a)]); return;
	end;
	
	% 8. Shielding
	
	ino = 8;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0 | str2double(parsed_text{si+ino}) > 2);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - shielding out of reasonable range - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable shielding value - line ' int2str(a)]); return;
		end;
		all_othercorr(a) = str2double(parsed_text{si+ino});
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in shielding field - line ' int2str(a)]); return;
	end;
	
	
    % 11. Be-10 standardization -- get this first 
	
	ino = 11;
	
	% must match something in stds structure
    
    if strmatch(parsed_text{si+ino},al_be_consts.be_stds_names,'exact');
        % pass
        all_std10{a} = parsed_text{si+ino};
    else
        % fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unknown Be-10 standardization ID - line ' int2str(a)]); return;
    end;
    
    
	% 9. N10
	
	ino = 9;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Be-10 concentration less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable Be-10 concentration - line ' int2str(a)]); return;
		end;
		all_N10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std10{a},al_be_consts.be_stds_names,'exact');
        this_std_cf = al_be_consts.be_stds_cfs(this_std_no);
        all_N10(a) = all_N10(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in Be-10 concentration - line ' int2str(a)]); return;
	end;
	
	% 10. delN10
	
	ino = 10;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Be-10 uncertainty less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable Be-10 uncertainty - line ' int2str(a)]); return;
		end;
		all_delN10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN10(a) = all_delN10(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in Be-10 uncertainty - line ' int2str(a)]); return;
	end;
	
	
    % 15. Al-26 standardization -- get this first 
	
	ino = 14;
	
	% must match something in stds structure
    
     if strmatch(parsed_text{si+ino},al_be_consts.al_stds_names,'exact');
        % pass
        all_std26{a} = parsed_text{si+ino};
     else
        % fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unknown Al-26 standardization ID - line ' int2str(a)]); return;
    end;
    
	% 11. N26
	
	ino = 12;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Al-26 concentration less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable Al-26 concentration - line ' int2str(a)]); return;
		end;
		all_N26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std26{a},al_be_consts.al_stds_names,'exact');
        this_std_cf = al_be_consts.al_stds_cfs(this_std_no);
        all_N26(a) = all_N26(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in Al-26 concentration - line ' int2str(a)]); return;
	end;
	
	% 12. delN26
	
	ino = 13;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Al-26 uncertainty less than zero - line ' int2str(a)]); return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
            retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - un-numericalizable Al-26 uncertainty - line ' int2str(a)]); return;
		end;
		all_delN26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN26(a) = all_delN26(a).*this_std_cf;
        
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in Al-26 uncertainty - line ' int2str(a)]); return;
	end;
	
	
	% determine which nuclides were submitted --
	
	if all_N10(a) ~= 0;
		all_isN10(a) = 1; 
    else
		all_isN10(a) = 0; 
	end;

	if all_delN10(a) ~= 0;
		all_isdelN10(a) = 1; 
    else
		all_isdelN10(a) = 0; 
	end;
	
	if all_N26(a) ~= 0;
		all_isN26(a) = 1; 
    else
		all_isN26(a) = 0;
	end;

	if all_delN26(a) ~= 0;
		all_isdelN26(a) = 1; 
    else
		all_isdelN26(a) = 0; 
	end;
	
	% catch mismatches;
	
	if (~all_isN10(a) & ~all_isN26(a));
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - need either Be-10 or Al-26 concentration - line ' int2str(a)]); return;
	elseif (all_isN10(a) & ~all_isdelN10(a)) | (~all_isN10(a) & all_isdelN10(a));
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Need both Be-10 concentration and uncertainty - line ' int2str(a)]); return;
	elseif (all_isN26(a) & ~all_isdelN26(a)) | (~all_isN26(a) & all_isdelN26(a));
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - Need both Al-26 concentration and uncertainty - line ' int2str(a)]); return;
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
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in calibration data set name - line ' int2str(a)]); return;
	end;
    
    % test for illegal characters in calibration tracking string
	% this allows letters, numbers, white space, underscores, and dashes only. 
	if isempty(regexp(ins.trace_string,'[^\w\s-.:]'));
		% pass, do assignment
		outstr.trace_string = ins.trace_string;
    else
		% fail
        retstr = dump_error_HTML(['al_be_erosion_many_v23: Unknowns data block - unallowed characters in trace string - line ' int2str(a)]); return;
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
                    retstr = dump_error_HTML(['al_be_erosion_many_v23: Production rate inputs ' this_item_name ' less than zero']); return;
                end; 
                % cover other eventualities
                if isnan(str2double(this_item_str));
                    retstr = dump_error_HTML(['al_be_erosion_many_v23: Production rate inputs ' this_item_name ' can''t be numericalized']); return;
                end;
                % Pass all - assign
                eval(['cal_data.' this_item_name ' = str2double(this_item_str);']);
            else
                % fail
                retstr = dump_error_HTML(['al_be_erosion_many_v23: Production rate inputs ' this_item_name ' -- unallowed characters']); return;
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
	if all_isN10(a);
		sample.N10 = all_N10(a);
		sample.delN10 = all_delN10(a);
	end;
	if all_isN26(a);
		sample.N26 = all_N26(a);
		sample.delN26 = all_delN26(a);
	end;
	
	% Get the erosion rates;
	
	if (all_isN10(a)); be_results = get_al_be_erosion(sample,al_be_consts,10); end;
	if (all_isN26(a)); al_results = get_al_be_erosion(sample,al_be_consts,26); end;
	
	
	% if both nuclides, get the ratios and uncertainty therein;
	% Note: there is math here. Does the error propagation on the ratio. 
	
	clear drdN26 drdN10;
	if (all_isN10(a) & all_isN26(a));
    		r2610(a) = sample.N26./sample.N10;
    		drdN26 = 1./sample.N10;
    		drdN10 = -sample.N26./(sample.N10.^2);
    		delR(a) = sqrt( (sample.delN10.*drdN10).^2 + (sample.delN26.*drdN26).^2 );
	end;
	
	
	% sort the results;
	
	if(all_isN10(a));
		be_Egcm2yr(a,1:5) = be_results.Egcm2yr;     % 5 erosion rates;
		be_EmMyr(a,1:5) = be_results.EmMyr;         % 5 erosion rates in m/Myr
		be_delE_int(a,1:5) = be_results.delE_int;   % 5 int uncerts
		be_delE_ext(a,1:5) = be_results.delE_ext;   % 5 ext uncerts
		be_P_St(a) = be_results.P_St;               % NTD P10 via St
		be_Pmu0(a) = be_results.Pmu0;               % P from muons
		be_fzero_status(a,1:5) = be_results.fzero_status; % Converged?
		be_fval(a,1:5) = be_results.fval;           % Objective function values
		be_time_fzero(a,1:5) = be_results.time_fzero; % Rootfinder times
        be_time_mu_precalc(a) = be_results.time_mu_precalc; % Pmu(z) calculation time
        % Add output flags to dstring
        if ~isempty(be_results.flags);
            dstring = [dstring ' ' be_results.flags '<br>'];
        end;
	end;
	
	if(all_isN26(a));
		al_Egcm2yr(a,1:5) = al_results.Egcm2yr;     % 5 erosion rates;
		al_EmMyr(a,1:5) = al_results.EmMyr;         % 5 erosion rates in m/Myr
		al_delE_int(a,1:5) = al_results.delE_int;   % 5 int uncerts
		al_delE_ext(a,1:5) = al_results.delE_ext;   % 5 ext uncerts
		al_P_St(a) = al_results.P_St;               % NTD P26 via St
		al_Pmu0(a) = al_results.Pmu0;               % P from muons
		al_fzero_status(a,1:5) = al_results.fzero_status; % Converged?
		al_fval(a,1:5) = al_results.fval;           % Objective function values
		al_time_fzero(a,1:5) = al_results.time_fzero; % Rootfinder times
        al_time_mu_precalc(a) = al_results.time_mu_precalc; % Pmu(z) calculation time
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

% Things that are the same for all samples and can be extracted from the most 
% recent results set:

outstr.wrapper_version = ver;
outstr.consts_version = al_be_consts.version;
if (all_isN10(a));
    outstr.main_version = be_results.main_version;
    outstr.obj_version = be_results.obj_version;
    outstr.mu_version = be_results.mu_version;
else;
    outstr.main_version = al_results.main_version;
    outstr.obj_version = al_results.obj_version;
    outstr.mu_version = al_results.mu_version;
end;
	
% Loops for building long html strings...

% 1. Non-time-dependent Be-10 results - sample name, shielding factor, Pmu,
% internal uncertainty -- then E_St, ext uncert (St), P_St

outstr.results_10_ntd = '';

for a = 1:numsamples;
	if (all_isN10(a));
		% if Be-10 data, write a full line - 8 cols
        % Line is sample_name - Shielding - Pmu - delE_int_St - then E_St
        % in m/Myr and g/cm2/yr, delE_ext_St, P_St
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
        temp = [temp '</td><td>' sprintf('%8.4f',all_othercorr(a))];
        temp = [temp '</td><td>' sprintf('%8.3f',be_Pmu0(a))];
        temp = [temp '</td><td>' sprintf('%8.2f',be_delE_int(a,1))];
        temp = [temp '</td><td>' sprintf('%8.5f',be_Egcm2yr(a,1))];
		temp = [temp '</td><td>' sprintf('%8.2f',be_EmMyr(a,1))];
		temp = [temp '</td><td>' sprintf('%8.2f',be_delE_ext(a,1))];
		temp = [temp '</td><td>' sprintf('%8.2f',be_P_St(a)) '</td></tr>'];
        outstr.results_10_ntd = [outstr.results_10_ntd temp];
	else 
		% if no Be-10 data, write a table line anyway
    		outstr.results_10_ntd = [outstr.results_10_ntd '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% 1.b. Basic Al-26 results.

outstr.results_26_ntd = '';

for a = 1:numsamples;
	if (all_isN26(a));
		% if Al-26 data, write a full line - 7 cols
        % Line is sample_name - Shielding - Pmu - delE_int_St - then E_St
        % in m/Myr and g/cm2/yr, delE_ext_St, P_St
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
        temp = [temp '</td><td>' sprintf('%8.4f',all_othercorr(a))];
        temp = [temp '</td><td>' sprintf('%8.3f',al_Pmu0(a))];
        temp = [temp '</td><td>' sprintf('%8.2f',al_delE_int(a,1))];
        temp = [temp '</td><td>' sprintf('%8.5f',al_Egcm2yr(a,1))];
		temp = [temp '</td><td>' sprintf('%8.2f',al_EmMyr(a,1))];
        temp = [temp '</td><td>' sprintf('%8.2f',al_delE_ext(a,1))];
		temp = [temp '</td><td>' sprintf('%8.2f',al_P_St(a)) '</td></tr>'];
        outstr.results_26_ntd = [outstr.results_26_ntd temp];
    else
        % if no Al-26 data, write a table line anyway
    		outstr.results_26_ntd = [outstr.results_26_ntd '<tr align="center"><td align="left">' all_sample_name{a} '</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
end;

% 2.a. Be-10 erosion rates -- time-dependent scaling
% Sample name, E_De (2 units), delE_De, E_Du ( 2 units), delE_Du, E_Li (2 units), delE_Li, E_Lm (2 units), delE_Lm

outstr.results_10_td = '';

for a = 1:numsamples;
	if (all_isN10(a));
		% if Be-10 data, write a full line - sample name plus 4 times:
        % Egcm2yr, EmMyr, delEMmyr -- total 13 columns 
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
        for b = 2:5;
            temp = [temp '</td><td>' sprintf('%8.5f',be_Egcm2yr(a,b))];
            temp = [temp '</td><td>' sprintf('%8.2f',be_EmMyr(a,b))];
            temp = [temp '</td><td>' sprintf('%8.2f',be_delE_ext(a,b))];
        end;
        temp = [temp '</td></tr>'];
		outstr.results_10_td = [outstr.results_10_td temp];
	else 
		% if no Be-10 data, write a table line anyway
        temp = ['<tr align="center"><td align="left">' all_sample_name{a} '</td>'];
        for b = 1:12;
            temp = [temp '<td>--</td>'];
        end;
    	outstr.results_10_td = [outstr.results_10_td temp '</tr>'];
	end;
end;

% 2.b. Al-26 erosion rates -- time-dependent scaling

outstr.results_26_td = '';

for a = 1:numsamples;
	if (all_isN26(a));
		% if Al-26 data, write a full line - sample name plus 4 times:
        % Egcm2yr, EmMyr, delEMmyr -- total 13 columns 
		temp = ['<tr align="center"><td align="left">' all_sample_name{a}];
        for b = 2:5;
            temp = [temp '</td><td>' sprintf('%8.5f',al_Egcm2yr(a,b))];
            temp = [temp '</td><td>' sprintf('%8.2f',al_EmMyr(a,b))];
            temp = [temp '</td><td>' sprintf('%8.2f',al_delE_ext(a,b))];
        end;
        temp = [temp '</td></tr>'];
		outstr.results_26_td = [outstr.results_26_td temp];
	else 
		% if no Al-26 data, write a table line anyway
        temp = ['<tr align="center"><td align="left">' all_sample_name{a} '</td>'];
        for b = 1:12;
            temp = [temp '<td>--</td>'];
        end;
    	outstr.results_26_td = [outstr.results_26_td temp '</tr>'];
	end;
end;

% 3. Solver diagnostics
% A long line of text. 
% Sample name - nuclide -- 5 x exitflag -- 5 x fval -- 5 x opt time -- muon time
% Al and Be in consecutive lines
% Total 6 columns

outstr.results_opt_diag = '';

for a = 1:numsamples;
	temp = ['<tr align="center"><td align="left">' all_sample_name{a} '</td><td>Be-10</td><td>'];
	if (all_isN10(a));
    		temp = [temp  int2str(be_fzero_status(a,:)) '</td><td>'];
            temp = [temp sprintf('%0.3g ',be_fval(a,:)) '</td><td>'];
            temp = [temp sprintf('%6.2f',be_time_fzero(a,:)) '</td><td>'];
            temp = [temp sprintf('%6.2f',be_time_mu_precalc(a)) '</td></tr>'];
	else
    		temp = [temp '--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;
    
    % Second row
    temp = [temp '<tr align="center"><td align="left"></td><td>Al-26</td><td>'];
	
    if (all_isN26(a));
    		temp = [temp  int2str(al_fzero_status(a,:)) '</td><td>'];
            temp = [temp sprintf('%0.3g ',al_fval(a,:)) '</td><td>'];
            temp = [temp sprintf('%6.2f',al_time_fzero(a,:)) '</td><td>'];
            temp = [temp sprintf('%6.2f',al_time_mu_precalc(a)) '</td></tr>'];
	else
    		temp = [temp '--</td><td>--</td><td>--</td><td>--</td></tr>'];
	end;

	outstr.results_opt_diag = [outstr.results_opt_diag temp];
end;

% 4. Al/Be ratios 

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

% Plotting disabled 20180828.

if 0;

% 7. SPLOT! 

% First, figure out which samples have both measurements.

cs = all_isN10 & all_isN26; % cs = can splot
cs_index = find(cs);

if isempty(cs_index);
	% no samples to splot
	outstr.splotName = '(No Al-26 / Be-10 plot)';
	outstr.gmtName = '';
	outstr.psName = ''; 
else;
	% splot the samples. 
	% create the data structure --
	% first the scalar elements --
    tempP10 = be_P_St(cs_index) + be_Pmu0(cs_index);
    tempP26 = al_P_St(cs_index) + al_Pmu0(cs_index);
	pdata.l10 = al_be_consts.l10;
    pdata.l26 = al_be_consts.l26;
    pdata.Lsp = al_be_consts.Lsp;
	% now the vector elements --
	pdata.N26_norm = all_N26(cs_index) ./ tempP26;
    pdata.N10_norm = all_N10(cs_index) ./ tempP10;
    pdata.delN10_norm = pdata.N10_norm .* all_delN10(cs_index) ./ all_N10(cs_index);
    pdata.delN26_norm = pdata.N26_norm .* all_delN26(cs_index) ./ all_N26(cs_index);

	% call the plotting function --
	splotNameString = makeEplot(pdata);
	
	% assign the output variables -- 
    outstr.splotName = ['<img src=/scratch/' splotNameString '.jpg width=500>'];
	outstr.gmtName =  ['<a href=/scratch/' splotNameString '.gmt>GMT code for this plot (includes the x,y data points)</a>'];
	outstr.psName = ['<a href=/scratch/' splotNameString '.ps>Postscript version of this plot</a>'];
end;     

end;

outstr.splotName = 'Plotting discontinued in this version. Use version 3 instead.';
outstr.gmtName = '';
outstr.psName = '';

% ----------------- END OUTPUT STRING ASSEMBLY ------------------------

% dump whatever diagnostics exist -- 

outstr.dstring = dstring;

% Server operations

if localFlag == 0;
    
    % Dump to locations data file. 
    % Disabled during development. 
    dump_location_v2('e',all_lat,all_long);

    % Do some cleanup -- kill image files older than 1 week 

    wscleanup('*.jpg',24*7,'/var/www/html/scratch/');
    wscleanup('*.gmt',24*7,'/var/www/html/scratch/');
    wscleanup('*.ps',24*7,'/var/www/html/scratch/');

    % Write to log file

    % validate requesting_ip form input 

    ip_pattern = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

    if regexp(ins.requesting_ip,ip_pattern);
        this_ip = ins.requesting_ip;
    else;
        this_ip = 'Bad_address';
    end;

    % do the log entry for each sample

    for a = 1:numsamples;
        log_entry = [this_ip ' e_many_v23 ' sprintf('%.4f',all_lat(a)) ' ' sprintf('%.4f',all_long(a)) ];
        log_entry = [log_entry ' ' sprintf('%i ',fix(clock))];
	
        write_to_log(log_entry);
    end;
    
    % increment the call count
    
    increment_call_count();

    % Return the output HTML. 
    templatefile = '/var/www/html/math/al_be_v23/al_be_erosion_out_v23.html';

    retstr = htmlrep(outstr, templatefile);
else
    retstr = outstr;
end;


