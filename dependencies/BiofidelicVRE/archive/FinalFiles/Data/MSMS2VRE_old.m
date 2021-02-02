function VRE = MSMS2VRE(MSMS)

% MSMS = thumb,index,middle,ring,little,thumbint,indexint,ringint,littleint,wristpitch,wristyaw,wristroll];
% VRE = [wristroll,wristpitch,thumb,thumbint,

VRE = zeros(12,1);

VRElims = [  ...        % motor limits from VRE. in general ABD = abduction, MCP = flexion
    1.57, -1.57   ;...     % 1 wrist_PRO (pronate)
    -0.26,  0.79;...    % 2 wrist_UDEV (ulnar deviation)
    -1,     1   ;...    % 3 wrist_FLEX 
    0,      2.1 ;...    % 4 thumb_ABD (abduction)
    0,      1   ;...    % 5 thumb_MCP (metacarpal)
    0,      1   ;...    % 6 thumb_PIP (proximal interphlangeal)
    0,      1.3 ;...    % 7 thumb_DIP (distal interphlangeal)
    0,      0.34;...    % 8 index_ABD (abduction)
    0,      1.6 ;...    % 9 index_MCP (metacarpal)
    0,      1.6 ;...    % 10 middle_MCP (metacarpal)
    0,      1.6 ;...    % 11 ring_MCP (metacarpal)
    0,      0.34;...    % 12 pinky_ABD (abduction)
    0,      1.6 ....    % 13 pinky_MCP (metacarpal)
    ];

VRENeutralPos = [ ... % neutral positions
    0;...   % 1 wrist_PRO (pronate)
    0;...   % 2 wrist_UDEV (ulnar deviation)
    0;...       % 3 wrist_FLEX 
    1.5;...    % 4 thumb_ABD (abduction)
    0.5;...     % 5 thumb_MCP (metacarpal)
    0.5;...     % 6 thumb_PIP (proximal interphlangeal)
    0.2;...     % 7 thumb_DIP (distal interphlangeal)
    0.15;...    % 8 index_ABD (abduction)
    0.4;...     % 9 index_MCP (metacarpal)
    0.4;...     % 10 middle_MCP (metacarpal)
    0.4;...     % 11 ring_MCP (metacarpal)
    0.15;...    % 12 pinky_ABD (abduction)
    0.4];       % 13 pinky_MCP (metacarpal)

MSMSVREindx = [ ... % look up table for corresponding VRE index 
    5;... % 1 thumb flex = 4 thumb_ABD
    9;... % 2 index flex = 9 index_mcp
    10; ... % 3 middle flex = 10middle_mcp
    11; ... % 4 ring flex = 11 ring_mcp
    13; ... % 5 little flex = 13 pinky_mcp
    4; ... % 6 thumb int = 5 thumb_mcp
    8;...  % 7 index int = 8 index_abd
    12; ... % 8 ring int = 12 pinky_abd (VRE pinky and thumb tied together)
    12; ... % 9 pinky int = 12 pinky_abd
    3; ... % 10 wrist pitch = 3 wrist_flex
    2; ... % 11 wrist yaw = 2 wrist_udev
    1]; ... % 12 wrist roll = 1 wrist_pro
    
% interpolation y = y0+ (y1-y0)*(x-x0)/(x1-x0) 
% we need to have two zones of interpolation, one for flexion and one for
% extension based on neutral position and motor limits.

for k = 1:12
    if k ~=1
        VREidx = MSMSVREindx(k);% look up VRE index
    else
        VREidx = [MSMSVREindx(k), 6,7];%
    end
   if MSMS(k) < 0 % y0 = vrelims(idx, 1), y1 = vreneutralpos, x0 = -1, x1 = 0
       VRE(VREidx) = VRElims(VREidx,1) + (VRENeutralPos(VREidx) - VRElims(VREidx,1))*(MSMS(k)+1);
   else  % positive interp; y0 = vreneutralpos, y1 = vrelims(idx, 2), x0 = 0, x1 = 1
       VRE(VREidx) = VRENeutralPos(VREidx)  + (VRElims(VREidx,2) - VRENeutralPos(VREidx))*(MSMS(k));
   end
end

% VRE(6:7) = [0.5;0.2]; % fix values for thumb_PIP and thumb_DIP since these don't map to MSMS

 
 % MSMS = zeros(1,12);
% VRESensor.motor_limit(1,:)
% scale = diff([-1.57,0])/2;
% offset = scale;
% VRE(1) = MSMS(12)*scale-offset;
% 
% scale1 = (0-0.4);
% scale2 = (0.4-1.6);
% center = 0.4;
% 
% offset = scale;
% if MSMS(2)<=0
%     VRE(9) = (1-MSMS(2))*scale1-center;
% else
%     VRE(9) = MSMS(2)*scale2-center;
% end
% 
% MSMSlims = [ ...
%     -1, 1;...   % 1 Thumb flex
%     -1, 1;...   % 2 Index flex
%     -1, 1;...   % 3 Middle flex
%     -1, 1;...   % 4 Ring flex
%     -1, 1;...   % 5 Little flex
%     0, 1;...    % 6 Thumb intrinsic
%     0, 1;...    % 7 Index intrinsic
%     0, 1;...    % 8 Ring intrinsic
%     0, 1;...    % 9 Little intrinsic
%     -1, 1;...   % 10 wrist pitch (flex)
%     -1, 1;...   % 11 wrist yaw (deviation)
%     -1, 1;...   % 12 wrist roll (pronation)
%     ];
