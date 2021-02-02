function SRF2Mat_FD(filelocation,savelocation,varargin)

if nargin>2
    handType = varargin{1};
else
    handType = 'MPL'; %MPL or Luke
end

SRFdata = readSRF(filelocation);
if(length(SRFdata) == 1)
    [cutaneousMap,proprioceptionMap,amplitudeMap,durationMap,frequencyMap1,frequencyMap2,frequencyMap3,SRF] = calibrateEncode(SRFdata,handType);
    proprioLabels = fieldnames(SRF.info.proprioceptionLabels);
    cutaneousLabels = fieldnames(SRF.info.contactLabels);
    save(savelocation,'cutaneousMap','proprioceptionMap','amplitudeMap','durationMap','frequencyMap1','frequencyMap2','frequencyMap3','proprioLabels','cutaneousLabels', 'handType');
end
