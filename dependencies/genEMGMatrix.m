function [EMGMatrix,EMGChanPairs,BadEMGIdxs] = genEMGMatrix(BadEMGChans)

% Generates a matrix to multiply with EMG buffer to create differential EMG
% data streams for all possible combinations of 4 on an individual lead
% (emg1, emg2, emg3, emg4, emg12, emg13, emg14, emg23, emg24, emg 34). The
% 1st 80 columns are all possible combinations constrained to a single
% lead. The remaining columns are all other combinations spanning leads.
%
% BadEMGChans = [1,2,3,...32];
% BadEMGIdxs = [1,2,3,...528];

EMGSub = [1,0,0,0,1,1,1,0,0,0;0,1,0,0,-1,0,0,1,1,0;0,0,1,0,0,-1,0,-1,0,1;0,0,0,1,0,0,-1,0,-1,-1];
EMGMatrix1 = repmat(EMGSub,8,8).*kron(eye(8),ones(4,10));

Pairs1 = repmat([1,2;1,3;1,4;2,3;2,4;3,4],8,1)+repmat(reshape(repmat(0:4:28,6,1),[],1),1,2);
Pairs2 = setdiff(nchoosek(1:32,2),Pairs1,'rows');

EMGMatrix2 = zeros(32,size(Pairs2,1));
for k=1:size(Pairs2,1)
   EMGMatrix2(Pairs2(k,:),k) = [1,-1]; 
end

EMGMatrix = [EMGMatrix1,EMGMatrix2];

EMGChanPairs = nan(size(EMGMatrix,2),2);

[r,c] = find(EMGMatrix==1);
EMGChanPairs(c,1) = r;

[r,c] = find(EMGMatrix==-1);
EMGChanPairs(c,2) = r;

if isempty(BadEMGChans)
    BadEMGIdxs = [];
else
    BadEMGIdxs = find(any(bsxfun(@(x,y) x==y,EMGChanPairs(:,1),BadEMGChans),2) | any(bsxfun(@(x,y) x==y,EMGChanPairs(:,2),BadEMGChans),2));
end

EMGChanPairs(BadEMGIdxs,:) = nan;
EMGMatrix(:,BadEMGIdxs) = 0;


