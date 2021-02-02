function [ts,spikerem,wf] = findSpikesRealTime(data,thresh,res,spikerem)

% Creates timestamps (ts) for every threshold crossing above or below
% thresh. Also returns the first 48 sample waveform snippet (wf).
% spikerem should be initialized to Inf outside this function.
%
% Version Date:  20140507 
% Author:  Tyler Davis, smw
%
% [ts,spikerem,wf] = findSpikesRealTime(data,-100,spikerem)

data = data(:);
if thresh>=0
    t1=(data>thresh);
else
    t1=(data<thresh);
end
t2=find(t1);
t3=diff(t2);
t4=find(t3>res);
   
ts = []; wf = [];
if ~isempty(t2)
    if (spikerem+t2(1))<res
        ts = t2(t4+1);
    else
        ts = t2([1;t4+1]);
    end
    if ~isempty(ts)
%         if nargout==3
%             idxs = (-10:37)+ts(1);
%             if ~any(idxs>length(data)|idxs<1)
%                 wf = data(idxs);
%             else % waveform snippet on the edge of window, pad w zeros
%                 wf = zeros(48, 1);
%                 if idxs(1) < 1
%                     tempwf = data(idxs(idxs>=1));
%                     wf(-idxs(1)+2:end) = tempwf;
%                 end
%                 if idxs(end) > length(data)
%                     tempwf = data(idxs(idxs <= length(data)));
%                     wf(1:length(tempwf)) = tempwf;
%                 end
%             end
%         end
        spikerem = length(data)-ts(end);
    else
        spikerem = Inf;
    end
end



 
 
 
 