function eventCode = targ2EEGEvent(targRad, targPos, eventType)
% eventCode = targ2EEGEvent(targRad, targPos) Converts a target radius to
% an event code for sending to the ActiCHAMP system. Targets are coded by
% DOF and size of target. Note that only individual movements are encoded
% by discrete events. Combination movements receive their own codes. 
% Event encoding:
%     100 - 230: Buzz on
%         100 - 109: DOF 1, TargRad floor from 0 to 1 (e.g., 0.35 = code 103)
%         110 - 119: DOF 2, same size encoding
%         ...
%         210 - 219: DOF 12, same size encoding
%         220 - 229: Combination target, same size encoding
%         230: No active target (no targPos other than 0)
%     240 - 249: Buzz off, same size encoding
%     10 - 19: Target Onset, same size encoding
%     20 - 29: Target Offset, same size encoding
%     30 - 39: Button Press, same size encoding
%     40 - 49: Button Release, same size encoding
% 
% Inputs:
%     targRad: scalar value of target size
%     targPos: 1x12 or 12 x 1 vector of DOF target positions
%     eventType: char of event type (BuzzOn, BuzzOff, TargOn, TargOff,
%                                    ButtonPress, ButtonRelease)
% Outputs:
%     eventCode: integer corresponding to event code
% 
% Written by: Michael Paskett
% Created: 3/17/20
% Last Modified: 3/17/20

% account for unlikely case target size is greater than or equal 1 for
% event coding
targRad(targRad >= 1) = 0.99;

switch eventType
    case 'BuzzOn' % 100 to 230
        % handle individual movements
        if (nnz(targPos) == 1)
            activeDOF = find(targPos)*10 - 10;
            targID = floor(targRad*10);
            eventCode = activeDOF + targID;
        elseif (nnz(targPos) == 0) % if for some reason there's no active target...
            eventCode = 130;
        else % handle combination movements
            activeDOF = 120;
            targID = floor(targRad*10);
            eventCode = activeDOF + targID;
        end
        eventCode = eventCode + 100; % event codes are all 100 to 230, inclusive
    case 'BuzzOff' % 240 - 249
        targID = floor(targRad*10);
        eventCode = targID + 240;
    case 'TargOn' % 10 - 19
        targID = floor(targRad*10);
        eventCode = targID + 10;
    case 'TargOff' % 20 - 29
        targID = floor(targRad*10);
        eventCode = targID + 20;
    case 'ButtonPress' % 30 - 39
        targID = floor(targRad*10);
        eventCode = targID + 30;
    case 'ButtonRelease' % 40 - 49
        targID = floor(targRad*10);
        eventCode = targID + 40;        
end
end