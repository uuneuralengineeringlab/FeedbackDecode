function [chans loss] = gramSchm(X, Z, mvts, maxChans, varargin)

%This function finds channels using the forward selection (gram-schmidt
%orthogonalization procedure). 
%X: Signal being estimated, NxM, N movements and M samples.
%Z: Estimators, KxM, K channels and M samples.
%mvts: A vector holding information about which of the N movements in X 
%should be used
%maxChans: The maximum number of channels that should be chosen
%sepMvts (varargin{1}): Find for each DOF individually, or all at once.
%stopCrit: 'AIC' or 'BIC', which stopping criteria to use.
%windowType: 'singMvt' uses the window around each DOF
%to find the correlation and 'all' uses the entire window in X, for 
%pre-selecting potential channels.
%threshold: A minimum correlation coefficient threshold (with the kinematic)
%to be considered a good channel.

%chans: Cell of vectors of channels for each DOF
%loss: Cell of vectors of stopping criteria values. The best number of
%channels is the one before the minimum index.

if numel(varargin)>3
    corrKineThresh = varargin{4};
else
    corrKineThresh = .3;
end

if numel(varargin)>2
    windowType = varargin{3};
else
    windowType = 'all';
end

if numel(varargin)>1
    stopCrit = varargin{2};
else
    stopCrit = 'none';
end    

if numel(varargin)>0
    sepMvts = varargin{1};
else
    sepMvts = 0;
end

%End of inputs

myCorr = @(Z,X) Z*X'./sqrt(dot(Z',Z')'*dot(X',X')); %correlation coefficient

possChans = corrChanSelZeroMeanDarpa(X,Z,1:size(X,1),corrKineThresh,size(Z,1),windowType);

posThresh = 5;

fullZ = Z(possChans,:);

if ~sepMvts 
    fullX{1} = X(mvts,:)-repmat(mean(X(mvts,:),2),1,...
        size(X,2));
else
    for i = 1:numel(mvts)
        fullX{i} = X(mvts(i),:)-mean(X(mvts(i),:));
    end
end

fullZ = fullZ-repmat(mean(fullZ,2),1,size(fullZ,2)); 
%fullZ = fullZ./repmat(max(fullZ,[],2),1,size(fullZ,2));
fullZ(isnan(fullZ)) = 0;

for i = 1:numel(fullX)
    mu = zeros(size(fullX{i}));
    actives = [];
    newZ = fullZ./repmat(sqrt(sum(fullZ.^2,2)),1,size(fullZ,2));
    clear lossDir   
    for j = 1:min(maxChans,numel(possChans))
        
        resid = fullX{i}-mu;
        residNorm = resid./repmat(sqrt(sum(resid.^2,2)),1,size(resid,2));
        SSE = resid(:)'*resid(:); %Calculate error
        
        for k = 1:size(resid,1) %find stopping criterion value
            if ~strcmp(stopCrit,'none')
                loss{i}(k,j) = stopCritDarpa([],[],resid(k,:),j-1,stopCrit);          
            else
                loss{i}(k,j) = -j;
            end
                
            if j>1 %Check to see if stopping crit is increasing or decreasing
                lossDir(k,j) = sign(loss{i}(k,j)-...
                    loss{i}(k,j-1));
            else
                lossDir(k,j) = -1;
            end        
        end
        
        corrs = newZ*residNorm';%myCorr(newZ,resid);
        corrs(isnan(corrs)) = 0;
        
        [val ind] = sort(abs(corrs(:)), 'descend');
        
        [ind1 ind2] = ind2sub(size(corrs),ind);

        while(~isempty(find(actives==ind1(1)))) %find new channels, not active
            ind1 = ind1(2:end);
        end
        ind = ind1(1);
        actives = [actives ind];

        w =  resid/newZ(ind,:); 
            
        mu = mu + w*newZ(ind,:); %Find new residual
        
        temp = newZ(ind,:); 
        
        w = newZ/temp;
        newZ = newZ-w*temp;
        
        newZ = newZ./repmat(sqrt(sum(newZ.^2,2)),1,size(newZ,2));
        newZ(actives(j),:)=0;
%         if j>posThresh-1
%            if sum(sum(lossDir(:,j-posThresh+1:j))) == size(resid,1)*posThresh
%                break;
%            end
%         end
    end
        
    j = j+1; %Final stopping criteria value
    resid = fullX{i}-mu;
    SSE = resid(:)'*resid(:);
    
    for k = 1:size(resid,1)
        if ~strcmp(stopCrit,'none')
            loss{i}(k,j) = stopCritDarpa([],[],resid(k,:),j-1,stopCrit);          
        else
            loss{i}(k,j) = -j;
        end
    end
    
    [~,temp] =  min(loss{i},[],2); %Find channel with best stopping crit  
    [ind] = max(temp);
    ind = ind-1;
    
    if strcmp(stopCrit,'none')
        loss = [];
    end
    
    chans{i} = possChans(actives); 
end
