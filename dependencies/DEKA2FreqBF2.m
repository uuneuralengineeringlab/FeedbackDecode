function [Freq, varargout] = DEKA2FreqBF2(DEKASensors,DEKASensorLabels,DEKAMotors,DEKAMotorLabels,StimCell,varargin)

% SS.DEKASensorLabels = {'index_medial';'index_distal';'middle_distal';'ring_distal';...
%     'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
%     'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};
% 
% SS.DEKAMotorLabels = {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
%     'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD'};
% 

persistent pastContantValue1;
if(isempty(pastContantValue1))
    pastContantValue1 = zeros(1,200);
end
persistent pastContactValue2;
if(isempty(pastContactValue2))
    pastContactValue2 = zeros(1,200);
end
persistent pastContactValue3;
if(isempty(pastContactValue3))
    pastContactValue3 = zeros(1,200);
end
persistent pastContactValue4;
if(isempty(pastContactValue4))
    pastContactValue4 = zeros(1,200);
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
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});
ReceptorType = StimCell{2};

IdxContact = strcmp(Region,DEKASensorLabels);
IdxMotor = strcmp(Region,DEKAMotorLabels);

Freq = 0;


if any(IdxContact)
    %Calculate normal value
    NormVal = DEKASensors(IdxContact)/(255-BLineInterp(IdxContact));
    varargout{1} = NormVal;
    %biofidelic stuff
    if(~isempty(ReceptorType))
        %if receptor type
        if (strcmp(ReceptorType,'RA1') || strcmp(ReceptorType,'SA1')) %if an RA1 or SA1, determine rate of change
            rateOfChange = NormVal - pastContantValue1(index); %finite difference 1
            rateOfChange2 = pastContantValue1(index) - pastContactValue2(index); %finite difference 2
            rateOfChange = (rateOfChange + rateOfChange2) * 10; %constant factor to increase response
            rateOfChange = rateOfChange(rateOfChange > .01);    %remove noise
            pastContactValue2(index) = pastContantValue1(index);
            pastContantValue1(index) = NormVal;
        elseif (strcmp(ReceptorType,'aRA') || strcmp(ReceptorType,'aSA')) %archived version
            rateOfChange = NormVal - pastContantValue1(index); %finite difference
            rateOfChange = rateOfChange * 100; %constant factor to increase response
            pastContantValue1(index) = NormVal;
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
        if (strcmp(ReceptorType,'bio'))
            pos0 = NormVal * 3; %scale sensor value (which is 0 to 1) to go from 0 to 3 mm
            pos1 = pastContantValue1(index); pos2 = pastContactValue2(index); pos3 = pastContactValue3(index); pos4 = pastContactValue4(index);  %get positions
            vel0 = abs(pos0 - pos1); vel1 = abs(pos1 - pos2); vel2 = abs(pos2 - pos3); vel3 = abs(pos3 - pos4);     %get velocities
            acc0 = abs(pos0 - pos2); acc1 = abs(pos1 - pos3);     %get accelerations
            posTerm = 557.9706 * pos0 -554.7820 * pos1;   %calculate position term
            velTerm = 1559.4952 * vel0 - 359.7767 * vel1 - 109.1068*vel2;   %calculate velocity term
            accTerm = 364.3545 * acc0 + 169.9743 * acc1;  %calculate acceleration term
            intercept = -3.1163;
            Freq = posTerm + velTerm + accTerm + intercept;   %determine firing rate (Chicago model, without zero-mean guassian noise)
            if Freq<0
                Freq=0;
            end
            pastContactValue4(index) = pastContactValue3(index);    %update past values
            pastContactValue3(index) = pastContactValue2(index);
            pastContactValue2(index) = pastContantValue1(index);
            pastContantValue1(index) = pos0;
        else
            Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;
        end
    end
elseif any(IdxMotor)
    NormVal = DEKAMotors(IdxMotor)/255; %normalized value from 0 to 1
    NormVal(NormVal<0) = 0;     %non-negative
    if(~isempty(ReceptorType))  %if receptor type
        if (strcmp(ReceptorType,'proprio'))
            %nothing
        end
    end
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;   
    end
end


function valout = setLimit(valin,lim)

valout = min(max(valin,lim(1)),lim(2)); 

