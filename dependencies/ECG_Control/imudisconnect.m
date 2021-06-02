function [isDisconnected] = imudisconnect(shimmer3)

[shimmerStatus, islogging] = shimmer3.getstatus;

% stop logging if logging
%if islogging
%    imustop(shimmer3)
%end

isDisconnected = 0;
% find if connected
if ~shimmerStatus
    isDisconnected = 1;
else
    attempts = 10;
    while ~isDisconnected && attempts
        pause(0.0005)
        isDisconnected = shimmer3.disconnect;                                      % disconnecting shimmer
        attempts = attempts - 1;
    end
    
    if isDisconnected 
        fprintf('Shimmer IMU disconnected\n')   
    else
        fprintf('Shimmer IMU did not disconnect properly\n')
    end
end 


 
