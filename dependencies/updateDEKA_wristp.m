function [motorOut, sensorOut] = updateDEKA_wristp(motorPositions, varargin)
%updates DEKA hand position with motorPosition values from -1 to 1.
%motor values (double 12x1 or 1x12) in order of: [thumb, index, middle, ring, pinky, thumb intrinsic, index intrinsic, ring intrinsic, pink intrinsic, wrist flex, wrist deviation, wrist rotation]
% NOTE: wrist commands are sent in terms of velocity, not position! 
%sensor values (double 19x1) returned in the order of:
%   {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
%   'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD';...
%   'index_medial';'index_distal';'middle_distal';'ring_distal';...
%   'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
%   'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};

%Note: currently wrist is in velocity control

%% initialization (right hand or left hand?)
if nargin > 1 && ~isempty(varargin{1})
    neutral = varargin{1};   
else
    neutral = [];
end

if nargin > 2 && ~isempty(varargin{2})
    rightHand = varargin{2};    %try to get right hand true/false
else
    rightHand = 1;  %assume right hand if no input
end
    
    
%% setup motor commands
    len = length(motorPositions);
    switch len
        case 6  %6 degree of freedom for DEKA (use these 6 values to drive each motor directly)
            %convert to MSMS format
            motorPositions = [motorPositions(3);motorPositions(5);motorPositions(6);0;0;motorPositions(4);0;0;0;motorPositions(2);0;motorPositions(1)];
        case 12 %12 degrees of freedom from MSMS (convert to DEKA 6 degrees of freedom)
            %do nothing
        otherwise %not a valid input for position
            motorPositions = zeros(12,1);   %zero hand
    end
%% get motor movements
    if rightHand
        motorPositions(10) = -motorPositions(10); %invert wrist flex
    end
    [rot, flex] = wristPositionAdjust(motorPositions(12),motorPositions(10),[45,75],neutral,1);
    motorPositions = MSMS2DEKA_wristp(motorPositions,neutral);
    motorPositions(1) = rot;
    motorPositions(2) = flex;
%% read sensors (sensors pulled before movement occured)
    [frameCount, sensorData] = lkmex('sensor');
%% move hand
    lkmex('command',motorPositions);
%% adjust final output
    sensorOut = sensorData;
    motorOut = [motorPositions(1:4);0;0;motorPositions(5:6)];
end