function [wristRotateVelocity, wristFlexVelocity] = wristPositionToVelocity(desiredRotatePosition,desiredFlexPosition,RightHand)
    %convert MSMS position control to DEKA velocity control (for wrist only)
    [~, sensorData] = lkmex('sensor');
    rotateLocation = sensorData(1);
    flexLocation = sensorData(2);
    %% scale to limits:
    %rotation limits: -120:175
    %flexion limits: -55:55
    switch RightHand
        case 0
            if(rotateLocation < 0)  %negative limit
                rotateLocation = -rotateLocation / 175;
            else
                rotateLocation = -rotateLocation / 120;
            end
        case 1
            if(rotateLocation < 0)  %negative limit
                rotateLocation = rotateLocation / 120;
            else
                rotateLocation = rotateLocation / 175;
            end
    end
    flexLocation = flexLocation / 55;
    %% calculate velocity
    wristFlexVelocity = (desiredFlexPosition - flexLocation); %finite differences
    wristRotateVelocity = (desiredRotatePosition - rotateLocation);
    %% safe check values
    if(wristFlexVelocity > 1); wristFlexVelocity = 1;    end
    if(wristFlexVelocity < -1); wristFlexVelocity = -1;    end
    if(wristRotateVelocity > 1); wristRotateVelocity = 1;    end
    if(wristRotateVelocity < -1); wristRotateVelocity = -1;    end

end
