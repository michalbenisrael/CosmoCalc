function out = write_to_log(log_entry)

% This function writes a line to the calculator log. 
%
% Syntax: out = write_to_log(log_entry);
%
% log_entry is a string
% just returns the output of fprintf on success.
%
% Greg Balco -- UW Cosmogenic Nuclide Lab
% March, 2006
% Part of the CRONUS-Earth Be-10/Al-26 calculators

% open the file

fid = fopen('/var/www/html/scratch/calculog.log','a');

out = fprintf(fid,'%s\n',log_entry);

fclose(fid);
