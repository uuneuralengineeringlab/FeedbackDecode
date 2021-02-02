function [ContactVals,MotorVals,NIPTime] = readPHF(fname)

% Reads in data saved to *.phf file (Physical hand filespec). This data is
% saved to disk when running FeedbackDecode.vi.
%
% Version: 20161129
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
ContactVals = [];
if idxs(2,1)<=idxs(2,2)
    ContactVals = Data(idxs(2,1):idxs(2,2),:);
end
MotorVals = [];
if idxs(3,1)<=idxs(3,2)
    MotorVals = Data(idxs(3,1):idxs(3,2),:);
end