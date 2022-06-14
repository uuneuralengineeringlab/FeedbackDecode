function [Freq, Amp, varargout] = TASKASensors2Stim_INI_encodes(b,StimCell,varargin)
% Converts TASKA Sensor Values into Stimulation Frequency using various
% encoding algorithms

%% Stim Settings
Region = StimCell{1};
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});
ReceptorType = StimCell{2}; %to determine encoding algorithm

Freq = 0;   %base frequency
Amp = 0;    %base amplitude
%% Intensity Encoding

% b = taskaHand(TASKAbuffer(1,:,indices),params);

switch Region
    case 'thumb_distal'
        outputchannel = 1;
    case 'index_distal'
        outputchannel = 2;
    case 'middle_distal'
        outputchannel = 3;
end
%%
b(1,15,:) ./ [2.5 1 1]';
Val = b(1,15,outputchannel);
Freq = Val*(MaxFreq-MinFreq) + MinFreq;


% stay within bounds
if(Freq < 0)
    Freq = 0;
end

if(Freq == MinFreq)
    Freq = 0;
end
if(Freq > MaxFreq)
    Freq = MaxFreq;
end

return