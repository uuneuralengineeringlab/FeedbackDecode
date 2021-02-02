function SRF = updateSRF_FD(SRF,StimCell)
% updateSRF - Updates the SRF calibration and saves a new file
%
% Syntax:  [output1] = sendSRF(input1,input2,input3)
%
% Inputs:
%    input1 - SRF calibration struct: contains cutaneousMap, proprioceptionMap, amplitudeMap, durationMap, proprioceptionLabels, and cutaneousLabels.  See calibrateEncode.m for additional info
%
% Outputs:
%    output1 - updated SRF calibration struct (values may be changed, entries may be deleted)
%
% Example:
%    updated_CalibrationStruct = sendSRF(CalibrationStruct,StringOfCommands,filesavepath);
%
% Notes:
%    runs at an max speed of 52 ms.
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
amplitudeMap = SRF.amplitudeMap;
durationMap = SRF.durationMap;
frequencyMap1 = SRF.frequencyMap1;
frequencyMap2 = SRF.frequencyMap2;
frequencyMap3 = SRF.frequencyMap3;
proprioLabels = SRF.proprioLabels;
cutaneousLabels = SRF.cutaneousLabels;
proprioceptionMap = MapN('UniformValues',false);
cutaneousMap = MapN('UniformValues',false);
for ii = 1:size(StimCell,1)
    region = StimCell{ii,1};
    receptor = StimCell{ii,2};
    chan = str2double(StimCell{ii,3});
    amp = str2double(StimCell{ii,4});
    dur = str2double(StimCell{ii,5});
    f1 = str2double(StimCell{ii,6});
    f2 = str2double(StimCell{ii,7});
    f3 = str2double(StimCell{ii,8});
    switch receptor
        case {'MS1','MS2','SA2'}
            region = find(strcmp(region, proprioLabels));
            if(isKey(proprioceptionMap,region,receptor))
                temp = proprioceptionMap(region,receptor);
                temp = [temp chan];
                proprioceptionMap(region,receptor) = temp;
            else
                proprioceptionMap(region,receptor) = chan;
            end
        case {'SA1','RA1','RA2'}
            region = find(strcmp(region, cutaneousLabels));
            if(isKey(cutaneousMap,region,receptor))
                temp = cutaneousMap(region,receptor);
                temp = [temp chan];
                cutaneousMap(region,receptor) = temp;
            else
                cutaneousMap(region,receptor) = chan;
            end
        otherwise
            fprintf('Receptor Type of %s not found!\n',receptor);
    end
    amplitudeMap(chan) = amp;
    durationMap(chan) = dur;
    frequencyMap1(chan) = f1;
    frequencyMap2(chan) = f2;
    frequencyMap3(chan) = f3;
end
SRF.cutaneousMap = cutaneousMap;
SRF.proprioceptionMap = proprioceptionMap;
SRF.amplitudeMap = amplitudeMap;
SRF.durationMap = durationMap;
SRF.frequencyMap1 = frequencyMap1;
SRF.frequencyMap2 = frequencyMap2;
SRF.frequencyMap3 = frequencyMap3;
%% ------------- END OF CODE ------------
end