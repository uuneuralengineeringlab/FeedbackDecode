function nextTime = updateTimeAdaptTrain(currTime,previousErrors)

%This functions determines when is best to update the KF models that are
%currently being used for decoding. Eventually it will be based on the time
%since updating began (or the number of trials of each movement already
%performed) and the most recent errors.

nextTime = currTime + 1e3;