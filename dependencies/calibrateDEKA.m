function [DEKABLSensors] = calibrateDEKA()
    numDOF = 6;
    numSensors = 13;
    positionCommand = zeros(numDOF,1);
    sensorValues = zeros(numSensors,numDOF*3);
    updateDEKA(positionCommand);    %default position
    waitTime = 1; %1 second wait
    pause(waitTime);
    for ii = 1:numDOF %go through each DOF and determine max sensor values
        positionCommand(ii) = 1;
        jj = ii*3-2;
        [~, sensors] = updateDEKA(positionCommand);    %rest sensors, move to flex
        sensorValues(:,jj) = sensors(10:22); %extract just contact sensors
        pause(waitTime);
        positionCommand(ii) = -1;
        [~, sensors] = updateDEKA(positionCommand);    %flexed sensors, move to extended
        sensorValues(:,jj+1) = sensors(10:22); %extract just contact sensors
        pause(waitTime);
        positionCommand(ii) = 0;
        [~, sensors] = updateDEKA(positionCommand);    %extended sensors, move to rest
        sensorValues(:,jj+2) = sensors(10:22); %extract just contact sensors
        pause(waitTime);
        if(ii == 4)  %thumb intrinsic needs to be moved out of the way
            positionCommand(ii) = 1;   %fully extended
            [~, sensors] = updateDEKA(positionCommand);
            pause(waitTime);
        end
    end
    positionCommand = zeros(numDOF,1);
    updateDEKA(positionCommand);    %default position
    mins = min(sensorValues,[],2);
    maxes = max(sensorValues,[],2);
    DEKABLSensors = [mins,maxes];
end