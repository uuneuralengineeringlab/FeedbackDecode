function [AllContStimAmp,AllContStimFreq,NIPTime] = readCSF(fname)

% Reads in data saved to *.csf file (continuous stim filespec). This data is
% saved to disk when running FeedbackDecode.vi. Rows are by electrode 1 to
% 200, columns are time.
%
% Version: 20171117
% Author: Tyler Davis

fid = fopen(fname);
Header = fread(fid,[3,1],'single');
Data = fread(fid,[sum(Header),Inf],'single');
fclose(fid);

idxs = cumsum(Header);
idxs = [[1;idxs(1:end-1)+1],idxs];

NIPTime = [];
if idxs(1,1)<=idxs(1,2)
    NIPTime = Data(idxs(1,1):idxs(1,2),:);
end
AllContStimAmp = [];
if idxs(2,1)<=idxs(2,2)
    AllContStimAmp = Data(idxs(2,1):idxs(2,2),:);
end
AllContStimFreq = [];
if idxs(3,1)<=idxs(3,2)
    AllContStimFreq = Data(idxs(3,1):idxs(3,2),:);
end
