function [isDisconnected] = imudisconnect(shimmer3)


    IMUstate = shimmer3.getstate;
    
    % stop logging if logging
    if IMUstate == 'Streaming'
        shimmer3.stop;
        shimmer3.disconnect;
    elseif IMUstate == 'Connected'
        shimmer3.disconnect;
    end
    
%     isDisconnected = 0;
%     % find if connected
%     if ~shimmerStatus
%         isDisconnected = 1;
%     else
%         attempts = 10;
%         while ~isDisconnected && attempts
%             pause(0.0005)
%             isDisconnected = shimmer3.disconnect;                                      % disconnecting shimmer
%             attempts = attempts - 1;
%         end
%         
%         if isDisconnected
%             fprintf('Shimmer IMU disconnected\n')
%         else
%             fprintf('Shimmer IMU did not disconnect properly\n')
%         end
    end




