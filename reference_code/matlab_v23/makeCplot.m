function out = makeCplot(data10,data26,localFlag);

% Function to make an age-comparison plot using GMT and ImageMagick.
% 
% Syntax out = makeCplot(data10,data26,localFlag);
% 
% data10 and data26 are structures with fields:
%
%   t - exposure age
%   delt_int - internal uncertainty
%   delt_ext - external uncertainty
%
% Where each one is a 1,4 vector containing the respective variable for
% each of the four scaling schemes. The order is St, De, Du, Li.  
%
% If no Be-10 or Al-26 data, these variables are zero. 
%
% localFlag = 1 disables the server-specific stuff for development
% 
% returns the filename root of the images that it makes
%
% Written by Greg Balco -- UW Cosmogenic Nuclide Lab
% balcs@u.washington.edu
% January, 2007
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

if nargin < 3; localFlag = 0; end;

% Find the age limits for the plot

if isstruct(data10);
    isPos10 = find(data10.t > 0);
    if isempty(isPos10);
        max10 = 0; min10 = Inf;
    else;
        max10 = max(data10.t(isPos10) + data10.delt_ext(isPos10));
        min10 = min(data10.t(isPos10) - data10.delt_ext(isPos10));
    end;
else;
    max10 = 0;min10 = Inf;
end;
if isstruct(data26);
    isPos26 = find(data26.t > 0);
    if isempty(isPos26);
        max26 = 0; min26 = Inf;
    else;
        max26 = max(data26.t(isPos26) + data26.delt_ext(isPos26));
        min26 = min(data26.t(isPos26) - data26.delt_ext(isPos26));
    end;
else;
    max26 = 0;min26 = Inf;
end;

% Final check to make sure there is anything to plot
if (min10 == Inf) & (min26 == Inf);
    % nothing to plot
    out = 0; return;
end;

max_int = ceil(max([max10 max26])./1000).*1000;
max_str = int2str(max_int);

min_int = floor(min([min10 min26])./1000).*1000;
min_str = int2str(min_int);
range = max_int - min_int;
range_str = int2str(range);

rangeorder = ceil(log10(range));
tdiv_int  = (0.5*(10^(rangeorder - 1)));
if (range./tdiv_int) > 6;
    tdiv_int = 2*tdiv_int;
end;

tdiv = int2str(tdiv_int);

% Now see if we can make raster images using GMT and ghostscript. 

uniqueid = int2str(round(rand(1)*1e6));
% There is no effort made to see if this really is unique. 
% I mean, what are the odds?

% Everything goes on in the scratch directory. 
if localFlag == 0;
    fname = ['/var/www/html/scratch/comp' uniqueid];
else;
    fname = ['tempC'];
end;

gmtname = [fname '.gmt'];
if localFlag == 0;
    psname = [fname '.ps'];
else;
    psname = [fname '.eps'];
end;
jpgname = [fname '.jpg'];

fid = fopen(gmtname,'w');

%fprintf(fid,'%s\n','gmtset PAPER_MEDIA square8');
%fprintf(fid,'%s\n','gmtset ANOT_FONT 3 ANOT_FONT_SIZE 14');
%fprintf(fid,'%s\n','gmtset LABEL_FONT 3 LABEL_FONT_SIZE 14');
%fprintf(fid,'%s\n','gmtset FRAME_PEN 8');

jstring = '-JX5.5i/3i';
rstring = ['-R0.5/5.5/' min_str '/' max_str];
cs = ['0/0/0    '; '255/0/0  '; '0/255/0  '; '0/0/255  ' ; '0/255/255'];

% GMT rigidity
fprintf(fid,'%s\n','# ----------- Make the frame ------------');
temp_string = ['psbasemap ' rstring ' -Ba1/a' tdiv 'g' tdiv ':"yr BP":Wesn ' jstring ' -K -P > ' psname];
fprintf(fid,'%s\n',temp_string);

% Be-10 results
if isstruct(data10);
    fprintf(fid,'%s\n','# ----------- Plot Be-10 age/uncertainties x 5  ------------');
    for a = 1:5;
        fprintf(fid,'%s\n',['# ------------- Starting Be-10 set ' int2str(a) ' -------------']); 
        % external error
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -W1p/' cs(a,:) ' << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a-0.1) data10.t(a)-data10.delt_ext(a)]);
        fprintf(fid,'%0.5g %0.5g\n',[(a-0.1) data10.t(a)+data10.delt_ext(a)]);
        fprintf(fid,'%s\n','EOF');
        % internal error
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -W3p/' cs(a,:) ' << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a-0.1) data10.t(a)-data10.delt_int(a)]);
        fprintf(fid,'%0.5g %0.5g\n',[(a-0.1) data10.t(a)+data10.delt_int(a)]);
        fprintf(fid,'%s\n','EOF');
        % value
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -Sc0.15i -W1p/' cs(a,:) ' -G255 << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a-0.1) data10.t(a)]);
        fprintf(fid,'%s\n','EOF');
        fprintf(fid,'%s\n',['# ------------- Finishing Be-10 set ' int2str(a) ' -------------']); 
        
    end;
end;

% Al-26 results
if isstruct(data26);
    fprintf(fid,'%s\n','# ----------- Plot Al-26 age/uncertainties x 5  ------------');
    for a = 1:5;
        fprintf(fid,'%s\n',['# ------------- Starting Al-26 set ' int2str(a) ' -------------']); 
        % external error
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -W1p/' cs(a,:) ' << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a+0.1) data26.t(a)-data26.delt_ext(a)]);
        fprintf(fid,'%0.5g %0.5g\n',[(a+0.1) data26.t(a)+data26.delt_ext(a)]);
        fprintf(fid,'%s\n','EOF');
        % internal error
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -W3p/' cs(a,:) ' << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a+0.1) data26.t(a)-data26.delt_int(a)]);
        fprintf(fid,'%0.5g %0.5g\n',[(a+0.1) data26.t(a)+data26.delt_int(a)]);
        fprintf(fid,'%s\n','EOF');
        % value
        temp_string = ['psxy ' rstring ' ' jstring ' -O -K -P -M -St0.15i -W1p/' cs(a,:) ' -G255 << EOF >> ' psname];
        fprintf(fid,'%s\n',temp_string);
        fprintf(fid,'%0.5g %0.5g\n',[(a+0.1) data26.t(a)]);
        fprintf(fid,'%s\n','EOF');
        fprintf(fid,'%s\n',['# ------------- Finishing Al-26 set ' int2str(a) ' -------------']); 
        
    end;
end;

% close off plot

temp_string = ['psxy -R0.5/5.5/0/1 ' jstring ' -O -P -M -W1p/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[1.5 0]);
fprintf(fid,'%0.5g %0.5g\n',[1.5 1]);
fprintf(fid,'%s\n','EOF');

fclose(fid);

if localFlag == 0;
    % run the script you just made
    temp_string = ['chmod a+x ' gmtname];
    system(temp_string);
    temp_string = ['' gmtname];
    system(temp_string);

    % convert the ps file to a jpeg using ImageMagick...
    temp_string = ['convert -trim ' psname ' ' jpgname];
    system(temp_string);
    
    % return the root file name
    out = ['comp' uniqueid];
else;
    out = 'tempC';
end;
    


