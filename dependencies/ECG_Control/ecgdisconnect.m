function [isDisconnected] = ecgdisconnect(shimmer3)

[shimmerStatus, islogging] = shimmer3.getstatus;

% stop logging if logging
if islogging
    ecgstop(shimmer3)
end

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
        fprintf('Shimmer ECG disconnected\n')   
    else
        fprintf('Shimmer did not disconnect properly\n')
    end
end 


 
