function [Freq, Amp, varargout] = TASKASensors2Stim(TASKASensorsIR, TASKASensorsBAR,TASKASensorLabels,StimCell,varargin)
% Converts TASKA Sensor Values into Stimulation Frequency using various
% encoding algorithms

% TASKASensors.IR = [indx; indx; mid; thumb]
% TASKASensors.baro = [indx; indx; mid; thumb]

% Normalize sensor values and add ceiling (map 0 -> 1).

% SENSOR INDEXS ARE DEFINED AS:
% SS.TASKASensorLabels = {'index_ir';'index_bar';'middle_ir';'middle_bar';...
%     'thumb_ir';'thumb_bar';};
% 
% SS.TASKAMotorLabels = {}; %% USELESS ATM
%% Normalize and cat sensor values
TASKASensors = [TASKASensorsIR(2:4) TASKASensorsBAR(2:4)];
TASKASensors = TASKASensors - [17620,85500;18135,85628;14320,85320];
TASKASensors = TASKASensors/100; %ESS 2nd INI pilot with greg;
TASKASensors(TASKASensors>1) = 1;

%% Variable inputs
try
    stimThreshold = varargin{1};
    stimThreshold = stimThreshold(1:length(TASKASensors));
    TASKASensors = TASKASensors - stimThreshold;
catch
end
%% Calibration for sensor values
%positionoffset for proprioceptive feedback
persistent positionOffset;
if(isempty(positionOffset))
    positionOffset = 0;
end

%% Stim Settings
Region = StimCell{1};
IdxContact = strcmp(Region,TASKASensorLabels);
%IdxMotor = strcmp(Region,TASKAMotorLabels);
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});
ReceptorType = StimCell{2}; %to determine encoding algorithm

Freq = 0;   %base frequency
Amp = 0;    %base amplitude
%% Intensity Encoding
if any(IdxContact)          %if electrode is tied to a contact sensor...
    c0 = TASKASensors(IdxContact); 
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
                posTerm = 557.9706 * (c0*scale) - 554.7820 * (c1*scale);   %calculate position term
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
% elseif any(IdxMotor)        %if electrode is tied to a motor position sensor...
%     p0 = TASKAMotors(IdxMotor); p1 = PastTASKAMotors(IdxMotor,1); p2 = PastTASKAMotors(IdxMotor,2); p3 = PastTASKAMotors(IdxMotor,3); p4 = PastTASKAMotors(IdxMotor,4); p5 = PastTASKAMotors(IdxMotor,5);
%     dpdt0 = p0 - p1; dpdt1 = p1 - p2; dpdt2 = p2 - p3; dpdt3 = p3 - p4; %first derivative
%     dp2dt0 = p0 - p2; dp2dt1 = p1 - p3; %second derivative
%     IdxMotorToContact = getContactSensor(find(IdxMotor == 1)); %associated contact sensor for motor sensors
%     if(p0 > 0)
%         switch ReceptorType
%             case 'proprio'
%                 %% modified proprioception: stim on movement only when contact is present
%                 if(IdxMotorToContact ~= 0)  %valid idx for contact
%                     c0 = TASKASensors(IdxMotorToContact);    %sensor associated with movement
%                     if(c0 > 0)  %contact is occuring (without noise)
%                         Val = p0 - positionOffset;  %subtract offset (stim scales with position after contact is made)
%                         Val = Val*10;               %scale by random factor so that ranges from ~0 to ~1
%                         Freq = Val*(MaxFreq-MinFreq) + MinFreq;
%                         Amp = Val*(MaxAmp-MinAmp) + MinAmp;
%                     else
%                         positionOffset = p0;
%                     end
%                 end
%             case 'RA1'
%                 %% rapidly adapting type 1: stim with onset and offset only
%                 Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
%                 Val = abs(Val);             %direction doesn't matter
%                 Val(Val < .01) = 0;       %remove noise
%                 Freq = Val*(MaxFreq-MinFreq) + MinFreq;
%                 Amp = Val*(MaxAmp-MinAmp) + MinAmp;
%             case 'SA1'
%                 %% slowly adapting type 1: stim with steadystate and onset
%                 Val = (dcdt0 + dcdt1) * 10; %constant factor to increase response
%                 Val(Val < .01) = 0;       %remove noise (only positive values)
%                 Freq = Val*(MaxFreq-MinFreq) + MinFreq;
%                 Amp = Val*(MaxAmp-MinAmp) + MinAmp;
%             otherwise
%                 %% unscaled linear fit between min and max values (never reaches true max)
%                 Val = p0;
%                 Freq = Val*(MaxFreq-MinFreq) + MinFreq;
%                 Amp = Val*(MaxAmp-MinAmp) + MinAmp;
%        end
%    end
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
            Idx = 12;
        case 8  %thumb_ABD --> thumb_medial     (not certain)
            Idx = 11;
    end
return