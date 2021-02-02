function [str] = sendSRF(SRF)
% sendSRF - sends the SRF data to labVIEW as a string.
%
% Syntax:  [output1] = sendSRF(input1)
%
% Inputs:
%    input1 - SRF calibration struct: contains cutaneousMap, proprioceptionMap, amplitudeMap, durationMap, proprioceptionLabels, and cutaneousLabels.  See calibrateEncode.m for additional info
%
% Outputs:
%    output1 - string containing SRF data for labVIEW display and editing:  String format: 'regionA,receptorA,channelA,amplitudeA,durationA,indexA;regionB,receptorB,...,indexB;...;...indexN'
%               
% Notes:
%    Future considerations: For increased performance: preallocate chars or use fwrite directly.
%
% Example:
%    StringToLabVIEW = sendSRF(SRFcalibrationMATFile);
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
% July 2015; Last revision: 7-July-2015

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
        str = [str region ',' receptor ',' sprintf('%d', channel) ',' sprintf('%d', amplitude) ',' sprintf('%d', duration) ';'];
    end
end
for ii = 1:length(cutaneousKeys)
    for jj = 1:length(cutaneousValues{ii})
        region = SRF.cutaneousLabels{cutaneousKeys{ii}{1,1}};
        receptor = cutaneousKeys{ii}{1,2};
        channel = cutaneousValues{ii}(jj);
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        str = [str region ',' receptor ',' sprintf('%d', channel) ',' sprintf('%d', amplitude) ',' sprintf('%d', duration) ';'];
    end
end

str = str(1:end-1);

%% ------------- END OF CODE ------------
end