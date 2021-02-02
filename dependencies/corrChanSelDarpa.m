function [chans loss] = corrChanSel(X,Z,mvts,threshold,maxChans,varargin)
%This function finds channels using the correlation method. 
%X: Signal being estimated, NxM, N movements and M samples.
%Z: Estimators, KxM, K channels and M samples.
%mvts: A vector holding information about which of the N movements in X 
%should be used
%threshold: A minimum correlation coefficient threshold to be considered a
%good channel.
%maxChans: The maximum number of channels that should be chosen.
%windowType (varargin{1}): 'singMvt' uses the window around each DOF
%to find the correlation and 'all' uses the entire window in X.

%chans: Vector of channels
%loss: Vector of stopping criteria values. The best number of
%channels is the one before the minimum index.

stopCritPosThresh = 5; %How many increasing values before the stopping
%criteria stops the process from adding chans.

if numel(varargin)>1
    stopCrit = varargin{2};
else
    stopCrit  = 'none';
end

if numel(varargin)>0
    windowType = varargin{1};
else
    windowType = 'singMvt';
end

sepX = zeros(0,size(X,2));
for i = 1:numel(mvts) %Make all movement positive, split DOFs with both + and - into two positives
    ind = find(X(mvts(i),:)>0);
    if ~isempty(ind)
        temp = zeros(1,size(X,2));
        temp(ind) = X(mvts(i),ind);
        sepX = [sepX; temp];
    end
    
    ind = find(X(mvts(i),:)<0);
    if ~isempty(ind)
        temp = zeros(1,size(X,2));
        temp(ind) = abs(X(mvts(i),ind));
        sepX = [sepX; temp];
    end
end

if strcmp(windowType, 'all') %Find correlation
    rzx = Z*sepX'./sqrt(dot(Z',Z')'*dot(sepX',sepX'));
elseif strcmp(windowType, 'singMvt')
    rzx = zeros(size(Z,1),size(sepX,1));
    for i = 1:size(sepX,1)
        [pSt,pEn] = findWindowsDarpa(sepX(i,:),0);
        wind = pSt(1)-25:pEn(end)+25;
        rzx(:,i) = Z(:,wind)*sepX(i,wind)'./...
            sqrt(dot(Z(:,wind)',Z(:,wind)')'*...
            dot(sepX(i,wind)',sepX(i,wind)'));
    end    
end

rzx = abs(rzx);
rzx(isnan(rzx)) = 0;
rzx(rzx<threshold) = 0;

clear ind;
for i = 1:size(sepX,1)
    [sortedRzx(:,i),ind(:,i)] = sort(rzx(:,i),'descend');
end

addOrderChans = [];

for i = 1:size(ind,2) %Add 1 channel per DOF at a time
    for j = 1:size(ind,1)
        if(sortedRzx(j,i)~=0)
            addOrderChans = [addOrderChans setdiff(ind(j,i),addOrderChans)];
        end
    end
end

if strcmp(stopCrit, 'none')
    chans = addOrderChans(1:min(maxChans,numel(addOrderChans)));
    loss = [];
else %Calculate AIC/BIC
    for i = 1:numel(addOrderChans)
        w = X/[Z(addOrderChans(1:i),:); ones(1,size(Z,2))]; %LS model
        resid = X-w*[Z(addOrderChans(1:i),:); ones(1,size(Z,2))];
        SSE = resid(:)'*resid(:); %Error
        loss(i) = stopCritDarpa([],[],resid,i,stopCrit); 
        
        if(i>1) %Check to see if loss is increasing or decreasing
            lossDir(i) = sign(loss(i)-loss(i-1));
        else
            lossDir(i) = -1;
        end
        
        if i>=stopCritPosThresh %If increasing for a while
            if(sum(lossDir(i-stopCritPosThresh+1:i))==stopCritPosThresh)
                break;
            end
        end
    end
    [~,ind] = min(loss);
    chans = addOrderChans;%(1:ind);
end