function [PARAM,x,z]=LinSVReg_train(x,z)
% NonLinSVReg_train - calculate linear SVR training data
%
%   [PARAM,x,z]=LinSVReg_train(x,z)
%
%   Inputs
%
%       x       -   Kinematic information to be estimated as nKinematics by
%                   nSample double precision matrix
%
%       z       -   Feature information that is used to predict the
%                   kinematic information, as nFeature by nSample double
%                   precision matrix
%
%   Ouputs
%
%       PARAM   -   Parameter values calculated by the routine. In
%                   particular, this algorithm calcualtes PARAM.model which is
%                   the support vector regression model, PARAM.N
%                   which is the number of kinematic variables
%                   (nKinematics), PARAM.xmu which is the mean value of
%                   each kinematic variable during training, PARAM.zmu
%                   which is the mean value of each feature during
%                   training, PARAM.nDelay which is the number of delay
%                   states in the linear regression, and PARAM.SVMat, which
%                   is a  matrix of support vectors.
%
%       x       -   The same x as passed to the function.
%
%       z       -   The same z as passed to the function.
%

% magic numbers
nDelays = 10;

svmType = '3'; %Epsilon SVR type
kernelType = '0'; %Linear kernel (u'*v)
degree = '3'; %This is default and is not used for radial basis function kernel (Gaussian)
%gamma =  num2str(1/size(z,1), '%.3g'); %This is default for lib-svm, can be changed
%I have removed gamma for the moment, since LibSVM seems to do better just
%calculating this itself. If better values for gamma are somehow
%discovered, an appropriate entry will need to be made in the parameters
%passed to libsvm
epsilon = '.1'; %This is default for lib-svm, this is the margin of the SVR




% calculate mu's, the means of kinematics (x) and features (z), and subtract off
%
%   Note: these values are zeroed out and not used by this method
%
PARAM.xmu=zeros(size(x,1),1); %mean(x,2); x=x-repmat(PARAM.xmu,[1 size(x,2)]);
PARAM.zmu=zeros(size(z,1),1); %mean(z,2); z=z-repmat(PARAM.zmu,[1 size(z,2)]);

% length of the signals
nKinematics = size( x, 1 ); % number of predictions or 
nFeatures = size( z, 1 ); % number of predictors
nSamples = size( x ,2 ); % number of time samples

PARAM.maxVals = max(z,[],2);

for i = 1:size(z,2)
    z(:,i) = z(:,i)./PARAM.maxVals;
end

z(isnan(z)) = 0;

% put things into preferred orientation
predictions = x';
features = z';



% calculate Z, the predictor matrix with delays added
Z = zeros( nSamples, (nDelays+1)*nFeatures );
%Z( :, end ) = 1;
Z( :, 1:nFeatures ) = features;



for n = 1:nDelays
    n1 = 1 + nFeatures*n;
    n2 = n1 + (nFeatures-1);
    n3 = nSamples - n;
    Z( :, n1:n2 ) = [ ...
        zeros( n, nFeatures );
        Z( 1:n3, 1:nFeatures )];
    clear n1 n2 n3
end;clear n
PARAM.nDelays = nDelays;

% calculate B, the svm model
for n = 1:nKinematics
    PARAM.model(n) = svmtrain(predictions(:,n), Z, ...
    ['-s ' svmType ' -t ' kernelType ' -h 1 ' ' -d '  degree ' -p ' epsilon ' -m 1000 -q']);
    PARAM.SVMat{n} = zeros(size(PARAM.model(n).SVs))+PARAM.model(n).SVs;
end

PARAM.N = nKinematics; %# of kinematics

return