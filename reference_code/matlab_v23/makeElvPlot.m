function out = makeElvPlot(pdata,localFlag);

% Function to plot calib data set performance vs. elevation
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
% March, 2008
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

% Determine elevation limits

plot_emax = ceil((max(pdata.elvs))./500).*500; % Round to 500's
emax = int2str(plot_emax);
if plot_emax <= 500; 
    ediv = int2str(100);
elseif plot_emax <= 1000;
    ediv = int2str(200);
else;
    ediv = int2str(500);
end;

% Determine miss limits

temp1 = [abs(pdata.r_St - 1)
    abs(pdata.r_De - 1)
    abs(pdata.r_Du - 1)
    abs(pdata.r_Li - 1)
    abs(pdata.r_Lm -1)];
mmax = (1 + ceil((max(max(temp1)))*10)./10)+0.05;
if mmax < 1.25; mmax=1.25; end;
mmin = (1 - (mmax-1));

str_mmax = num2str(mmax); str_mmin = num2str(mmin);



% Open the text file

uniqueid = int2str(round(rand(1)*1e6));
% no effort made to see if this really is unique. 
% I mean, what are the odds?

% everything goes on in the scratch directory. 
if localFlag == 0;
    fname = ['/var/www/html/scratch/ElvPlot' uniqueid];
else;
    fname = 'tempElv';
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

rstring = ([str_mmin '/' str_mmax '/0/' emax]);

sfa = ['St';'De';'Du';'Li';'Lm'];
cols = {'0' '255/0/0' '0/255/0' '0/0/255' '0/255/255'};

fprintf(fid,'%s\n','gmtset PAPER_MEDIA a0');
fprintf(fid,'%s\n','gmtset ANOT_FONT 3 ANOT_FONT_SIZE 14');
fprintf(fid,'%s\n','gmtset LABEL_FONT 3 LABEL_FONT_SIZE 14');
fprintf(fid,'%s\n','gmtset FRAME_PEN 8');

% Do everything 5 times. Geez. 
for sf = 1:5;

    
    % Plot the bounds on P10
    fprintf(fid,'%s\n',['# ----------- P bounds - ' sfa(sf,:) ' ------------']);
    if sf == 1;
        temp_string = ['psxy -R' rstring ' -JX2i/4i  -K -P -G200 << EOF > ' psname];
    else;
        temp_string = ['psxy -R' rstring ' -JX2i/4i  -K -O -P -G200 -X2i << EOF >> ' psname];
    end;
    fprintf(fid,'%s\n',temp_string);
    
    eval(['tx = pdata.delPpct_' sfa(sf,:) ';']);
    x1 = [1-tx 1-tx 1+tx 1+tx 1-tx];
    y1 = [0 plot_emax plot_emax 0 0];
    data = [x1' y1']';
    fprintf(fid,'%0.5g %0.5g\n',data);
    fprintf(fid,'%s\n','EOF');
    
    % Make the GMT basemap
    fprintf(fid,'%s\n',['# ----------- Draw plot axes - ' sfa(sf,:) ' ------------']);
    if sf == 1;
        temp_string = ['psbasemap -Ba0.2g0.05:"t/truet":/a' ediv ':"Elevation":WeSn -R' rstring ' -JX2i/4i -P -K -O >> ' psname];
    else;
        temp_string = ['psbasemap -Ba0.2g0.05:"t/truet":/a' ediv 'weSn -R' rstring ' -JX2i/4i -P -K -O >> ' psname];
    end;
        
    fprintf(fid,'%s\n',temp_string);
    
    
    
    % Plot the error bars
    fprintf(fid,'%s\n',['# ----------- Error bars on data - ' sfa(sf,:) ' ------------']);
    temp_string = ['psxy -R' rstring ' -JX2i/4i  -K -O -M -P -W1p/' cols{sf} ' << EOF >> ' psname];
    fprintf(fid,'%s\n',temp_string);
    for a = 1:length(pdata.elvs);
        eval(['tm = pdata.r_' sfa(sf,:) '(a);']);
        eval(['te = pdata.delr_' sfa(sf,:) '(a);']);
        xx = [tm-te tm+te];
        yy = [pdata.elvs(a) pdata.elvs(a)];
        data = [xx' yy']';
        fprintf(fid,'%0.5g %0.5g\n',data);
        fprintf(fid,'%s\n','>');
    end;
    fprintf(fid,'%s\n','EOF');
    
    % Plot the dots
    fprintf(fid,'%s\n',['# ----------- Data - ' sfa(sf,:) ' ------------']);
    if sf == 5;
        temp_string = ['psxy -R' rstring ' -JX2i/4i  -O -P -Sc0.1i -G' cols{sf} ' << EOF >> ' psname];
    else;
        temp_string = ['psxy -R' rstring ' -JX2i/4i  -K -O -P -Sc0.1i -G' cols{sf} ' << EOF >> ' psname];
    end;
    fprintf(fid,'%s\n',temp_string);
    eval(['xx = pdata.r_' sfa(sf,:) ';']);
    yy = pdata.elvs;
    data = [xx' yy']';
    fprintf(fid,'%0.5g %0.5g\n',data);
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
    out = ['ElvPlot' uniqueid];
else;
    out = 'tempElv';
end;