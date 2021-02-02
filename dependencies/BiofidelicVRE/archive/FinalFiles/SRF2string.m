function [str] = SRF2string(SRF)
% SRF2string - converts the SRF data to a string.
%
% Syntax:  [output1] = SRF2string(input1)
%
% Inputs:
%    input1 - SRF calibration struct: contains cutaneousMap, proprioceptionMap, amplitudeMap, durationMap, proprioceptionLabels, and cutaneousLabels.  See calibrateEncode.m for additional info
%
% Outputs:
%    output1 - string containing SRF data for labVIEW display and editing:  String format: 'regionA,receptorA,channelA,amplitudeA,durationA,FreqMap1,FreqMap2,FreqMap3,indexA,regionB,receptorB,...,indexB,...,...indexN'
%               
% Notes:
%    Future considerations: For increased performance: preallocate chars or use fwrite directly.
%
% Example:
%    StringToLabVIEW = SRF2string(SRFcalibrationMATFile);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: 

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 21-July-2015

%------------- BEGIN CODE ---------------
proprioKeys = keys(SRF.proprioceptionMap);
proprioValues = values(SRF.proprioceptionMap);
cutaneousKeys = keys(SRF.cutaneousMap);
cutaneousValues = values(SRF.cutaneousMap);
str = 'BiofidelicVRECalibration:';
for ii = 1:length(proprioKeys)
    for jj = 1:length(proprioValues{ii})
        region = SRF.proprioLabels{proprioKeys{ii}{1,1}};
        receptor = proprioKeys{ii}{1,2};
        channel = proprioValues{ii}(jj);
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        f1 = SRF.frequencyMap1(channel);
        f2 = SRF.frequencyMap2(channel);
        f3 = SRF.frequencyMap3(channel);
        str = [str region ',' receptor ',' sprintf('%d', channel) ',' sprintf('%d', amplitude) ',' sprintf('%d', duration) ',' sprintf('%f', f1) ',' sprintf('%f', f2) ',' sprintf('%f', f3) ';'];
    end
end
for ii = 1:length(cutaneousKeys)
    for jj = 1:length(cutaneousValues{ii})
        region = SRF.cutaneousLabels{cutaneousKeys{ii}{1,1}};
        receptor = cutaneousKeys{ii}{1,2};
        channel = cutaneousValues{ii}(jj);
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        f1 = SRF.frequencyMap1(channel);
        f2 = SRF.frequencyMap2(channel);
        f3 = SRF.frequencyMap3(channel);
        str = [str region ',' receptor ',' sprintf('%d', channel) ',' sprintf('%d', amplitude) ',' sprintf('%d', duration) ',' sprintf('%f', f1) ',' sprintf('%f', f2) ',' sprintf('%f', f3) ';'];
    end
end

str = str(1:end-1);

%% ------------- END OF CODE ------------
end