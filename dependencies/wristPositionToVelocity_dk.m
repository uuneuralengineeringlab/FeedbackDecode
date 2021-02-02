function [wristRotateVelocity, wristFlexVelocity] = wristPositionToVelocity_dk(desiredRotatePosition,desiredFlexPosition,RightHand)
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
                rotateLocation = rotateLocation / 175;
            else
                rotateLocation = rotateLocation / 120;
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
    if (desiredFlexPosition - flexLocation) > 0.1
        wristFlexVelocity = 1;
    elseif (desiredFlexPosition - flexLocation) < -0.1
        wristFlexVelocity = -1;
    else
        wristFlexVelocity = 0;
    end
    
    if abs(desiredRotatePosition - rotateLocation) > 0.2
        wristRotateVelocity = desiredRotatePosition - rotateLocation;
    else
        wristRotateVelocity = 0;
    end
    
    if wristRotateVelocity > 1; wristRotateVelocity = 1; end
    if wristRotateVelocity < -1; wristRotateVelocity = -1; end
end
