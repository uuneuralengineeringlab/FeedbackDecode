function [str] = SRF2Str_FD(SRF)
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
str = '';
channelList=[];
for ii = 1:length(proprioKeys)
    for jj = 1:length(proprioValues{ii})
        region = SRF.proprioLabels{proprioKeys{ii}{1,1}};
        receptor = proprioKeys{ii}{1,2};
        channel = proprioValues{ii}(jj);
        channelList=[channelList,channel];
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        f1 = SRF.frequencyMap1(channel);
        f2 = SRF.frequencyMap2(channel);
        f3 = SRF.frequencyMap3(channel);
        str = [str region ',' receptor ',' sprintf('%0.0f', channel) ',' sprintf('%0.0f', amplitude) ',' sprintf('%0.3f', duration) ',' sprintf('%0.0f', f1) ',' sprintf('%0.0f', f2) ',' sprintf('%0.0f', f3) ','];
    end
end
for ii = 1:length(cutaneousKeys)
    for jj = 1:length(cutaneousValues{ii})
        region = SRF.cutaneousLabels{cutaneousKeys{ii}{1,1}};
        receptor = cutaneousKeys{ii}{1,2};
        channel = cutaneousValues{ii}(jj);
        channelList=[channelList,channel];
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        f1 = SRF.frequencyMap1(channel);
        f2 = SRF.frequencyMap2(channel);
        f3 = SRF.frequencyMap3(channel);
        str = [str region ',' receptor ',' sprintf('%0.0f', channel) ',' sprintf('%0.0f', amplitude) ',' sprintf('%0.3f', duration) ',' sprintf('%0.0f', f1) ',' sprintf('%0.0f', f2) ',' sprintf('%0.0f', f3) ','];
    end
end

%DP added June 3, 2016: include all other electrodes, even if no region was
%assigned (to make for easy use of any elect with saved parameters).
numb=0;
for ii = 1:length(SRF.amplitudeMap)
    channel = ii;
    if sum(channel==channelList)==0 && SRF.amplitudeMap(ii)>0%If this electrode hasn't been included yet, include it
        numb=numb+1;
        amplitude = SRF.amplitudeMap(channel);
        duration = SRF.durationMap(channel);
        f1 = SRF.frequencyMap1(channel);
        f2 = SRF.frequencyMap2(channel);
        f3 = SRF.frequencyMap3(channel);
        region = '';
        receptor = '';
        channelList=[channelList,channel];
        str = [str region ',' receptor ',' sprintf('%0.0f', channel) ',' sprintf('%0.0f', amplitude) ',' sprintf('%0.3f', duration) ',' sprintf('%0.0f', f1) ',' sprintf('%0.0f', f2) ',' sprintf('%0.0f', f3) ','];
    end    
end

str(end) = ';';

%% ------------- END OF CODE ------------
end