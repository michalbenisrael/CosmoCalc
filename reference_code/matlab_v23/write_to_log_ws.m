function out = write_to_log_ws(log_entry)

% This function writes a line to the web service log. 
%
% Syntax: out = write_to_log(log_entry);
%
% log_entry is a string
% just returns the output of fprintf on success.
%
% Greg Balco -- Berkeley Geochronology Center

% open the file

fid = fopen('/var/www/html/scratch/wslog.log','a');

out = fprintf(fid,'%s\n',log_entry);

fclose(fid);
