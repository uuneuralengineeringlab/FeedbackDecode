function [imutime, accel, rategyro, maghead, quaternion, Data] = readimukdf(fname)

% Reads in data saved to *.kdf file (Kalman decode filespec). This data is
% saved to disk when running FeedbackDecode.vi.
%
% Version: 2021518
% Author: Troy Tully & Eric Stone

fid = fopen(fname);
Header = fread(fid,[3,1],'single');
Data = fread(fid,[Header(3)+ Header(1),Inf],'single');
fclose(fid);



NIPTime = [];
NIPTime = Data(1,:);

imutime = {};
accel = {};
rategyro = {};
maghead = {};
quaternion = {};
for index = 1:Header(2)
    offset = (index-1)*10;

    imutime{index} = Data(2+offset,:);

    accel{index} = Data(3+offset:5+offset,:);

    rategyro{index} = Data(6+offset:8+offset,:);

    maghead{index} = Data(9+offset:11+offset,:);
    
    quaternion{index} = Data(12+offset:15+offset,:);
end

end