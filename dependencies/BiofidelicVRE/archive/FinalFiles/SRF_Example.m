% THIS IS AN EXAMPLE FILE:
%
% Contents:
%   This file contains examples of how to work with an process SRF data structures in MATLAB.
%   Lesson 1:   How to load and read values from the SRF data structure
%   Lesson 2:   How to use the getSRF function to search the SRF data structure
%   Lesson 3:   How to assign sensor names to precepts based on location
%   Lesson 4:   How to assign receptor types to each channel automatically
%   Lesson 5:   How to use an SRF file to calibrate an encode function
%   Lesson 6:   Writing an SRF file
%
%   Appendix A: How to generating a contact sensor solor labels .mat file
%
%   Additional lessons may be added by request. See author information below for additional help.
%
% Other m-files required: getSRF.m, readSRF.m, assignRegions.m, calibrateContact.m, encodeContact.m, writeSRF.m
% Subfunctions: none
% MAT-files required: none
%
% See also: none

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 15-June-2015

%------------- BEGIN CODE ---------------
%% Lesson 1: Loading and viewing SRF data:
%Read in a single SRF file
srfPath = 'C:\Users\Jake\Box Sync\HAPTIX\Data\HaptixInc2.srf';
mySRF = readSRF(srfPath);
%Input a folder path and load metadata:
myFolder = 'C:\Users\Jake\Box Sync\HAPTIX\Data';
all_SRF_data = readSRF(myFolder);
%Select a specific SRF file to work with:
mySRF = all_SRF_data(1).data;
%View information about the file:
mySRF
%View information about the subfiles:
mySRF.info
mySRF.input
mySRF.output
%View information about the first input
mySRF.input(1)
%Determine the frequency pattern for the first channel of the first input
mySRF.input(1).frequencyPatterns_Hz_a{1}    %note the use of { } instead of ( ).  This is because we are accessing a cell array
%Determine the electrode number for the first input
mySRF.input(1).electrodes_d(1)
%% Lesson 2: SRF data operations
%Get all electrode info for every trial
channels = {mySRF.input.electrodes_d}
%Learn how to search through SRF files to select specific criteria
help getSRF
%Get all experiments that cause ANY vibration:
newSRF = getSRF(mySRF,'quality_s','Vibration','involves')
%Get all experiments that cause ONLY vibration:
newSRF = getSRF(mySRF,'quality_s','Vibration','onlyinvolves')
%Get all experiments that cause any vibration due to any stimulus involving channel 1
newSRF = getSRF(mySRF,'quality_s','Vibration','involves','electrodes_d',[1],'involves')
%% Lesson 3: Assigning sensor names to precepts based on location
% Create a new SRF with region labels (this step may take some time)
mySRF = assignContactSensor(mySRF);
mySRF = assignProprioceptionSensor(mySRF);
% Verify the regions have been added by searching the new field (note the new field will always end with 'Sensor_s')
newSRF = getSRF(mySRF,'contactSensor_s','palm_thumb','involves');
%% Lesson 4: Assigning receptor types for each channel automatically
%simply call the assign receptors to determine which receptor type each channel is.  For more information, type: Help assignReceptors
mySRF = assignReceptors(mySRF);
%% Lesson 5: Calibrating and using the encode function
%acquire a specific SRF file path or folder you want to use
srfPath = 'C:\Users\Jake\Box Sync\HAPTIX\Data\HaptixInc2.srf';
%call the automated offline calibration function.  Type Help calibrateSRF for more information.
calibrationpath = calibrateSRF(srfPath);
load(calibrationpath);
%alternatively, you can calibrate an SRF file in the workspace manually:
mySRF = readSRF(srfPath);
[cutaneousMap,proprioceptionMap,amplitudeMap, durationMap, frequencyMap1, frequencyMap2, frequencyMap3, calibratedSRF] = calibrateEncode(mySRF);
%% Lesson 6: Writing an SRF file
% Writing an SRF file is simple - just call the writeSRF function.  Type Help writeSRF for more information.

%write an SRF file with the name 'mySRFoutput' to the location 'C:\Users\Jake\Documents\MATLAB\Utah\Text'
writeSRF(mySRF,'mySRFoutput', 'C:\Users\Jake\Documents\MATLAB\Utah\Text');
%% Lesson 7: Using the encode function
% make fake contact and motor values:
contact = ones(19,1);
motorpos = ones(13,1);
motorvel = motorpos;
% load a calibration file
calibration = load(calibrateSRF('C:\Users\Jake\Box Sync\HAPTIX\Data\HaptixInc2.srf'))
[channel,frequency,amplitude,duration] = encode(contact,motorpos,motorvel,calibration);
% a list of optional parameters can be found using the Help encode function
%% Appendix A: Generating a contact sensor color labels .mat file
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
%%------------- END OF CODE --------------