function w = newtDesc3rd(X,Z,varargin)
%This function finds a local minimum w such to minimize: 
%mean((X-(w'*Z).^d).^2)+ceta*(w'*w)^3


if numel(varargin)<1
%     ceta = 1e-6;%Penalty on norm of weights
    ceta = 1;%Penalty on norm of weights, modified 1/18/17 to prevent overfitting
else 
    ceta = varargin{1};
end

if numel(varargin)<2
    w = sign(sum(X))*rand(size(Z,1),1); %Initialize weights to same sign as direction of movement
else
    w = varargin{2};
end

    d = 3; %Poly Order
    ind  = 1;
    
    beta = .9; %Line search parameters (backtracking line search
    alpha = .4;
    
    gradw = mean(-2*d*repmat((X-(w'*Z).^d).*((w'*Z).^(d-1))...
            ,size(Z,1),1).*Z,2)+ceta*6*(w'*w)^2*w; %Find gradient of loss 
        %with repect to current weights
        
    grad2w = -2*d*((Z.*repmat(-d.*(w'*Z).^(2*d-2)+...
            (X-(w'*Z).^d).*(d-1).*(w'*Z).^(d-2),size(Z,1),1))/size(Z,2))*Z'+...
            ceta*6*(2*(w'*w)*w*w'+ (w'*w)^2*eye(size(Z,1),size(Z,1)));
        %Find Hessian of loss with respect to current weights
        
    newtStep = -grad2w\gradw;%Compute direction of step
    lambda2 = -gradw'*newtStep;%Compute stopping criteria check
        
    while lambda2(ind) > 1e-12
        gradw = mean(-2*d*repmat((X-(w'*Z).^d).*((w'*Z).^(d-1))...
            ,size(Z,1),1).*Z,2)+ceta*6*(w'*w)^2*w;
        
        grad2w = -2*d*((Z.*repmat(-d.*(w'*Z).^(2*d-2)+...
            (X-(w'*Z).^d).*(d-1).*(w'*Z).^(d-2),size(Z,1),1))/size(Z,2))*Z'+...
            ceta*6*(2*(w'*w)*w*w'+ (w'*w)^2*eye(size(Z,1),size(Z,1)));
        newtStep = -grad2w\gradw;
        lambda2(ind+1) = -gradw'*newtStep;
        t = 1;

        fW = mean((X-(w'*Z).^d).^2)+ceta*(w'*w)^3; %Current value of loss
        count = 1;
        %Backtracking line search
        while mean((X-...
                ((w+t*newtStep(1:end))'*Z).^d).^2)+...
                ceta*((w+t*newtStep(1:end))'*(w+t*newtStep(1:end)))^3 > ...
                fW + alpha*t*gradw'*(newtStep)
            t = beta*t;
        end

        w = w+ t*newtStep;%Step
        ind = ind+1;
    end
end