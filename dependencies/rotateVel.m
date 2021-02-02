%%
[x,z,t,Kalman,NIPTime] = readKDF('E:\Data\P201401\20140709-095846\Kalman_TaskData_20140709-095846.kdf');

N=size(x,1);
x=[x(:,1:end-1);diff(x,1,2);ones(1,size(x,2)-1)]; %adding velocity and baseline
M=size(x,2);

v = t(:,1:M)-x(1:N,:); %vector from current position to target
v = v.*repmat(sqrt(sum(x(N+1:2*N,:).^2))./sqrt(sum(v.^2)),N,1); %adjust to match velocity magnitude

x(N+1:2*N,:) = v; %adding adjusted velocity back to kinematic variable
