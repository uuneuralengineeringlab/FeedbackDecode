function RandTrials = isRandTrials(TrialStruct)

% Determines if trials are random or squential


mvnts = cat(3,TrialStruct.MvntMat);
trials = (1:size(mvnts,3))';
mvntidx = {};
mvntcnt = [];
umvnt = [];
isseq = [];
k=1;
while true
    idx = squeeze(all(all(bsxfun(@(x,y)x==y,mvnts(:,:,1),mvnts),1),2));
    mvntidx(k,1) = {trials(idx)};
    mvntcnt(k,1) = sum(idx);
    umvnt(:,:,k) = mvnts(:,:,1);
    isseq(k,1) = all(diff(mvntidx{k})==1);
    mvnts(:,:,idx) = [];
    trials(idx) = [];
    if isempty(mvnts)
        break;
    end
    k=k+1;
end

RandTrials = ~all(isseq);


