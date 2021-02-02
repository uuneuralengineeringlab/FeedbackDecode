function TrialStruct = parseKEF(fname)
% function that parses events from KEF (kalman events file) into a
% structure called "trialStruct" 
% input:
%   fname: -string, full file path of .kef file
% output: 
%   TrialStruct = 
%   1 x numTrials struct array with fields:
%     TargOnTS: nip time stamp of the beginning of the trial
%     TrialTS: Nip time stamp of the end of the trial (targot off +
%     finalization period)
%     MvntMat: 12x 4 matrix containing training movement parameters.
%     (amplitude, delay, rise time, hold time for each DOF)
% 
% SMW and TD, 6/17/2015
    
fid = fopen(fname);
TrialParams = regexp(fscanf(fid,'%c'),'\r\n','split')';
TrialStruct = repmat(struct('TargOnTS',[],'TrialTS',[],'MvntMat',[]),1,size(TrialParams,1));
for k=1:length(TrialParams)
    SS = struct('TargOnTS',[],'TrialTS',[],'MvntMat',[]);
    eval(TrialParams{k});
    TrialStruct(k) = SS;
end
idx = cellfun(@isempty,{TrialStruct.TargOnTS}) | cellfun(@isempty,{TrialStruct.TrialTS}) | cellfun(@isempty,{TrialStruct.MvntMat});
TrialStruct(idx) = [];

