function model = trainVelocityLS(X,Z,w,beta)
    model.ZMax = ones(size(max(Z,[],2)));
    Z = Z./repmat(model.ZMax,1,size(Z,2));
    Z(isnan(Z)) = 0;
    
    Z = [Z; ones(1,size(Z,2))];
    holdLevOrig = .5;
    holdWidthOrig = .2;
    negVelScale = .4;
    
    maxVel = .2;
    b = .2; h = .1;
    
    XPos = X;
    XPos(XPos<0) = 0;
    XNeg = X;
    XNeg(XNeg>0) = 0;
    lambda = 1;%1e-6;
    
    XPos = XPos-holdLevOrig-holdWidthOrig;
    XPosOrig = XPos;
    XPos(XPosOrig<=-holdLevOrig-holdWidthOrig) = -b+h;
    XPos(XPosOrig>-holdLevOrig-holdWidthOrig & XPosOrig<=-2*holdWidthOrig)=...
        XPosOrig(XPosOrig>-holdLevOrig-holdWidthOrig & XPosOrig<=-2*holdWidthOrig)*...
        (2*(b-h)/holdLevOrig) + 2*holdWidthOrig + holdLevOrig;
    XPos(XPosOrig>-2*holdWidthOrig&XPosOrig<=0) = 0;
    XPos(XPos>0) = XPos(XPos>0)/max(XPos(XPos>0))*maxVel;
    
    XNeg = XNeg+holdLevOrig+holdWidthOrig;
    XNegOrig = XNeg;
    XNeg(XNegOrig>=holdLevOrig+holdWidthOrig) = b-h;
    XNeg(XNegOrig<holdLevOrig+holdWidthOrig & XNegOrig>=2*holdWidthOrig)=...
        XNegOrig(XNegOrig<holdLevOrig+holdWidthOrig & XNegOrig>=2*holdWidthOrig)*...
        (2*(b-h)/holdLevOrig) - 2*holdWidthOrig -  holdLevOrig;
    XNeg(XNegOrig<2*holdWidthOrig&XNegOrig>=0) = 0;
    XNeg(XNeg<0) = XNeg(XNeg<0)/min(XNeg(XNeg<0))*-maxVel;
      
%     XNeg = XNeg+.3;
%     XNeg(XNeg>.2999&XNeg<.30001) = b-h;
%     XNeg(XNeg>.09999&XNeg<.10001) = 0;
%     XNeg(XNeg<-.69999&XNeg>-.70001) = -.3;
       
    fullX = [XPos; XNeg];
    
    XPos2 = XPos;
    XPos2(XPos==0) = -h/2;
    XPos2(XPos==-b+h) = -b;
    
    XNeg2 = XNeg;
    XNeg2(XNeg==0) = h/2;
    XNeg2(XNeg==b-h) = b;
    
    fullX2 = [XPos2; XNeg2];
    %options = optimoptions(@fminunc);
    %options.MaxIterations = 1e5;
    %options.MaxFunctionEvaluations = 1e5;
    options.MaxFunEvals = 1e6;
    options.MaxIter = 1e6; 
    for i = 1:size(fullX,1)
        
        if i>size(fullX,1)/2
            wOrig = -fullX(i,:)/Z;
            L = @(w) weightedLoss(-fullX(i,:),est(w,Z,b,h))+lambda*sqrt(mean(w.^2));
            %wOrig2 = -fullX2(i,:)/Z;
            %L2 = @(w) weightedLoss(-fullX2(i,:),est2(w,Z,b))+lambda*sqrt(mean(w.^2));
        else
            wOrig = fullX(i,:)/Z;
            L = @(w) weightedLoss(fullX(i,:),est(w,Z,b,h))+lambda*sqrt(mean(w.^2));% mean(((fullX(i,:)-est(w,Z,b,h)).^2)) + lambda * mean(w.^2);
            %wOrig2 = fullX2(i,:)/Z;
            %L2 = @(w) weightedLoss(fullX2(i,:),est2(w,Z,b))+lambda*sqrt(mean(w.^2));
 
        end
        opts2 = optimset('fminunc');
        opts2.MaxFunEvals = 1e6;
        opt2.MaxIter = 1e6;
        %tic; 
        model.w(i,:) = fminsearch(L,wOrig,options);
        %toc; tic;
        %model.w(i,:) = fminunc(L,wOrig,opts2);
        %toc; tic;
        %model.w3(i,:) = fminsearch(L,model.w2(i,:),options);
        %toc;
        %i
        %err1 = sqrt(mean((fullX(i,:)-wOrig*Z).^2));
        %err2 = sqrt(mean((fullX(i,:)-est(model.w,Z,b,h)).^2));
    end
    model.b = b;
    model.h = h;
    model.negVelScale = negVelScale;
end

function loss = weightedLoss(X,Xhat)
    err = (X-Xhat).^2;
    err(X==0) = 5*err(X==0);
    loss = sqrt(mean(err));
end

function estimate = est(w,Z,b,h)
    estimate = w*Z;
    estOrig = estimate;
    estimate(estOrig<=-b) = -b+h;
    estimate(estOrig>-b&estOrig<=-h) = h+estimate(estOrig>-b&estOrig<=-h);%...
        %+b*h/(b-h);%*b/(b-h)+b*h/(b-h);
    estimate(estOrig<0&estOrig>=-h) = 0;    
end

function estimate = est2(w,Z,b)
    estimate = w*Z;
    estimate(estimate<-b) = -b;
end

function w = subGradient(w,X,Z,rate)
    ind = randperm(size(X,2));
    
    for i = 1:numel(ind)
        temp = w*Z(:,ind);
        temp(temp<0) = 0;
        grad = 2*(X(ind)-w*Z(:,ind))*Z(:,ind);
        
        w = w - rate(i)*grad;
    end
end