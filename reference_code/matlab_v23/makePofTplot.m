function out = makePofTplot(tdata,localFlag);

% Function to make a P vs. T plot using GMT and ImageMagick.
% 
% Syntax out = makePofTplot(tdata,localFlag);
% 
% tdata is a structure with fields:
%
%   tv - time vector
%   Rc - site paleorigidity vector
%   P10_St - scalar production rate via Stone 2000
%   P10_De, P10_Du, P10_Li, P10_Lm - vector P10(t) from other scaling
%   schemes
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

if nargin < 2; localFlag = 0; end;

% Find the limits for stuff

tmax_int = ceil(max(tdata.tv) ./ 1000) .* 1000;
tmax = int2str(tmax_int); 

torder = ceil(log10(tmax_int));
tdiv_int = (0.5*(10^(torder - 1)));
if (tmax_int./tdiv_int) > 8;
    tdiv_int = 2*tdiv_int;
end;
tdiv = int2str(tdiv_int);


Rcmax = (ceil(max([max(tdata.Rc_De) max(tdata.Rc_Du) max(tdata.Rc_Li) max(tdata.Rc_Lm)])));
Rcmin = (floor(min([min(tdata.Rc_De) min(tdata.Rc_Du) min(tdata.Rc_Li) min(tdata.Rc_Lm)])));
Rcrange = Rcmax - Rcmin;
Rcmax = int2str(Rcmax);
Rcmin = int2str(Rcmin);
if Rcrange <= 5;
    Rcdiv = '1';
elseif Rcrange <=10;
    Rcdiv = '2';
else;
    Rcdiv = '5';
end;

Pmin = min([min(tdata.P10_De) min(tdata.P10_Du) min(tdata.P10_Li) min(tdata.P10_Lm) tdata.P10_St]);
Pmax = max([max(tdata.P10_De) max(tdata.P10_Du) max(tdata.P10_Li) min(tdata.P10_Lm) tdata.P10_St]);
Prange = Pmax-Pmin;

Pmin = int2str(floor(Pmin./5) * 5);
Pmax = int2str(ceil(Pmax./5) * 5);

if Prange <= 8;
    Pdiv = '2';
elseif Prange <=20;
    Pdiv = '5';
else;
    Pdiv = '10';
end;

% Now see if we can make raster images using GMT and ghostscript. 

uniqueid = int2str(round(rand(1)*1e6));
% There is no effort made to see if this really is unique. 
% I mean, what are the odds?

% Everything goes on in the scratch directory. 
if localFlag == 0;
    fname = ['/var/www/html/scratch/pvst' uniqueid];
else;
    fname = ['temp'];
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

jstring = '-JX6i/1i';

% GMT rigidity 1
fprintf(fid,'%s\n','# ----------- Plot Desilets cutoff rigidity vs. time, in red ------------');
temp_string = ['psxy -R0/' tmax '/' Rcmin '/' Rcmax ' -Ba' tdiv 'g' tdiv ':"yr BP":/a' Rcdiv 'g' Rcdiv ':"Rc (GV)":WeSn ' jstring ' -K -P -W1p/255/0/0 << EOF > ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.Rc_De']');
fprintf(fid,'%s\n','EOF');

% GMT rigidity 2
fprintf(fid,'%s\n','# ----------- Plot Dunai cutoff rigidity vs. time, in green ------------');
temp_string = ['psxy -R0/' tmax '/' Rcmin '/' Rcmax ' ' jstring '  -K -O -P -W1p/0/255/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.Rc_Du']');
fprintf(fid,'%s\n','EOF');

% GMT rigidity 3
fprintf(fid,'%s\n','# ----------- Plot Lifton cutoff rigidity vs. time, in blue ------------');
temp_string = ['psxy -R0/' tmax '/' Rcmin '/' Rcmax ' ' jstring ' -K -O -P -W1p/0/0/255 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.Rc_Li']');
fprintf(fid,'%s\n','EOF');

% GMT rigidity 3
fprintf(fid,'%s\n','# ----------- Plot time-dependent Lal cutoff rigidity vs. time, in cyan ------------');
temp_string = ['psxy -R0/' tmax '/' Rcmin '/' Rcmax ' ' jstring ' -K -O -P -W1p/0/255/255 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.Rc_Lm']');
fprintf(fid,'%s\n','EOF');


% GMT production rate 1
fprintf(fid,'%s\n','# ----------- Plot Desilets production rate vs. time, in red ------------');
temp_string = ['psxy -R0/' tmax '/' Pmin '/' Pmax ' -Bg' tdiv '/a' Pdiv 'g' Pdiv ':"P10 (atoms/g/yr)":Wesn ' jstring ' -Y1.5i -O -K -P -M -W1p/255/0/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.P10_De']');
fprintf(fid,'%s\n','EOF');

% GMT production rate 2
fprintf(fid,'%s\n','# ----------- Plot Dunai production rate vs. time, in green ------------');
temp_string = ['psxy -R0/' tmax '/' Pmin '/' Pmax ' ' jstring ' -O -K -P -M -W1p/0/255/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.P10_Du']');
fprintf(fid,'%s\n','EOF');

% GMT production rate 3
fprintf(fid,'%s\n','# ----------- Plot Lifton production rate vs. time, in blue ------------');
temp_string = ['psxy -R0/' tmax '/' Pmin '/' Pmax ' ' jstring ' -O -K -P -M -W1p/0/0/255 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.P10_Li']');
fprintf(fid,'%s\n','EOF');

% GMT production rate 4
fprintf(fid,'%s\n','# ----------- Plot time-dependent Lal production rate vs. time, in cyan ------------');
temp_string = ['psxy -R0/' tmax '/' Pmin '/' Pmax ' ' jstring ' -O -K -P -M -W1p/0/255/255 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[tdata.tv' tdata.P10_Lm']');
fprintf(fid,'%s\n','EOF');

% GMT production rate 5
fprintf(fid,'%s\n','# ----------- Plot Lal/Stone constant production rate vs. time, in black ------------');
temp_string = ['psxy -R0/' tmax '/' Pmin '/' Pmax ' ' jstring ' -O -P -M -W1p/0 << EOF >> ' psname];
fprintf(fid,'%s\n',temp_string);
fprintf(fid,'%0.5g %0.5g\n',[0 tdata.P10_St]');
fprintf(fid,'%0.5g %0.5g\n',[tmax_int tdata.P10_St]');
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
end;
    
% return the root file name
out = ['pvst' uniqueid];

