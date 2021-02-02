function mu = muAdaptTrain(currTime,previousErrors)
    
%This function updates the adaptive step size for the adaptive training
%algorithm. Eventually, it should be based on how much time has passed
%since the beginning of adaptive training (or perhaps based on the trial
%number for a particular movement) as well as the previous errors from any
%DOFs.

    mu = .02;

end