function xhat_out = kalman_test_adaptation(z,TRAIN,klim,init,AdaptOnline,Thresh)

persistent xhat
persistent P

if init    
    xhat = zeros(size(TRAIN.A,1),1);
    P = zeros(size(TRAIN.A));    
else    
    % step 1: time-update equations
    xhatm = TRAIN.A*xhat; %previous xhat
    Pm = TRAIN.A*P*TRAIN.A'+TRAIN.W ; %previous P
    
    % step 2: measurement-update equations
    K = Pm*TRAIN.H'*pinv(TRAIN.H*Pm*TRAIN.H'+TRAIN.Q);
    xhat = xhatm + K*(z-TRAIN.H*xhatm); %current xhat
    P = (eye(size(K,1))-K*TRAIN.H)*Pm; %current P
    
    idx = xhat<klim(:,1); %minimum limit so kalman output doesn't run wild
    xhat(idx) = klim(idx,1);
    
    idx = xhat>klim(:,2); %maximum limit
    xhat(idx) = klim(idx,2);
    
    if AdaptOnline.ShouldAdapt == 1 && ~isempty(AdaptOnline.GoalX)
        
        transGoal = AdaptOnline.GoalX;
        transGoal(transGoal>0) = transGoal(transGoal>0)*(1-Thresh)+Thresh;
        transGoal(transGoal<0) = transGoal(transGoal<0)*(1-Thresh)-Thresh;
        
        xhat = xhat - AdaptOnline.AdaptationRate * (xhat -transGoal);
       
    end

    
end
xhat_out = xhat;
