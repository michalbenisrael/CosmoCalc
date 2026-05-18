function out = dump_location_v2(type,lat,long);

% Dumps latitude and longitude of an exposure-dating sample to a file -- 
% then redraws the map of all exposure ages. 
%
%
% This is version 2. Not the same as version 1, be careful.
%
% out = dump_location_v2(type,lat,long);
%
% type is 'e' or 't' 
% lat and long are matching vectors of same size

% Check to see if it is one of the calibration samples
% Or an integer latitude
% if it is, do nothing

sample_lats = [41.4436 -77.313  41.3567 41.3578 57.968 57.976  57.87 -77.073 -77.074 38.6139 38.6136 38.6204 -77.8282];

for a = 1:length(lat);
    if any(lat(a) == sample_lats);
        return;
    end;
    if (round(lat(a)) - lat) < 1e-5;
        return;
    end; 
    if (round(long(a)) - long) < 1e-5;
       return;
    end;
end;

% open file for append, depending on whether it is erosion or not

if strcmp(type,'e');
    fid = fopen('/var/www/html/scratch/e_locations.dat','a');
elseif strcmp(type,'t');
    fid = fopen('/var/www/html/scratch/t_locations.dat','a');
end;
    
% make the vectors work right

data = [lat' long'];

fprintf(fid,'%7.4f %7.4f\n',data');

fclose(fid);

% redo the map

temp_string = ['/var/www/html/scratch/locations.sh'];
system(temp_string);

