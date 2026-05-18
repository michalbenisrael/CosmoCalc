function out = makeCalOptPlot(pdata,localFlag);

% Function to plot P10 vs. chi-squared relative to calib data set
% 
% Syntax out = makeCalOptPlot(pdata,localFlag);
%
% pdata is a structure with 
% 
%
% the output argument is the filename root.
%
% localFlag = 1 disables server-specific pathnames and ImageMagick
% conversion. Writes the GMT code as tempCalOpt.gmt.
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

if nargin < 2; localFlag = 0; end;

% Make up some stuff

pmin_data = 3.*max([min(pdata.y1_St ) min(pdata.y1_De) min(pdata.y1_Du) min(pdata.y1_Li) min(pdata.y1_Lm)]);
pmin_data_2 = ceil(pmin_data./10).*10;
pmin = int2str(pmin_data_2);
pdiv = int2str(pmin_data_2./10);

% Open the text file

uniqueid = int2str(round(rand(1)*1e6));
% no effort made to see if this really is unique. 
% I mean, what are the odds?

% everything goes on in the scratch directory. 
if localFlag == 0;
    fname = ['/var/www/html/scratch/calOptPlot' uniqueid];
else;
    fname = 'tempCalOpt';
end;

gmtname = [fname '.gmt'];
if localFlag == 0;
    psname = [fname '.ps'];
else;
    psname = [fname '.eps'];
end;
pngname = [fname '.png'];
    
% open file for write
fid = fopen(gmtname,'w');

rstring = ([num2str(pdata.x1(1)) '/' num2str(pdata.x1(end)) '/0/' pmin]);

fprintf(fid,'%s\n','gmtset PAPER_MEDIA a0');
fprintf(fid,'%s\n','gmtset ANOT_FONT 3 ANOT_FONT_SIZE 14');
fprintf(fid,'%s\n','gmtset LABEL_FONT 3 LABEL_FONT_SIZE 14');
fprintf(fid,'%s\n','gmtset FRAME_PEN 8');

% Make the GMT basemap
fprintf(fid,'%s\n','# ----------- Draw the plot axes ------------');
temp_string = ['psbasemap -Ba0.5:"P10":/a' pdiv ':"Reduced chi-squared":WeSn -R' rstring ' -JX6i/4i -K -P > ' psname];
fprintf(fid,'%s\n',temp_string);

% GMT fit data and polynomial approximations
sfa = ['St';'De';'Du';'Li';'Lm'];

cols = {'0' '255/0/0' '0/255/0' '0/0/255' '0/255/255'};

for sf = 1:5;
    eval(['y1 = pdata.y1_' sfa(sf,:) ';']);
    eval(['y2 = pdata.y2_' sfa(sf,:) ';']);
    data1 = [pdata.x1' y1']';
    data2 = [pdata.x2' y2']';
    fprintf(fid,'%s\n',['# ----------- Data and polynomial approximation - ' sfa(sf,:) ' ------------']);
    temp_string = ['psxy -R' rstring ' -JX6i/4i  -P -K -O -W1p/' cols{sf} ' << EOF >> ' psname];
    fprintf(fid,'%s\n',temp_string);
    fprintf(fid,'%0.5g %0.5g\n',data2);
    fprintf(fid,'%s\n','EOF');
    if sf == 5;
        temp_string = ['psxy -R' rstring ' -JX6i/4i  -P -M -O -Sc0.1i -G' cols{sf} ' << EOF >> ' psname];
    else;
        temp_string = ['psxy -R' rstring ' -JX6i/4i  -P -K -M -O -Sc0.1i -G' cols{sf} ' << EOF >> ' psname];
    end;
    fprintf(fid,'%s\n',temp_string);
    fprintf(fid,'%0.5g %0.5g\n',data1);
    fprintf(fid,'%s\n','EOF');
end;


% close the file
fclose(fid);

if localFlag == 0;
    % run the script you just made
    temp_string = ['chmod a+x ' gmtname];
    system(temp_string);
    temp_string = ['' gmtname];   
    system(temp_string);

    % convert the ps file to a jpeg using ImageMagick...
    temp_string = ['convert -trim ' psname ' ' pngname];
    system(temp_string);

    % return the name of the jpeg you just made
    out = ['calOptPlot' uniqueid];
else;
    out = 'tempCalOpt';
end;