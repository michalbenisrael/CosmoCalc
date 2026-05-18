function retstr = al_be_age_many_v23_ws(ins,localFlag)

%
%
% This code has been disabled 20180828. Use version 3 instead. 
%
% Al-Be EXPOSURE AGE CALCULATOR
% MULTIPLE SAMPLE INPUT
% 
% Version 2.3
% 
% This is the wrapper script for the multiple-sample Be-Al exposure age
% calculator. It checks the input data, passes it to other functions to
% calculate the exposure ages, then repackages the data.
% Either follows from a new production rate calibration or 
% uses the default production rate calibration data set. 
% This version returns a short data string rather than a HTML page, for use
% as a web service. 
%
% This code only pays attention to the "St" and "Lm" scaling schemes. The
% others have been removed.  
%
% syntax: retstr = al_be_age_many_v23_ws(ins,localFlag)
%
% The input structure contains:
% ins.text_block -- the big block of text from the 'sample' paste-in 
% text field in the input HTML
% form
% ins.requesting_IP, -- the IP address of the requesting
% machine handed down from the web server. This is used to write a
% log entry.
% ins.P10_St, ins.delP10_St, ins.P10_Lm, ins.del_10_Lm -- Be-10 
% production rates - strings
% ins.P26_St, ins.delP16_St, etc. and so on -- Al-26 same
%
% If none of these are supplied, uses default production rates. 
%
% localFlag is an optional diagnostic flag -- enter 1 to disable 
% web-server-specific actions.
%
% The output string retstr is basically XML. More details later. 
%
% Based on code written by Greg Balco -- Berkeley Geochronology Center
% -- in march, 2008, and part of what were at the time the CRONUS-Earth 
%      online calculators: 
%      http://hess.ess.washington.edu/math
%
% This version by Greg Balco (Berkeley Geochronology Center), August 2014
% Updated June 2016, Greg Balco
%
% Copyright 2001-2007, University of Washington
% Copyright 2007-2016, Greg Balco
% All rights reserved
% Developed in part with funding from the National Science Foundation.
%
% This software is under development and is not licensed for distribution. 

% The following disables this code.

retstr = dump_error_XML('This version of the calculators API has been disabled. Use version 3 instead.'); 
return;

% Done.


% This code needs to do two things: if no calibration supplied, uses
% default calibration. If calibration supplied, uses it. 

% Sort local flag

if nargin < 2; localFlag = 0;end;

%% Setup cell

% 0. What version is this file. 

ver = '2.3-cal-webservice';

% get in the correct directory

if localFlag == 0;
    cd /var/www/html/math/al_be_v23
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

sfa = ['St';'Lm'];

%% ------------ DATA CHECKING AND LOADING FOR UNKNOWNS -----------------

% check for correct number of items --

