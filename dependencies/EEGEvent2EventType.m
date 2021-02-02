function eventType = EEGEvent2EventType(digEvent)
% eventType = EEGEvent2EventType(digEvent) Converts events from the NIP
% 'digin' call to a character event type for use in FeedbackDecode. See
% targ2EEGEvent for relevant information on event encoding.
% 
% Inputs:
%     digEvent: single struct from xippmex 'digin' call.
%     
% Outputs:
%     eventType: char array of event type name
%     
% Written by: Michael Paskett
% Created: 3/17/20
% Last Modified: 3/17/20


eventNum = digEvent.parallel;

if (100 <= eventNum) && (230 >= eventNum)
    eventType = 'BuzzOn';
elseif (240 <= eventNum) && (249 >= eventNum)
    eventType = 'BuzzOff';
elseif (10 <= eventNum) && (19 >= eventNum)
    eventType = 'TargOn';
elseif (20 <= eventNum) && (29 >= eventNum)
    eventType = 'TargOff';
elseif (30 <= eventNum) && (39 >= eventNum)
    eventType = 'ButtonPressEEGTrigger';
elseif (40 <= eventNum) && (49 >= eventNum)
    eventType = 'ButtonReleaseEEGTrigger';
elseif (digEvent.reason == 2) && (digEvent.sma1 == 32767)
    eventType = 'ButtonPressRawNIP';
elseif (digEvent.reason == 2) && (digEvent.sma1 == 0)
    eventType = 'ButtonReleaseRawNIP';
else
    eventType = 'Unknown';
end

end