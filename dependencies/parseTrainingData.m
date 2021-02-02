function [subX, subZ, subK, subT, subKDFTimes, TrialStruct] = parseTrainingData(KefFname,KdfFname,varargin)
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
%   Lag (optional).  subZ will be circshifted by Lag
% outputs:
%   subX - numSelectedDof x numSubSamples, Kinematics training data
%   subZ - numSelectedInd x numSubSamples, Feature training data
%   subK - numSelectedDof x numSubSamples, Kalman output training data
%   (usually 0's)
%   subT -  numSelectedDof x numSubSamples, Target training data
%
% example call: [subX, subZ] = parseTrainingData(SS.KEFTrainFile, SS.KDFTrainFile, SS.KalmanMvnts, SS.KalmanGain, SS.KalmanIdx);
% SMW and TD 6/2015

TrialStruct = parseKEF(KefFname); % read kef file
[X,Z,T,K,KDFTimes] = readKDF(KdfFname); % read KDF file

% init
KalmanMvnts = (1:12);
KalmanGain = ones(12,2);
SelectedInd = 1:size(Z,1);

% parse optional inputs
if nargin > 2
    KalmanMvnts = varargin{1};
end
if nargin > 3
    KalmanGain = varargin{2};
end
if nargin > 4
    SelectedInd = varargin{3};
end
if nargin > 5
    Lag = varargin{4};
    Z = circshift(Z,Lag,2); %need to circshift Z since trial timings are based on X
end

subX = zeros(length(KalmanMvnts), size(X,2));
subZ = zeros(length(SelectedInd), size(Z,2));
subK = zeros(length(KalmanMvnts), size(K,2));
subT = zeros(length(KalmanMvnts), size(T,2));
subKDFTimes = zeros(size(KDFTimes, 2),1);
% step through Trial struct, add data to subX and subZ if it meets criteria
curSubInd = [0,0];
lastMvnt = zeros(12,4);
skipTrialIdx = [];
if ~isempty(TrialStruct)
    for k = 1:length(TrialStruct)
        curMvntIdx = find(TrialStruct(k).MvntMat(:,1), 1);
  
        if ~isempty(curMvntIdx) %&& ~any(TrialStruct(k).MvntMat(:) ~= lastMvnt(:)) %look for desired movements, and throw out first trial
            
            if ismember(curMvntIdx,KalmanMvnts)
                curMvntSgn = TrialStruct(k).MvntMat(curMvntIdx,1)>0;
                
                if (curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,1))
                    curKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                    curSubInd(1) = curSubInd(2)+1;
                    curSubInd(2) = curSubInd(1)+sum(curKDFInd)-1;
                    subX(:,curSubInd(1):curSubInd(2)) = X(KalmanMvnts, curKDFInd);
                    subZ(:,curSubInd(1):curSubInd(2)) = Z(SelectedInd, curKDFInd);
                    subK(:,curSubInd(1):curSubInd(2)) = K(KalmanMvnts, curKDFInd);
                    subT(:,curSubInd(1):curSubInd(2)) = T(KalmanMvnts, curKDFInd);
                    subKDFTimes(curSubInd(1):curSubInd(2)) = KDFTimes(curKDFInd);
                    
                elseif (~curMvntSgn &&  KalmanGain(KalmanMvnts==curMvntIdx,2))
                    curKDFInd = (KDFTimes>=TrialStruct(k).TargOnTS & KDFTimes<=TrialStruct(k).TrialTS);
                    curSubInd(1) = curSubInd(2)+1;
                    curSubInd(2) = curSubInd(1)+sum(curKDFInd)-1;
                    subX(:,curSubInd(1):curSubInd(2)) = X(KalmanMvnts, curKDFInd);
                    subZ(:,curSubInd(1):curSubInd(2)) = Z(SelectedInd, curKDFInd);
                    subK(:,curSubInd(1):curSubInd(2)) = K(KalmanMvnts, curKDFInd);
                    subT(:,curSubInd(1):curSubInd(2)) = T(KalmanMvnts, curKDFInd);
                    subKDFTimes(curSubInd(1):curSubInd(2)) = KDFTimes(curKDFInd);
                end
            end
        else % the movement was not desired or was the first trial
            
            skipTrialIdx = [skipTrialIdx, k];
        end
        lastMvnt = TrialStruct(k).MvntMat;
    end
    
    % truncate output arrays
    if curSubInd(2)
        subX(:, curSubInd(2):end) = [];
        subZ(:, curSubInd(2):end) = [];
        subK(:, curSubInd(2):end) = [];
        subT(:, curSubInd(2):end) = [];
        subKDFTimes(curSubInd(2):end) = [];
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