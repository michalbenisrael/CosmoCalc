function out = increment_call_count();

% This function increments the counter of unique calculation requests. 
% For diagnostic purposes to sort out the pthread_create error.
%
% Syntax: out = increment_call_count();
%
% No arguments. Doesn't return anything. 
%
% Greg Balco -- UW Cosmogenic Nuclide Lab
% March, 2006
% Part of the CRONUS-Earth Be-10/Al-26 calculators

% open the file

if exist('/var/www/html/scratch/calls.log','file');
    load /var/www/html/scratch/calls.log -ascii
    callcount = calls(1);
else;
    callcount = 0;
end;

callcount = callcount + 1;

save /var/www/html/scratch/calls.log callcount -ascii

