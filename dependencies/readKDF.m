function [Kinematics,Features,Targets,Kalman,NIPTime] = readKDF(fname)

% Reads in data saved to *.kdf file (Kalman decode filespec). This data is
% saved to disk when running FeedbackDecode.vi.
%
% Version: 20140517
% Author: Tyler Davis

fid = fopen(fname);
Header = fread(fid,[5,1],'single');
Data = fread(fid,[sum(Header),Inf],'single');
fclose(fid);

idxs = cumsum(Header);
idxs = [[1;idxs(1:end-1)+1],idxs];

NIPTime = [];
if idxs(1,1)<=idxs(1,2)
    NIPTime = Data(idxs(1,1):idxs(1,2),:);
end
Features = [];
if idxs(2,1)<=idxs(2,2)
    Features = Data(idxs(2,1):idxs(2,2),:);
end
Kinematics = [];
if idxs(3,1)<=idxs(3,2)
    Kinematics = Data(idxs(3,1):idxs(3,2),:);
end
Targets = [];
if idxs(4,1)<=idxs(4,2)
    Targets = Data(idxs(4,1):idxs(4,2),:);
end
Kalman = [];
if idxs(5,1)<=idxs(5,2)
    Kalman = Data(idxs(5,1):idxs(5,2),:);
end