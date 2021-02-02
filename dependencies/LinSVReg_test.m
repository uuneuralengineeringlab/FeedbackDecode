function xhat = LinSVReg_test(z,TRAIN,klim,init)
% LinSVReg_test - Single time sample nonlinear SVR
%
%   [xhat,P] = LinSVReg_test(xhat,P,z,TRAIN)
%
%   Inputs
%
%       xhat    -   Kinematic information from preceding time step as
%                   nKinematic by 2 double precision matrix. This is not
%                   used with this function
%
%       P       -   Although intended for the Kalman filter, this matrix is
%                   used by this function to save delay state information.
%
%       z       -   Feature information that is used to predict the
%                   kinematic information, as nFeature double
%                   precision vector.
%
%       TRAIN   -   Parameter values used by the routine. In
%                   particular, this algorithm calcualtes TRAIN.B which is
%                   the SVR model, TRAIN.N
%                   which is the number of kinematic variables
%                   (nKinematics), TRAIN.xmu which is the mean value of
%                   each kinematic variable during training, TRAIN.zmu
%                   which is the mean value of each feature during
%                   training, and TRAIN.nDelay which is the number of delay
%                   states in the linear regression.
%
%   Ouputs
%
%
%       xhat    -   Kinematic information resulting from time step as
%                   nKinematic by 2 double precision matrix.
%
%
%       P       -   Updated delay state information.
%

persistent P
if init
    numDelays = 10;
    P = zeros((numDelays+1)*length(z),1);
end

% init
xhat = zeros(size(TRAIN.xmu, 1),1);
% magic numbers
nFeatures = numel( z );

% subtract mean during training
z = z-TRAIN.zmu;

for i = 1:size(z,2)
    z(:,i) = z(:,i)./TRAIN.maxVals;
end
z(isnan(z)) = 0;

% step 1: Apply delay
P( (nFeatures+1):(end), 1 ) = P( 1:(end-nFeatures), 1 );

% step 2: Apply new data
P( 1:nFeatures, 1 ) = z(:);

% step 3: Apply regression

for n=1:numel(TRAIN.model)
    xhat(n) = TRAIN.model(n).sv_coef'*(TRAIN.SVMat{n}*P) - TRAIN.model(n).rho;
end
   
idx = xhat<klim(:,1); %minimum limit so output doesn't run wild
xhat(idx) = klim(idx,1);

idx = xhat>klim(:,2); %maximum limit
xhat(idx) = klim(idx,2);
       
return