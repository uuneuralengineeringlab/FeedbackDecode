function [TrainX, TrainZ, TestX, TestZ, TrainKDFTimes, TestKDFTimes, TrialStruct] = splitTrainingData(KefFname,KdfFname,varargin)
% function that parses trainind data from KDF file based on KalmanMvnts and
% KalmanGain.  The output will be a subset of kinematics (subX) and
% features (subZ) corresponding to the desired movements and direction.
% The first trial of each block is discarded (as of 8/8/15).  If there are
% no trials recorded in the KEF file, all data of the desired movements (or
% all movements if not specified) will be returned.
% note: if combo movements are performed, any combo containing a desired DoF will
% be included in the output data (as in there is no way to deselect combo
% movements if any DoF contained in the combo is part of the Kalman movment
% list
% inputs:
%   KEFfname - string, full path for .kef filename
%   KDFfname - string, full path for .kdf filename
%   KalmanMvnts (optional) - numSelectedDOF x 1, vector of selected DOFs
%       (e.g., if thumb, index, and wrist are selected, KalmanMvnts =
%       [1,2,10]) Default KalmanMvnts = 1:12 (all DOF);
%   KalmanGain (optional) - numSelectedDOF x 2, matrix of gains for
%       flexion and extensions in each DOF.  First column is felxion, second
%       column is extension.  (e.g. if thumb flexion, index flexion AND
%       extension, and wrist extension are desired, KalmanGain = [1,0;1,1;0,1]
%       default KalmanGain = ones(12,2) (all directions of all movements).
%   SelectedInd (optional) - numChans x 1, vector of selected indicies for
%       feature data.  Default SelectedInd = 1:numIdx (all indx)
%   nTrials- integer, number of trials to select for testing /training
%   sets.  e.g. nTrials = 4 grab 4 testing and 4 training trials from each training set
%   inclComboFlag - binary, set to 1 to include combos movements, e.g. grasp (default), 0 to exclude
%   combo movements (e.g. grasp
% outputs:
%   TrainX - numSelectedDof x numSubSamples, Kinematics training data
%   (first n trials)
%   TrainZ - numSelectedInd x numSubSamples, Feature training data
%   TestX - numSelectedDof x numSubSamples, Kinematics training data
%   (first n trials)
%   TestZ - numSelectedInd x numSubSamples, Feature training data
%   KDFTimes - NIP time stanmps
%
% example call: [trainX, TrainZ, testX, testZ] = parseTrainingData(SS.KEFTrainFile, SS.KDFTrainFile, SS.KalmanMvnts, SS.KalmanGain, SS.KalmanIdx, ntrials);
% SMW  8/2016.  Note this is not robust code and will crash under
% circumstances where nTrials > (number of actual trials -1)/2

TrialStruct = parseKEF(KefFname); % read kef file
[X,Z,T,K,KDFTimes] = readKDF(KdfFname); % read KDF file

% init
KalmanMvnts = (1:12);
KalmanGain = ones(12,2);
SelectedInd = 1:size(Z,1);
nTrials = 2;
inclComboFlag = 1; % default, used combination movements

% parse optional inputs
if nargin > 2
    KalmanMvnts = varargin{1};
end
if nargin > 3
    KalmanGain = varargin{2};
end
if nargin > 4
    SelectedInd = varargin{3};
    if isempty(SelectedInd) SelectedInd = 1:size(Z,1); end
end
if nargin > 5
    nTrials = varargin{4};
    if isempty(nTrials) nTrials = 2; end
end
if nargin > 6
   inclComboFlag = varargin{5};
    if isempty(nTrials)inclComboFlags = 1; end
end

TrainX = zeros(length(KalmanMvnts), floor(size(X,2)/2));
TrainZ = zeros(length(SelectedInd),  floor(size(X,2)/2));
TestX = zeros(length(KalmanMvnts),  floor(size(X,2)/2));
TestZ = zeros(length(SelectedInd),  floor(size(X,2)/2));
TrainKDFTimes = zeros(floor(size(KDFTimes, 2)/2),1);
TestKDFTimes = zeros(floor(size(KDFTimes, 2)/2),1);

% step through Trial struct, add data to subX and subZ if it meets criteria
curTrainSubInd = [0,0];
curTestSubInd = [0,0];
lastMvnt = zeros(12,4);
skipTrialIdx = [];
trainCount = 0;
testCount = 0;
curMvntCount = 0;
if ~isempty(TrialStruct)
    for k = 1:length(TrialStruct)
        curMvntIdx = find(TrialStruct(k).MvntMat(:,1), 1);
        if (inclComboFlag && sum(abs(TrialStruct(k).MvntMat(:,1)))>1) || sum(abs(TrialStruct(k).MvntMat(:,1)))<=1
            if ~isempty(curMvntIdx) && ~any(TrialStruct(k).MvntMat(:) ~= lastMvnt(:)) %look for desired movements, and throw out first trial
                curMvntCount = curMvntCount+1;
                if ismember(curMvntIdx,KalmanMvnts)
                    curMvntSgn = TrialStruct(k).MvntMat(curMvntIdx,1)>0;
                    
                    if curMvntCount <= nTrials % det training data (first nTrials)
                        if (curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,1)) % grab flex
                            curTrainKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                            curTrainSubInd(1) = curTrainSubInd(2)+1;
                            curTrainSubInd(2) = curTrainSubInd(1)+sum(curTrainKDFInd)-1;
                            TrainX(:,curTrainSubInd(1):curTrainSubInd(2)) = X(KalmanMvnts, curTrainKDFInd);
                            TrainZ(:,curTrainSubInd(1):curTrainSubInd(2)) = Z(SelectedInd, curTrainKDFInd);
                            TrainKDFTimes(curTrainSubInd(1):curTrainSubInd(2)) = KDFTimes(curTrainKDFInd);
                            
                        elseif (~curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,2)) % grab extend
                            curTrainKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                            curTrainSubInd(1) = curTrainSubInd(2)+1;
                            curTrainSubInd(2) = curTrainSubInd(1)+sum(curTrainKDFInd)-1;
                            TrainX(:,curTrainSubInd(1):curTrainSubInd(2)) = X(KalmanMvnts, curTrainKDFInd);
                            TrainZ(:,curTrainSubInd(1):curTrainSubInd(2)) = Z(SelectedInd, curTrainKDFInd);
                            TrainKDFTimes(curTrainSubInd(1):curTrainSubInd(2)) = KDFTimes(curTrainKDFInd);
                        end
                    elseif curMvntCount <= 2*nTrials % grab testing data (next nTrials)
                        if (curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,1)) % grab flex
                            curTestKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                            curTestSubInd(1) = curTestSubInd(2)+1;
                            curTestSubInd(2) = curTestSubInd(1)+sum(curTestKDFInd)-1;
                            TestX(:,curTestSubInd(1):curTestSubInd(2)) = X(KalmanMvnts, curTestKDFInd);
                            TestZ(:,curTestSubInd(1):curTestSubInd(2)) = Z(SelectedInd, curTestKDFInd);
                            TestKDFTimes(curTestSubInd(1):curTestSubInd(2)) = KDFTimes(curTestKDFInd);
                            
                        elseif (~curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,2)) % grab extend
                            curTestKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                            curTestSubInd(1) = curTestSubInd(2)+1;
                            curTestSubInd(2) = curTestSubInd(1)+sum(curTestKDFInd)-1;
                            TestX(:,curTestSubInd(1):curTestSubInd(2)) = X(KalmanMvnts, curTestKDFInd);
                            TestZ(:,curTestSubInd(1):curTestSubInd(2)) = Z(SelectedInd, curTestKDFInd);
                            TestKDFTimes(curTestSubInd(1):curTestSubInd(2)) = KDFTimes(curTestKDFInd);
                        end
                    end
                end
                
            else % the movement was not desired or was the first trial.  Reset counts
                curMvntCount = 0;
                skipTrialIdx = [skipTrialIdx, k];
            end
        end
        lastMvnt = TrialStruct(k).MvntMat;
    end
    
    % truncate output arrays
    if curTrainSubInd(2)
        TrainX(:, curTrainSubInd(2):end) = [];
        TrainZ(:, curTrainSubInd(2):end) = [];
        TrainKDFTimes(curTrainSubInd(2):end) = [];
        TestX(:, curTestSubInd(2):end) = [];
        TestZ(:, curTestSubInd(2):end) = [];
        TestKDFTimes(curTestSubInd(2):end) = [];
    end
    
    
end


TrialStruct(skipTrialIdx) = []; % remove first trials from TrialStruct

if isempty(TrialStruct) % if no trials written to KEF, or only "first trials" in data set (which are all thrown out), then return all the data
    subX = X(KalmanMvnts,:);
    subZ = Z(SelectedInd, :);
    subK = K(KalmanMvnts,:);
    subT = T(KalmanMvnts,:);
    subKDFTimes = KDFTimes;
end

% adding additional fields for autoPopStepwise and other functions
for k = 1:length(TrialStruct)
    TrialStruct(k).TrialStart = TrialStruct(k).TargOnTS;
    TrialStruct(k).TrialEnd = TrialStruct(k).TrialTS;
    MovementMat = zeros(12,2);
    flexIdx = TrialStruct(k).MvntMat(:,1)> 0;
    extIdx =  TrialStruct(k).MvntMat(:,1) < 0;
    MovementMat(flexIdx, 1) = 1;
    MovementMat(extIdx, 2) = 1;
    TrialStruct(k).MovementMat = logical(MovementMat);
    TrialStruct(k).TrainingOn = true;
end