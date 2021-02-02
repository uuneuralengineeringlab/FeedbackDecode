%% This is a template file
% Contents:  This file can be edited to generate new color labels
%   All colors are given in [R,G,B] format.
%   Names of the sensors are based on MuJoCo software.
%
% Other m-files required: none
% Subfunctions: 
% MAT-files required: none
%
% See also: genSensorRegions.m (which uses labels and image to generate sensor locations)

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 3-June-2015

%------------- BEGIN CODE ---------------
% Clear all variables from workspace
clear all;
% Assign each name a specific color (in RGB format)
palm_thumb = [163,73,164];
palm_pinky = [218,173,218];
palm_side = [255,174,201];
palm_back = [185,122,87];
thumb_proximal = [255,185,185];
thumb_medial = [255,100,100];
thumb_distal = [237,28,36];
index_proximal = [255,191,149];
index_medial = [255,158,94];
index_distal = [255,127,39];
middle_proximal = [255,252,196];
middle_medial = [255,249,119];
middle_distal = [255,242,0];
ring_proximal = [156,237,181];
ring_medial = [69,220,115];
ring_distal = [34,177,76];
pinky_proximal = [168,228,255];
pinky_medial = [79,202,255];
pinky_distal = [0,162,232];
% Save all variables to a .mat file
filename = 'MyContactSensorColorLabels';
save(filename);
%------------- END OF CODE --------------