function Amp = DEKA2AmpBF2(DEKASensors,DEKASensorLabels,DEKAMotors,DEKAMotorLabels,StimCell,varargin)

% SS.DEKASensorLabels = {'index_medial';'index_distal';'middle_distal';'ring_distal';...
%     'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
%     'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};
% 
% SS.DEKAMotorLabels = {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
%     'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD'};
% 

persistent pastvalues;
if(isempty(pastvalues))
    pastvalues = zeros(1,200);
end
persistent pastvalues2;
if(isempty(pastvalues2))
    pastvalues2 = zeros(1,200);
end

DEKAMotors(1) = setLimit(DEKAMotors(1)/7680,[-1,1]); 
DEKAMotors(2) = setLimit(DEKAMotors(2)/3520,[-1,1]); 
DEKAMotors(3) = setLimit(DEKAMotors(3)/5760,[0,1]); 
DEKAMotors(4) = setLimit(DEKAMotors(4)/5760,[0,1]); 
DEKAMotors(7) = setLimit(DEKAMotors(7)/6400,[0,1]); 
DEKAMotors(8) = setLimit(DEKAMotors(8)/5760,[0,1]); 

if nargin > 5
    BLine = varargin{1};
else
    BLine = zeros(13,2);
end
% BLine(1,:) = [0,0];
% BLine(2,:) = [5,33];
% BLine(3,:) = [0,0];
% BLine(4,:) = [0,0];
% BLine(5,:) = [0,0];
% BLine(6,:) = [0,0];
% BLine(7,:) = [0,0];
% BLine(8,:) = [0,0];
% BLine(9,:) = [0,0];
% BLine(10,:) = [0,0];
% BLine(11,:) = [0,0];
% BLine(12,:) = [0,0];
% BLine(13,:) = [0,0];

if nargin > 6
    fudge = varargin{2};
else
    fudge = 8;
end

BLineInterp(1) = (DEKAMotors(3)*diff(BLine(1,:)) + BLine(1,1)) + fudge; % index_medial
BLineInterp(2) = (DEKAMotors(3)*diff(BLine(2,:)) + BLine(2,1)) + fudge; % index_distal
BLineInterp(3) = (DEKAMotors(4)*diff(BLine(3,:)) + BLine(3,1)) + fudge; % middle_distal
BLineInterp(4) = (DEKAMotors(4)*diff(BLine(4,:)) + BLine(4,1)) + fudge; % ring_distal
BLineInterp(5) = (DEKAMotors(4)*diff(BLine(5,:)) + BLine(5,1)) + fudge; % pinky_distal
BLineInterp(6) = ((1-DEKAMotors(4))*diff(BLine(6,:)) + BLine(6,1)) + fudge; % palm_distal
BLineInterp(7) = ((1-DEKAMotors(4))*diff(BLine(7,:)) + BLine(7,1)) + fudge; % palm_prox
BLineInterp(8) = (DEKAMotors(2)*diff(BLine(8,:)) + BLine(8,1)) + fudge; % palm_side
BLineInterp(9) = (DEKAMotors(2)*diff(BLine(9,:)) + BLine(9,1)) + fudge; % palm_back
BLineInterp(10) = ((1-DEKAMotors(8))*diff(BLine(10,:)) + BLine(10,1)) + fudge; % thumb_ulnar
BLineInterp(11) = (DEKAMotors(8)*diff(BLine(11,:)) + BLine(11,1)) + fudge; % thumb_medial
BLineInterp(12) = (DEKAMotors(7)*diff(BLine(12,:)) + BLine(12,1)) + fudge; % thumb_distal
BLineInterp(13) = ((1-DEKAMotors(7))*diff(BLine(13,:)) + BLine(13,1)) + fudge; % thumb_dorsal

for i=1:13
    DEKASensors(i) = setLimit(DEKASensors(i) - BLineInterp(i),[0,Inf]);
end

index = str2double(StimCell{3});    %electrode number is index of past stored values
Region = StimCell{1};
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});
ReceptorType = StimCell{2};

IdxContact = strcmp(Region,DEKASensorLabels);
IdxMotor = strcmp(Region,DEKAMotorLabels);

Amp = 0;


if any(IdxContact)
    %Calculate normal value
    NormVal = DEKASensors(IdxContact)/(255-BLineInterp(IdxContact));
    %biofidelic stuff
    if(~isempty(ReceptorType))
        %if receptor type
        if (strcmp(ReceptorType,'RA1') || strcmp(ReceptorType,'SA1')) %if an RA1 or SA1, determine rate of change
            rateOfChange = NormVal - pastvalues(index); %finite difference 1
            rateOfChange2 = pastvalues(index) - pastvalues2(index); %finite difference 2
            rateOfChange = (rateOfChange + rateOfChange2) * 10; %constant factor to increase response
            rateOfChange = rateOfChange(rateOfChange > .01);    %remove noise
            pastvalues2(index) = pastvalues(index);
            pastvalues(index) = NormVal;
        elseif (strcmp(ReceptorType,'aRA') || strcmp(ReceptorType,'aSA')) %archived version
            rateOfChange = NormVal - pastvalues(index); %finite difference
            rateOfChange = rateOfChange * 100; %constant factor to increase response
            pastvalues(index) = NormVal;
        elseif (strcmp(ReceptorType,'scaled'))
            NormVal = NormVal*2;
        end
        if(strcmp(ReceptorType,'aRA') || strcmp(ReceptorType,'RA1'))  %if RA1 use rate of change
            NormVal = abs(rateOfChange);
        end
        if(strcmp(ReceptorType,'aSA') || strcmp(ReceptorType,'SA1'))  %if SA1 use rate of change plus contact
            if(rateOfChange > 0) %only positive, above noise level
                NormVal = NormVal + rateOfChange;
            end
        end
    end
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Amp = NormVal*(MaxAmp-MinAmp) + MinAmp;
    end
elseif any(IdxMotor)
    NormVal = DEKAMotors(IdxMotor)/255;
    NormVal(NormVal<0) = 0;
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Amp = NormVal*(MaxAmp-MinAmp) + MinAmp; 
    end
end


function valout = setLimit(valin,lim)

valout = min(max(valin,lim(1)),lim(2)); 

