function [ts,wf] = findSpikesRealTime2(data,thresh)

% Creates timestamps for positive threshold crossings that are separated by
% at least 30 samples (1 ms). The 1st valid waveform is returned.
%
% Version Date:  20150608
% Author:  Tyler Davis

data=data(:);
if thresh>=0
    ts1=[false;diff(data>thresh)==1];
else
    ts1=[false;diff(data<thresh)==1];
end
ts=find(ts1);
ts([false;diff(ts)<30]) = [];

wf=nan(48,1);
if ~isempty(ts)
    ts_idx = find(ts>15&ts<(length(data)-32),1,'first');
    if ~isempty(ts_idx) 
        wf = data((-15:32)+ts(ts_idx));        
    end
end





 
 
 