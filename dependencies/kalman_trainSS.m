function [SSTRAIN]=kalman_trainSS(x,z)
% version = mfilename;
% calculate mu's, the means of kinematics and features, and subtract off
xmu=zeros(size(x,1),1); %mean(x,2); x=x-repmat(PARAM.xmu,[1 size(x,2)]);
zmu=zeros(size(z,1),1); %mean(z,2); z=z-repmat(PARAM.zmu,[1 size(z,2)]);

% length of the signals
N=size(x,1);
M=size(x,2);

% calculate A, the state-to-state transformation (hand kinematics)
A1=x(:,2:M)*x(:,1:(M-1))';
A2=x(:,1:(M-1))*x(:,1:(M-1))';
SSTRAIN.A=A1*pinv(A2);
% SSTRAIN.A = x(:,2:M)/x(:,1:(M-1));  %%

% calculate W, the covariance of the noise in the kinematics
W1=x(:,2:M)*x(:,2:M)';
W2=x(:,1:(M-1))*x(:,2:M)';
W=(1/(M-1))*(W1-SSTRAIN.A*W2);
W = (W+W')/2; %Added to force symmetry (needed to use dare to solve for steady state).
SSTRAIN.W = W;

% cross-correlation and autocorrelations of x and z
SSTRAIN.Pzx=z(:,1:M)*x(:,1:M)';
SSTRAIN.Rxx=x(:,1:M)*x(:,1:M)';
SSTRAIN.Rzz=z(:,1:M)*z(:,1:M)';

% calculate H, the transformation matrix from measured features to state
% SSTRAIN.H=SSTRAIN.Pzx/(SSTRAIN.Rxx); %%
SSTRAIN.H=SSTRAIN.Pzx*pinv(SSTRAIN.Rxx);

% calculate Q, the covariance of noise in the measured features
SSTRAIN.Q=(1/M)*(SSTRAIN.Rzz-SSTRAIN.H*SSTRAIN.Pzx');

SSTRAIN.N = N; %# of kinematics (not counting velocities)

SSTRAIN.P = dare(SSTRAIN.A',SSTRAIN.A'*SSTRAIN.H',SSTRAIN.W,...
    SSTRAIN.H*SSTRAIN.W*SSTRAIN.H'+SSTRAIN.Q,SSTRAIN.W*SSTRAIN.H');
Pm = SSTRAIN.A*SSTRAIN.P*SSTRAIN.A'+SSTRAIN.W;


SSTRAIN.K = Pm*SSTRAIN.H'/(SSTRAIN.H*Pm*SSTRAIN.H'+SSTRAIN.Q);
