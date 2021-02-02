function [Mvnts,SelIdxs,MaxLag,C] = autoSelectMvntsChsCorr(KDFFile,Thresh,BadKalmanIdxs)
% function to automatically select movements and channels from a training
% data set based on correlations.
% inputs: 
%   KDFFile - string, full file path of KDF training file (this should have
%   the baseline subtracted for optimal results).
%   Thresh - double, threshold correlation value for selection.  Typical
%        value is in the 0.3-0.5 range
%   BadKalmanIdxs = n x 1, integer vector, list of channels to exclude from
%      the selection (e.g. known bad channels, disconnected channels etc)
% outputs: 
%   Mvnts - 12 x 2, logical, matrix of  selected DOFs and direction.  
%        First column represents flexion, secound column represents extension
%   SelIdxs - n x 1, integer vector, list of selected indexes (1 to 720)


%% read kdf file.  X = kinematics for 12 dof, Z = feature data for all ch
[X,Z] = readKDF(KDFFile);
XPos = X;
XNeg = X;
XPos(XPos<0) = 0;
XNeg(XNeg>0) = 0;
X = [XPos;XNeg];

%%
if nargin<2
    Thresh = 0.5;
    BadKalmanIdxs = [];
end

%% Subtract mean
% mX = bsxfun(@minus,X,mean(X,2));
% mZ = bsxfun(@minus,Z,mean(Z,2));

%% Calculate correlation between kinematics and movements, set correlation of bad channels to 0
Lag = (-20:20);
CMean = zeros(length(Lag),1);
for k=1:length(Lag)
    ZShift = circshift(Z,Lag(k),2);
    C = (X*ZShift')./bsxfun(@(x,y)x*y,sqrt(sum(X.^2,2)),sqrt(sum(Z.^2,2))');
    C(:,BadKalmanIdxs) = nan;
    CMean(k) = nanmean(abs(C(:)));
end
[~,idx] = max(CMean);
MaxLag = Lag(idx);
ZShift = circshift(Z,MaxLag,2);
C = (X*ZShift')./bsxfun(@(x,y)x*y,sqrt(sum(X.^2,2)),sqrt(sum(Z.^2,2))');
C(:,BadKalmanIdxs) = nan;

%%
Mvnts = [any(C(1:12,:)>=Thresh,2),any(C(13:24,:)<=-Thresh,2)]; Mvnts = Mvnts(1:12,:);
SelIdxs = find(any(C(1:12,:)>=Thresh | C(13:24,:)<=-Thresh,1));

