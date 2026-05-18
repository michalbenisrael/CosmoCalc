function out = makeEplot(pdata,localFlag);

% Function to make a Be* - Al*/Be* plot using GMT and ImageMagick.
% 
% Syntax out = makeEplot(pdata,localFlag);
%
% pdata is a structure with N26_norm, N10_norm, delN10_norm, delN26_norm
% Lsp, l10, and l26. 
% 
% the first four things can be vectors. 
%
% the output argument is the filename root.
%
% localFlag = 1 disables server-specific pathnames and ImageMagick
% conversion. Only writes the GMT code as tempE.gmt.
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

% create data for the simple-exposure line and the simple-erosion line. 

tempt = logspace(0,7,100);
be = (1/pdata.l10)*(1-exp(-pdata.l10*tempt));
al = (1/pdata.l26)*(1-exp(-pdata.l26*tempt));
bound1 = [be' (al./be)']';
tempe = logspace(-6,1,100);
be = 1./(pdata.l10 + tempe./pdata.Lsp);
al = 1./(pdata.l26 + tempe./pdata.Lsp);
bound2 = [be' (al./be)']';

% find the number of samples

numsamples = length(pdata.N26_norm);

% Open the text file

uniqueid = int2str(round(rand(1)*1e6));
% no effort made to see if this really is unique. 
% I mean, what are the odds?

% everything goes on in the scratch directory. 
if localFlag == 0;
    fname = ['/var/www/html/scratch/albe' uniqueid];
else;
    fname = 'tempE';
end;

gmtname = [fname '.gmt'];
if localFlag == 0;
    psname = [fname '.ps'];
else;
    psname = [fname '.eps'];
end;
jpgname = [fname '.jpg'];
    
% open file for write
fid = fopen(gmtname,'w');

% GMT setup commands. These aren't needed. 

%fprintf(fid,'%s\n','gmtset PAPER_MEDIA square8');
%fprintf(fid,'%s\n','gmtset ANOT_FONT 3 ANOT_FONT_SIZE 14');
%fprintf(fid,'%s\n','gmtset LABEL_FONT 3 LABEL_FONT_SIZE 14');
%fprintf(fid,'%s\n','gmtset FRAME_PEN 8');

% Make the GMT basemap
fprintf(fid,'%s\n','# ----------- Draw the plot axes ------------');
temp_string = ['psbasemap -Ba1p:"[Be-10]*":/a0.2:"[Al-26]* / [Be-10]*":WeSn -R1e3/1e7/0/1.2 -JX6il/6i -K -P > ' psname];
fprintf(fid,'%s\n',temp_string);

% GMT simple-exposure boundaries
fprintf(fid,'%s\n','# ----------- Plot the simple exposure region ------------');
temp_string = ['psxy -R1e3/1e7/0/1.2 -JX6il/6i  -P -K -M -O -W1p/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',bound1);
fprintf(fid,'%s\n','>');
fprintf(fid,'%0.5g %0.5g\n',bound2);
fprintf(fid,'%s\n','EOF');

% loop for all the ellipses

for a = 1:numsamples;
	% get the x,y for the ellipse

	[ex,ey] = ellipse(pdata.N10_norm(a),pdata.delN10_norm(a),pdata.N26_norm(a),pdata.delN26_norm(a),0);

	% GMT ellipse 
	fprintf(fid,'%s\n','# ----------- Plot the ellipse ------------');
	temp_string = ['psxy -R1e3/1e7/0/1.2 -JX6il/6i -P  -O -K -W1p/255/0/0 << EOF >> ' psname];
	fprintf(fid,'%s\n',temp_string);
	fprintf(fid,'%0.5g %0.5g\n',[ex',ey']');
	fprintf(fid,'%s\n','EOF');
end;


% GMT center dots
fprintf(fid,'%s\n','# ----------- Plot the center point of the ellipse ------------');
temp_string = ['psxy -R1e3/1e7/0/1.2 -JX6il/6i -P  -O -Sc0.05i -G255/0/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
% loop for all the center dots
for a = 1:numsamples;
	fprintf(fid,'%0.5g %0.5g\n',[pdata.N10_norm(a) (pdata.N26_norm(a)./pdata.N10_norm(a))]');
end;

fprintf(fid,'%s\n','EOF');


% close the file
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

    % return the name of the jpeg you just made
    out = ['albe' uniqueid];
else;
    out = 'tempE';
end;