if mod(numitems,numcols) ~= 0;
	retstr = dump_error_XML('Wrong total number of data elements in unknowns block -- check for missing data, extra data, or white space within a single element');
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
		retstr = dump_error_XML('Unknowns data block - Sample name more than 24 characters');
        return;
	end;
	
	% test for illegal characters in sample name
	% this allows letters, numbers, underscores, and dashes only. 
	if isempty(regexp(parsed_text{si+ino},'[^\w-]'));
		% pass, do assignment
		all_sample_name{a} = parsed_text{si+ino};
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in sample name - line ' int2str(a)]);
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
    			retstr = dump_error_XML('Unknowns data block - latitude out of bounds');
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML('Unknowns data block - un-numericalizable latitude value');
            return;
		end;
		all_lat(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in latitude - line ' int2str(a)]);
        return;
	end;

	
	% 3. Longitude
	
	ino = 3;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) > 180 | str2double(parsed_text{si+ino}) < -180);
    			retstr = dump_error_XML('Unknowns data block - longitude out of bounds');
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML('Unknowns data block - un-numericalizable longitude value');
            return;
		end;
		all_long(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in longitude - line ' int2str(a)]);
        return;
	end;

	
	% 5. Elv/pressure flag -- get this first as it affects checks for (4)
	
	ino = 5;
	
	% must match one of three possible options
	if (strcmp(parsed_text{si+ino},'std') | strcmp(parsed_text{si+ino},'ant') | strcmp(parsed_text{si+ino},'pre') );
		% pass
		all_aa{a} = parsed_text{si+ino};
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - unknown elevation/pressure flag - line ' int2str(a)]);
        return;
	end;

	% 4. Elv/pressure
	
	ino = 4;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if strcmp(all_aa{a},'std') | strcmp(all_aa{a},'ant')
			if (str2double(parsed_text{si+ino}) < -500);
    				retstr = dump_error_XML(['Unknowns data block - elevation too low -- line ' int2str(a)]);
                    return;
			end; 
		elseif strcmp(all_aa{a},'pre')
			if (str2double(parsed_text{si+ino}) > 1060 | str2double(parsed_text{si+ino}) < 0);
    				retstr = dump_error_XML(['Unknowns data block - pressure out of reasonable bounds -- line ' int2str(a)]);
                    return;
			end;
		end;	
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
				retstr = dump_error_XML('Unknowns data block - un-numericalizable elev/pressure value');
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
			
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in elevation/pressure - line ' int2str(a)]);
        return;
	end;
	
	% 6. Thickness
	
	ino = 6;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - thickness less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable thickness value - line ' int2str(a)]);
            return;
		end;
		all_thick(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in thickness - line ' int2str(a)]);
        return;
	end;
	
	% 7. Density
	
	ino = 7;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - density less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable density value - line ' int2str(a)]);
            return;
		end;
		all_rho(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in density - line ' int2str(a)]);
        return;
	end;
	
	% 8. Shielding
	
	ino = 8;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0 | str2double(parsed_text{si+ino}) > 2);
    			retstr = dump_error_XML(['Unknowns data block - shielding correction out of reasonable range - line ' int2str(a)]);
                return;
        end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable shielding value - line ' int2str(a)]);
            return;
		end;
		all_othercorr(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in shielding correction - line ' int2str(a)]);
	end;
	
	
	% 9. Erosion rate
	
	ino = 9;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - erosion rate less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable erosion rate - line ' int2str(a)]);
            return;
		end;
		all_E(a) = str2double(parsed_text{si+ino});
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in erosion rate - line ' int2str(a)]);
        return;
	end;
	
    
    % 12. Be-10 standardization -- get this first 
	
	ino = 12;
	
	% must match something in stds structure
    
    if strmatch(parsed_text{si+ino},al_be_consts.be_stds_names,'exact');
        % pass
        all_std10{a} = parsed_text{si+ino};
    else;
        % fail
        retstr = dump_error_XML(['Unknowns data block - unknown Be-10 reference standard identifier - line ' int2str(a)]);
        return;
    end;
    
    
	% 10. N10
	
	ino = 10;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - Be-10 concentration less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable Be-10 concentration - line ' int2str(a)]);
            return;
		end;
		all_N10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std10{a},al_be_consts.be_stds_names,'exact');
        this_std_cf = al_be_consts.be_stds_cfs(this_std_no);
        all_N10(a) = all_N10(a).*this_std_cf;
        
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in Be-10 concentration - line ' int2str(a)]);
        return;
	end;
	
	% 11. delN10
	
	ino = 11;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - Be-10 uncertainty less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable Be-10 uncertainty - line ' int2str(a)]);
            return;
		end;
		all_delN10(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN10(a) = all_delN10(a).*this_std_cf;
        
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in Be-10 uncertainty - line ' int2str(a)]);
        return;
	end;
	
	
    % 15. Al-26 standardization -- get this first 
	
	ino = 15;
	
	% must match something in stds structure
    
     if strmatch(parsed_text{si+ino},al_be_consts.al_stds_names,'exact');
        % pass
        all_std26{a} = parsed_text{si+ino};
    else;
        % fail
        retstr = dump_error_XML(['Unknowns data block - unknown Al-26 reference standard identifier - line ' int2str(a)]);
        return;
    end;
    
	% 13. N26
	
	ino = 13;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - Al-26 concentration less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			retstr = dump_error_XML(['Unknowns data block - un-numericalizable Al-26 concentration - line ' int2str(a)]);
            return;
		end;
		all_N26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        this_std_no = strmatch(all_std26{a},al_be_consts.al_stds_names,'exact');
        this_std_cf = al_be_consts.al_stds_cfs(this_std_no);
        all_N26(a) = all_N26(a).*this_std_cf;
        
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in Al-26 concentration - line ' int2str(a)]);
        return;
	end;
	
	% 14. delN26
	
	ino = 14;
	
	if isempty(regexp(parsed_text{si+ino},'[^\d.eE+-]'));
		% pass
		% test for bounds
		if (str2double(parsed_text{si+ino}) < 0);
    			retstr = dump_error_XML(['Unknowns data block - Al-26 uncertainty less than zero - line ' int2str(a)]);
                return;
		end; 
		% cover other eventualities
		if isnan(str2double(parsed_text{si+ino}));
			 retstr = dump_error_XML(['Unknowns data block - un-numericalizable Al-26 uncertainty - line ' int2str(a)]);
             return;
		end;
		all_delN26(a) = str2double(parsed_text{si+ino});
        
        % Restandardize
        all_delN26(a) = all_delN26(a).*this_std_cf;
        
	else;
		% fail
		retstr = dump_error_XML(['Unknowns data block - illegal characters in Al-26 uncertainty - line ' int2str(a)]);
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
   		retstr = dump_error_XML(['Unknowns data block - need either Be-10 or Al-26 concentration - line ' int2str(a)]);
        return;
	elseif (all_isN10(a) & ~all_isdelN10(a)) | (~all_isN10(a) & all_isdelN10(a));
    		retstr = dump_error_XML(['Unknowns data block - need both Be-10 concentration and uncertainty - line ' int2str(a)]);
            return;
	elseif (all_isN26(a) & ~all_isdelN26(a)) | (~all_isN26(a) & all_isdelN26(a));
    		retstr = dump_error_XML(['Unknowns data block - need both Al-26 concentration and uncertainty - line ' int2str(a)]);
            return;
	end;
	
	
	% I think we're done with the data checking now. 
	
end;

% ---------- DONE DATA CHECKING AND LOADING FOR UNKNOWNS -----------------

% ----------- DATA CHECKING AND LOADING FOR CALIBRATION DATA -------------

% Determine which production rate parameters were supplied

isCalInputs(1,1:4) = [isfield(ins,'P10_St') isfield(ins,'delP10_St') isfield(ins,'P26_St') isfield(ins,'delP26_St')];
isCalInputs(2,1:4) = [isfield(ins,'P10_Lm') isfield(ins,'delP10_Lm') isfield(ins,'P26_Lm') isfield(ins,'delP26_Lm')];
  
% Input format checking for items that do exist
items = strvcat('P10_','delP10_','P26_','delP26_');
for sf = 1:2;
    for item = 1:4;
        if isCalInputs(sf,item)
            % Get the item
            this_item_name = [deblank(items(item,:)) sfa(sf,:)];
            eval(['this_item_str = ins.' this_item_name ';']);
            % Check  - allow digits and decimal point
            if isempty(regexp(this_item_str,'[^\d.]'));
                % pass
                % test for bounds
                if (str2double(this_item_str) < 0);
                    retstr =dump_error_XML(['Production rate inputs - ' this_item_name ' less than zero']);return;
                end; 
                % cover other eventualities
                if isnan(str2double(this_item_str));
                    retstr =dump_error_XML(['Production rate inputs - ' this_item_name ' can''t be numericalized']);return;
                end;
                % Pass all - assign
                eval(['cal_data.' this_item_name ' = str2double(this_item_str);']);
            else;
                % fail
                retstr =dump_error_XML(['Production rate inputs - illegal characters in ' this_item_name]);return;
            end;  
        else;
            %this_item_name = [deblank(items(item,:)) sfa(sf,:)];
            %disp([this_item_name ' does not exist']);
        end;
    end;
end;

if ~any(any(isCalInputs));
    % Case no calib inputs
    cal_data = [];
end;

% Load Be-10 production rates into consts structure if present
if isfield(cal_data,'P10_St');
    if isfield(cal_data,'delP10_St');
        al_be_consts.P10_ref_St = cal_data.P10_St;
        al_be_consts.delP10_ref_St = cal_data.delP10_St;
    else
        % Case P10 supplied but not del P10
        retstr =dump_error_XML(['al_be_age_many_v23_ws.m: P10_St supplied but not delP10_St']);return;
    end;
end;

if isfield(cal_data,'P10_Lm');
    if isfield(cal_data,'delP10_Lm');
        al_be_consts.P10_ref_Lm = cal_data.P10_Lm;
        al_be_consts.delP10_ref_Lm = cal_data.delP10_Lm;
    else
        % Case P10 supplied but not del P10
        retstr =dump_error_XML(['al_be_age_many_v23_ws.m: P10_Lm supplied but not delP10_Lm']);return;
    end;
end;

% Now load Al-26 production rates if present. If not present, simply use
% multiple of Be-10 production rate. 

if isfield(cal_data,'P26_St');
    if isfield(cal_data,'delP26_St');
        % Case both supplied
        al_be_consts.P26_ref_St = cal_data.P26_St;
        al_be_consts.delP26_ref_St = cal_data.delP26_St;
    else;
        retstr =dump_error_XML(['al_be_age_many_v23_ws.m: P26_St supplied but not delP26_St']);return;
    end;
else;
    % Case P26_St not supplied
    % Base on Be-10 production rates. If they were not changed, this just
    % recapitulates what is done when building the consts file.
    al_be_consts.P26_ref_St = al_be_consts.P10_ref_St.*6.75;
    al_be_consts.delP26_ref_St = al_be_consts.delP10_ref_St.*6.75;
end;

if isfield(cal_data,'P26_Lm');
    if isfield(cal_data,'delP26_Lm');
        % Case both supplied
        al_be_consts.P26_ref_Lm = cal_data.P26_Lm;
        al_be_consts.delP26_ref_Lm = cal_data.delP26_Lm;
    else;
        retstr =dump_error_XML(['al_be_age_many_v23_ws.m: P26_Lm supplied but not delP26_Lm']);return;
    end;
else;
    % Case P26_Lm not supplied
    % Base on Be-10 production rates. If they were not changed, this just
    % recapitulates what is done when building the consts file.
    al_be_consts.P26_ref_Lm = al_be_consts.P10_ref_Lm.*6.75;
    al_be_consts.delP26_ref_Lm = al_be_consts.delP10_ref_Lm.*6.75;
end;
    
% ----------- DONE CALIB DATA CHECKING AND LOADING -----------------------

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
	
	if (all_isN10(a)); be_results = get_al_be_age_StLm(sample,al_be_consts,10); end;
	if (all_isN26(a)); al_results = get_al_be_age_StLm(sample,al_be_consts,26); end;
	
	% sort the results that will appear in multiple-sample output;
    
	if(all_isN10(a));
		% SF-dependent
        for b = 1:2;
            eval(['t10_' sfa(b,:) '(a) = be_results.t_' sfa(b,:) ';']);
            eval(['delt10_int_' sfa(b,:) '(a) = be_results.delt_int_' sfa(b,:) ';']);
            eval(['delt10_ext_' sfa(b,:) '(a) = be_results.delt_ext_' sfa(b,:) ';']);
        end;
        % Add output flags to dstring
        if ~isempty(be_results.flags);
            dstring = [dstring ' ' be_results.flags '<br>'];
        end;
    else
        % No data, write zeros
        for b = 1:2;
            eval(['t10_' sfa(b,:) '(a) = 0;']);
            eval(['delt10_int_' sfa(b,:) '(a) = 0;']);
            eval(['delt10_ext_' sfa(b,:) '(a) = 0;']);
        end;
	end;
    
	if(all_isN26(a));
		% SF-dependent
        for b = 1:2;
            eval(['t26_' sfa(b,:) '(a) = al_results.t_' sfa(b,:) ';']);
            eval(['delt26_int_' sfa(b,:) '(a) = al_results.delt_int_' sfa(b,:) ';']);
            eval(['delt26_ext_' sfa(b,:) '(a) = al_results.delt_ext_' sfa(b,:) ';']);
        end;
        % Add output flags to dstring
        if ~isempty(al_results.flags);
            dstring = [dstring ' ' al_results.flags '<br>'];
        end;
    else
        % No data, write zeros
        for b = 1:2;
            eval(['t26_' sfa(b,:) '(a) = 0;']);
            eval(['delt26_int_' sfa(b,:) '(a) = 0;']);
            eval(['delt26_ext_' sfa(b,:) '(a) = 0;']);
        end;
	end;

	clear sample;
	
end; % End of main calculation loop -- 

% ---------------- DONE DOING AGE CALCULATIONS ------------------------

% -------------- START CALCULATION OUTPUT ASSEMBLY ---------------------

% start output string extraction...
% Basically XML
% <calcs_v22_data>
% <exposureAgeResult><t10St></t10St><delt10_int_St>......</exposureAgeResult>
% <exposureAgeResult><t10St></t10St><delt10_int_St>......</exposureAgeResult>
% ...
% </calcs_v22_data>

outstr = '<calcs_v22_age_data>';
for a = 1:numsamples;
    
    outstr = [outstr '<exposureAgeResult>'];
    outstr = [outstr '<t10St>' sprintf('%0.0f',t10_St(a)) '</t10St>'];
    outstr = [outstr '<delt10_int_St>' sprintf('%0.0f',delt10_int_St(a)) '</delt10_int_St>'];
    outstr = [outstr '<delt10_ext_St>' sprintf('%0.0f',delt10_ext_St(a)) '</delt10_ext_St>'];
    
    outstr = [outstr '<t10Lm>' sprintf('%0.0f',t10_Lm(a)) '</t10Lm>'];
    outstr = [outstr '<delt10_int_Lm>' sprintf('%0.0f',delt10_int_Lm(a)) '</delt10_int_Lm>'];
    outstr = [outstr '<delt10_ext_Lm>' sprintf('%0.0f',delt10_ext_Lm(a)) '</delt10_ext_Lm>'];
    
    outstr = [outstr '<t26St>' sprintf('%0.0f',t26_St(a)) '</t26St>'];
    outstr = [outstr '<delt26_int_St>' sprintf('%0.0f',delt26_int_St(a)) '</delt26_int_St>'];
    outstr = [outstr '<delt26_ext_St>' sprintf('%0.0f',delt26_ext_St(a)) '</delt26_ext_St>'];
    
    outstr = [outstr '<t26Lm>' sprintf('%0.0f',t26_Lm(a)) '</t26Lm>'];
    outstr = [outstr '<delt26_int_Lm>' sprintf('%0.0f',delt26_int_Lm(a)) '</delt26_int_Lm>'];
    outstr = [outstr '<delt26_ext_Lm>' sprintf('%0.0f',delt26_ext_Lm(a)) '</delt26_ext_Lm>'];
    
    outstr = [outstr '</exposureAgeResult>'];
end;

% Also dump diagnostics

% strip <br> tags from diagnostics
dstring = strrep(dstring,'<br>','...');

outstr = [outstr '<diagnostics>' dstring '</diagnostics>'];

outstr = [outstr '</calcs_v22_age_data>'];
   

   
% ----------------- END OUTPUT STRING ASSEMBLY ------------------------
    
% ---------------- DO LOGGING ------------------------------

if localFlag == 0;
    
    % Get requestor's IP address from CGI environment vars
    try 
        requesting_ip = getenv('REMOTE_ADDR');
        
        % Validate
        ip_pattern = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
        if regexp(requesting_ip,ip_pattern);
            this_ip = requesting_ip;
        else;
            this_ip = 'Bad_address';
        end;
    catch
        this_ip = 'Error_getting_address';
    end;


    % do the log entry for each sample
    for a = 1:numsamples;
        log_entry = [this_ip ' t_v23_ws ' sprintf('%.4f',all_lat(a)) ' ' sprintf('%.4f',all_long(a)) ];
        log_entry = [log_entry ' ' sprintf('%s',all_sample_name{a}) ' ' sprintf('%i ',fix(clock))];
        
        write_to_log_ws(log_entry);
    end;
end;

% -------------- RETURN OUTPUT STRING ----------------------------

retstr = outstr;



