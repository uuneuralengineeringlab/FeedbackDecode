function [rotation_out,flex_out] = wristPositionAdjust(rotation_in,flex_in,max_diff,neutral,RightHand)
% Adjusts the position commands so the 20-degree maximum difference between
% the current and commanded position is satisfied

[~,sensors] = lkmex('sensor');

% sensor = b0+b1(bits) ----> bits = (sensor-b0)/b1. Bs found through bench testing
rotation_cur = sensors(1);
b_rot0 = -169.4694;
b_rot1 = 0.3343;
rotation_cur = (rotation_cur-b_rot0)/b_rot1;

flex_cur = sensors(2);
b_fe0 = 58.8144;
b_fe1 = -0.1156;
flex_cur = (flex_cur-b_fe0)/b_fe1;

% turn -1:1 MSMS commands to Luke commands from 0-1023
MSMS = [zeros(9,1); flex_in; 0; rotation_in];
Luke = MSMS2DEKA_wristp(MSMS,neutral);

rotation_in = Luke(1);
flex_in = Luke(2);
% see if command meets spec and use logic to adjust
if (rotation_in-rotation_cur) > max_diff(1)
    rotation_out = floor(rotation_cur+max_diff(1));
elseif (rotation_in-rotation_cur) < -max_diff(1)
    rotation_out = floor(rotation_cur-max_diff(1));
else
    rotation_out = floor(rotation_in);
end

if (flex_in-flex_cur) > max_diff(2)
    flex_out = floor(flex_cur+max_diff(2));
elseif (flex_in-flex_cur) < -max_diff(2)
    flex_out = floor(flex_cur-max_diff(2));
else
    flex_out = floor(flex_in);
end

if(rotation_out > 1023); rotation_out = 1023; end
if(rotation_out < 0); rotation_out = 0; end
if(flex_out > 1023); flex_out = 1023; end
if(flex_out < 0); flex_out = 0; end
    