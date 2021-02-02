function [Freq, Amp, varargout] = analogDEKA2Stim(analogSensors,DEKAMotors,PastDEKAMotors,DEKAMotorLabels,StimCell,varargin)
% Converts DEKA Sensor Values into Stimulation Frequency using various
% encoding algorithms

% SENSOR INDEXS ARE DEFINED AS:
% SS.DEKASensorLabels = {'index_medial';'index_distal';'middle_distal';'ring_distal';...
%     'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
%     'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};
% 
% SS.DEKAMotorLabels = {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
%     'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD'};

%% set up variables
analogSensorLabels = {'thumb_distal';'index_distal';'middle_distal';'ring_distal'};

currentSensors = analogSensors(:,1);
pastSensors = analogSensors(:,2:6);

%% Calibration for sensor values
%positionoffset for proprioceptive feedback
persistent positionOffset;
if(isempty(positionOffset))
    positionOffset = 0;
end
%set limits for each motor sensor
DEKAMotors(1) = setLimit(DEKAMotors(1)/7680,[-1,1]); 
DEKAMotors(2) = setLimit(DEKAMotors(2)/3520,[-1,1]); 
DEKAMotors(3) = setLimit(DEKAMotors(3)/5760,[0,1]); 
DEKAMotors(4) = setLimit(DEKAMotors(4)/5760,[0,1]); 
DEKAMotors(7) = setLimit(DEKAMotors(7)/6400,[0,1]); 
DEKAMotors(8) = setLimit(DEKAMotors(8)/5760,[0,1]); 
%set limits for each past motor values
for ii = 1:5
    PastDEKAMotors(1,ii) = setLimit(PastDEKAMotors(1,ii)/7680,[-1,1]); 
    PastDEKAMotors(2,ii) = setLimit(PastDEKAMotors(2,ii)/3520,[-1,1]); 
    PastDEKAMotors(3,ii) = setLimit(PastDEKAMotors(3,ii)/5760,[0,1]); 
    PastDEKAMotors(4,ii) = setLimit(PastDEKAMotors(4,ii)/5760,[0,1]); 
    PastDEKAMotors(7,ii) = setLimit(PastDEKAMotors(7,ii)/6400,[0,1]); 
    PastDEKAMotors(8,ii) = setLimit(PastDEKAMotors(8,ii)/5760,[0,1]);
end
%% Stim Settings
Region = StimCell{1};
IdxContact = strcmp(Region,analogSensorLabels);
IdxMotor = strcmp(Region,DEKAMotorLabels);
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});
ReceptorType = StimCell{2}; %to determine encoding algorithm

Freq = 0;   %base frequency
Amp = 0;    %base amplitude
%% Intensity Encoding
if any(IdxContact)          %if electrode is tied to a contact sensor...
    c0 = currentSensors(IdxContact); c1 = pastSensors(IdxContact,1); c2 = pastSensors(IdxContact,2); c3 = pastSensors(IdxContact,3);  c4 = pastSensors(IdxContact,4);  c5 = pastSensors(IdxContact,5);
    dcdt0 = c0 - c1; dcdt1 = c1 - c2; dcdt2 = c2 - c3; dcdt3 = c3 - c4; %first derivative
    dc2dt0 = c0 - c2; dc2dt1 = c1 - c3; %second derivative
    if(c0 > 0)
        switch ReceptorType
            case 'RA1'
                %% rapidly adapting type 1: stim with onset and offset only
                Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
                Val = abs(Val);             %direction doesn't matter
                Val(Val < .01) = 0;       %remove noise
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
            case 'SA1'
                %% slowly adapting type 1: stim with steadystate and onset
                Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
                Val(Val < .01) = 0;       %remove noise
                Val = Val + c0;
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
            case 'bio freq'
                %% University of Chicago Biofidelic Model: Physiological frequency encoding with no amplitude encoding
                scale = 3;  %0-3 (Univ Chicago trained on 3mm indentation)
                posTerm = 557.9706 * (c0*scale) -554.7820 * (c1*scale);   %calculate position term
                velTerm = (1559.4952 * abs(dcdt0*scale)) - (359.7767 * abs(dcdt1*scale)) - (109.1068 * abs(dcdt2*scale));   %calculate velocity term
                accTerm = (364.3545 * abs(dc2dt0*scale)) + (169.9743 * abs(dc2dt1*scale));  %calculate acceleration term
                intercept = -3.1163;
                Freq = posTerm + velTerm + accTerm + intercept;   %determine firing rate (Chicago model, without zero-mean guassian noise)
                Freq(Freq < 0) = 0; %no negative freq
                Amp = MaxAmp;
            case 'bio amp'
                scale = 3;  %0-3 (Univ Chicago trained on 3mm indentation)
                posTerm = 181.7049 * (c0*scale) - 164.2083 * (c1*scale);   %calculate position term
                velTerm = (527.9869 * abs(dcdt0*scale)) + (292.2716 * abs(dcdt1*scale));   %calculate velocity term
                accTerm = (6.3115 * abs(dc2dt0*scale)) + (21.9826 * abs(dc2dt1*scale));  %calculate acceleration term
                intercept = -2.0783;
                Amp = posTerm + velTerm + accTerm + intercept;   %determine population active (Chicago model, without zero-mean guassian noise)
                Amp(Amp < 0) = 0; %no negative amp
                Freq = MaxFreq;
            case 'scaled'
                %% scaled linear fit between min and max values
                Val = c0*2;
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
            otherwise
                %% unscaled linear fit between min and max values (never reaches true max)
                Val = c0;
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
        end
    end
