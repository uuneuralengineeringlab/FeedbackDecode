
function [DEKABLSensors] = calibrateDEKA_wristp(neutral)
    numDOF = 6;
    numSensors = 13;
    positionCommand = zeros(numDOF,1);
    sensorValues = zeros(numSensors,numDOF*3);
    updateDEKA_wristp(positionCommand,neutral);    %default position
    waitTime = 1; %1.5 second wait
    pause(waitTime);
    for ii = 1:numDOF %go through each DOF and determine max sensor values
        if ii == 1 || ii == 2 % Wrists in position mode need extra time to adjust
            waitTime = 2;
        else
            waitTime = 1;
        end
        positionCommand(ii) = 1;
        jj = ii*3-2;
        t = tic;
        while toc(t) <= waitTime
            [~, sensors] = updateDEKA_wristp(positionCommand,neutral);    %rest sensors, move to flex
        end
        sensorValues(:,jj) = sensors(10:22); %extract just contact sensors
        positionCommand(ii) = -1;
        
        t = tic;
        while toc(t) <= waitTime
            [~, sensors] = updateDEKA_wristp(positionCommand,neutral);    %flexed sensors, move to extended
        end
        sensorValues(:,jj+1) = sensors(10:22); %extract just contact sensors
        positionCommand(ii) = 0;
        
        t = tic;
        while toc(t) < waitTime
            [~, sensors] = updateDEKA_wristp(positionCommand,neutral);    %extended sensors, move to rest
        end
        sensorValues(:,jj+2) = sensors(10:22); %extract just contact sensors
        if(ii == 4)  %thumb intrinsic needs to be moved out of the way
            positionCommand(ii) = 1;   %fully extended
            [~, sensors] = updateDEKA_wristp(positionCommand,neutral);
            pause(waitTime);
        end
    end
    positionCommand = zeros(numDOF,1);
    
    t = tic;
    while toc(t) < waitTime
        updateDEKA_wristp(positionCommand,neutral);    %default position
    end
    mins = min(sensorValues,[],2);
    maxes = max(sensorValues,[],2);
    DEKABLSensors = [mins,maxes];
end