function Luke = MSMS2DEKA_wristp(MSMS,varargin)
%convert from 12 degrees of freedom in MSMS land to 6 degrees of freedom in
%DEKA land

% MSMS = thumb,index,middle,ring,little,thumbint,indexint,ringint,littleint,wristpitch,wristyaw,wristroll];
% Luke = [wristroll,wristpitch,thumbadd,thumbflex,indexflex,mid/rin/lit flex];

Luke = zeros(6,1);
LukeLims = [...        % motor limits from Luke
    0,1023;...       % 1 wristroll
     0,1023;...        % 2 wristpitch
      +0,1023;...        % 3 thumbflex (actual limits 0 90) %dk 10/2/17 for RH DEKA
      -1023,-512;...        % 4 thumbabb (actual limits 0 100) %dk 10/2/17 for RH DEKA
      +0,1023;...        % 5 indexflex %dk 10/2/17 for RH DEKA
      +0,1023;...        % 6 mid/rin/lit flex   %dk 10/2/17 for RH DEKA
    ];

if nargin > 1 && ~isempty(varargin{1})
    [a,b] = size(varargin{1});
    if b>a
        LukeNeut = varargin{1}';
    else
        LukeNeut = varargin{1};
    end
    LukeNeut = (LukeNeut + ones(6,1))/2;
    LukeNeut([1 3:6]) = LukeLims([1 3:6],1) + (LukeNeut([1 3:6]).*(LukeLims([1 3:6],2)-LukeLims([1 3:6],1)));
%    Funky logic needed to handle the fact that 1023 = wrist extended and 0 = wrist flexed
    LukeNeut(2) = LukeLims(2,2) - (LukeNeut(2).*(LukeLims(2,2)-LukeLims(2,1)));
else
    LukeNeut = [...        % neutral positions
          +300;...   
          +511;...   
          +307;...      %dk 10/2/17 for RH DEKA
          -921;...    %dk 10/2/17 for RH DEKA
          +307;...     %dk 10/2/17 for RH DEKA
          +307;...    %dk 10/2/17 for RH DEKA
        ]; 
end

MSMS2LukeIdx = [...    % look up table for corresponding Luke index 
    3,nan;...            % MSMS thumb = Luke thumb/thumbint
    5,nan;...          % MSMS index = Luke index
    6,nan;...          % MSMS middle = Luke mid/rin/lit
    nan,nan;...        % MSMS ring = Luke mid/rin/lit
    nan,nan;...        % MSMS little = Luke mid/rin/lit
    4,nan;...        % MSMS thumbint = []
    nan,nan;...        % MSMS indexint = []
    nan,nan;...        % MSMS ringint = []
    nan,nan;...        % MSMS littleint = []
    2,nan;...          % MSMS wrist pitch = Luke wrist pitch
    nan,nan;...        % MSMS wrist yaw = []
    1,nan;...          % MSMS wrist roll = Luke wrist roll
    ]; 
    
% interpolation y = y0+ (y1-y0)*(x-x0)/(x1-x0) 
% we need to have two zones of interpolation, one for flexion and one for
% extension based on neutral position and motor limits.

for k=1:12   
    Lukeidx = MSMS2LukeIdx(k,:);        
    if ~all(isnan(Lukeidx))
        Lukeidx(isnan(Lukeidx)) = [];
        if MSMS(k)<0 % y0 = vrelims(idx, 1), y1 = vreneutralpos, x0 = -1, x1 = 0
            Luke(Lukeidx) = LukeLims(Lukeidx,1) + (LukeNeut(Lukeidx) - LukeLims(Lukeidx,1))*(MSMS(k)+1);
        else  % positive interp; y0 = vreneutralpos, y1 = vrelims(idx, 2), x0 = 0, x1 = 1
            Luke(Lukeidx) = LukeNeut(Lukeidx)  + (LukeLims(Lukeidx,2) - LukeNeut(Lukeidx))*(MSMS(k));
        end
    end
end
% k = 12;
% Lukeidx = MSMS2LukeIdx(k,:);        
% if ~all(isnan(Lukeidx))
%     Lukeidx(isnan(Lukeidx)) = [];
%     if MSMS(k)<0 % y0 = vrelims(idx, 1), y1 = vreneutralpos, x0 = -1, x1 = 0
%         Luke(Lukeidx) = (LukeLims(Lukeidx,1) + (LukeNeut(Lukeidx) - LukeLims(Lukeidx,1))*(MSMS(k)+1))*2.666;
%     else  % positive interp; y0 = vreneutralpos, y1 = vrelims(idx, 2), x0 = 0, x1 = 1
%         Luke(Lukeidx) = LukeNeut(Lukeidx)  + (LukeLims(Lukeidx,2) - LukeNeut(Lukeidx))*(MSMS(k))*.375;
%     end
% end

