function SurrMat = genSurrIdxs(NDist,BadElects,NumUEAs,MapType)
% modified by smw 7/31/15 (takes care of bad elecs in weight values),
% 8/5/15 (converts output into single operation weights for CAR)
GEM = reshape(1:100,10,10);
[X,Y] = meshgrid(1:10,1:10);
SurrMat = zeros(96,96);
SURRMAT = zeros(96*NumUEAs, 96*NumUEAs);
for j = 1:NumUEAs
    for k=1:96
        [y,x] = find(GEM==c2e(k,MapType));
        D = sqrt((X-x).^2+(Y-y).^2);
        G = find(D<=sqrt(NDist^2+NDist^2)&D>0);
        S = e2c(setdiff(G,[[1,11,81,91],(BadElects -(j-1)*100) ]),MapType);
        SurrMat(S,k) = 1/length(S);
    end
SURRMAT(((1:96)+(j-1)*96),((1:96)+(j-1)*96) ) = SurrMat;   
end
% convert weight matrix to negatives with identity values = 1, for single
% step multiplication for CAR calculation (d = d*weights as opposed to d =
% d - d*weights)
SURRMAT = eye(NumUEAs*96)-SURRMAT; % smw

SurrMat = SURRMAT;


% original (doesn't take into account bad elecs in the weight values):
% GEM = reshape(1:100,10,10);
% [X,Y] = meshgrid(1:10,1:10);
% SurrMat = zeros(96,96);
% for k=1:96
%     [y,x] = find(GEM==c2e(k,'pns'));
%     D = sqrt((X-x).^2+(Y-y).^2);
%     G = find(D<=sqrt(NDist^2+NDist^2)&D>0);
%     S = e2c(setdiff(G,[1,11,81,91]),'pns');
%     SurrMat(S,k) = 1/length(S);
% end
% SurrMat = repmat(SurrMat,NumUEAs,NumUEAs).*kron(eye(NumUEAs),ones(96));
% Idxs = mapRippleUEA(BadElects,'e2i');
% Idxs(isnan(Idxs)) = [];
% SurrMat(Idxs,:) = 0;