elseif any(IdxMotor)        %if electrode is tied to a motor position sensor...
    p0 = DEKAMotors(IdxMotor); p1 = PastDEKAMotors(IdxMotor,1); p2 = PastDEKAMotors(IdxMotor,2); p3 = PastDEKAMotors(IdxMotor,3); p4 = PastDEKAMotors(IdxMotor,4); p5 = PastDEKAMotors(IdxMotor,5);
    dpdt0 = p0 - p1; dpdt1 = p1 - p2; dpdt2 = p2 - p3; dpdt3 = p3 - p4; %first derivative
    dp2dt0 = p0 - p2; dp2dt1 = p1 - p3; %second derivative
    IdxMotorToContact = getContactSensor(find(IdxMotor == 1)); %associated contact sensor for motor sensors
    if(p0 > 0)
        switch ReceptorType
            case 'proprio'
                %% modified proprioception: stim on movement only when contact is present
                if(IdxMotorToContact ~= 0)  %valid idx for contact
                    c0 = currentSensors(IdxMotorToContact);    %sensor associated with movement
                    if(c0 > 0)  %contact is occuring (without noise)
                        Val = p0 - positionOffset;  %subtract offset (stim scales with position after contact is made)
                        Val = Val*10;               %scale by random factor so that ranges from ~0 to ~1
                        Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                        Amp = Val*(MaxAmp-MinAmp) + MinAmp;
                    else
                        positionOffset = p0;
                    end
                end
            case 'RA1'
                %% rapidly adapting type 1: stim with onset and offset only
                Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
                Val = abs(Val);             %direction doesn't matter
                Val(Val < .01) = 0;       %remove noise
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
            case 'SA1'
                %% slowly adapting type 1: stim with steadystate and onset
                Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
                Val(Val < .01) = 0;       %remove noise (only positive values)
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
            otherwise
                %% unscaled linear fit between min and max values (never reaches true max)
                Val = p0;
                Freq = Val*(MaxFreq-MinFreq) + MinFreq;
                Amp = Val*(MaxAmp-MinAmp) + MinAmp;
        end
    end
end
% stay within bounds
if(Amp < 0)
    Amp = 0;
end
if(Freq < 0)
    Freq = 0;
end
if(Amp > MaxAmp)
    Amp = MaxAmp;
end
if(Freq > MaxFreq)
    Freq = MaxFreq;
end

function valout = setLimit(valin,lim)
    valout = min(max(valin,lim(1)),lim(2));
return

function Idx = getContactSensor(IdxMotor)
    Idx = 0;
    switch IdxMotor
        case 1  %wrist_PRO --> NONE 
        case 2  %wrist_FLEX --> NONE
        case 3  %index_MCP --> index_distal
            Idx = 2;
        case 4  %middle_MCP --> middle_distal
            Idx = 3;
        case 5  %thumbraw_ABD --> NONE
        case 6  %thumbraw_MCP --> NONE
        case 7  %thumb_MCP --> thumb_distal
            Idx = 1;
        case 8  %thumb_ABD --> thumb_medial     (not certain)
    end
return