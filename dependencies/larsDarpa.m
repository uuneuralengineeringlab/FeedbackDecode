function [channels loss] = lars(X, Z, mvts, maxChans, varargin)

%This function finds channels using LEAST ANGLE REGRESSION (LARS). 
%X: Signal being estimated, NxM, N movements and M samples.
%Z: Estimators, KxM, K channels and M samples.
%mvts: A vector holding information about which of the N movements in X 
%should be used
%maxChans: The maximum number of channels that should be chosen
%sepMvts (varargin{1}): Find for each DOF individually, or all at once.
%stopCrit: 'AIC' or 'BIC', which stopping criteria to use
%windowType: 'singMvt' uses the window around each DOF
%to find the correlation and 'all' uses the entire window in X, for 
%pre-selecting potential channels.
%threshold: A minimum correlation coefficient threshold (with the kinematic)
%to be considered a good channel.

%chans: Cell of vectors of channels for each DOF
%loss: Cell of vectors of stopping criteria values. The best number of
%channels is the one before the minimum index.

if numel(varargin)>2
    corrKineThresh = varargin{3};
else
    corrKineThresh = .3;
end

if numel(varargin)>1
    windowType = varargin{2};
else
    windowType = 'all';
end

if numel(varargin)>0
    stopCrit = varargin{1};
else
    stopCrit = 'none';
end    

possChans = corrChanSelZeroMeanDarpa(X,Z,mvts,corrKineThresh,size(Z,1),windowType);

posThresh = 5; %How many increasing values of the stopping criteria before we stop adding channels

fullX = X;
fullZ = Z(possChans,:);

fullX = fullX - repmat(mean(fullX,2),1,size(fullX,2));
fullZ = fullZ - repmat(mean(fullZ,2),1,size(fullZ,2));
fullZ = fullZ./repmat(sqrt(sum(fullZ.^2,2)),1,size(fullZ,2));

fullZ(isnan(fullZ)) = 0;

if maxChans >= size(fullZ,1) %The main loop has trouble with the last channel, so we add it outside the loop
    numChannels = size(fullZ,1)-1;
    maxChans = size(fullZ,1);
else
    numChannels = maxChans;
end

for i = 1:numel(mvts) 
    mu = zeros(size(fullZ,2),1);
    channels{i} = [];
    for j = 1:numChannels        
        if ~strcmp(stopCrit, 'none'); %Stopping criteria
            loss{i}(j) = stopCritDarpa(fullX(mvts(i),:),mu',[],j-1,stopCrit);          
        else
            loss{i}(j) = -j;
        end
        
        if j>1
            lossDir(j) = sign(loss{i}(j)-...
                loss{i}(j-1));
        else
            lossDir(j) = -1;
        end
        
        corrs=fullZ*(fullX(mvts(i),:)'-mu);
           
        [vals ind] = sort(abs(corrs), 'descend');

        C = abs(vals(1:j));
        a = ind(1:j);
        channels{i} = [channels{i} setdiff(a,channels{i})'];
        s = sign(corrs(ind(1:j)));

        Z_a = fullZ(a,:); %LARs math
        for k = 1:numel(a)
            Z_a(k,:) = Z_a(k,:).*s(k);
        end
        G_a = Z_a*Z_a';
        A_a = (ones(1,size(G_a,1))/G_a*ones(size(G_a,1),1))^(-1/2);
        w_a = A_a*(G_a\ones(size(G_a,1),1));
        u_a = Z_a'*w_a;

        a_vec = (fullZ*u_a);
        set = [(C(1)-corrs(ind(j+1:end)))./(A_a-a_vec(ind(j+1:end))); (C(1)+corrs(ind(j+1:end)))./(A_a+a_vec(ind(j+1:end)))];

        [gInd gInd2 gammaList] = find(set(set>0));
        gamma = min(gammaList);

        if(isempty(gamma))
            break;
        end

        mu = mu + gamma*u_a;
        
        %if j>posThresh-1
        %   if sum(lossDir(j-posThresh+1:j)) == posThresh
        %       break;
        %   end
        %end

    end
    j = j + 1;
    
    if ~strcmp(stopCrit, 'none'); %One final stopping criteria
        loss{i}(j) = stopCritDarpa(fullX(mvts(i),:),mu',[],j-1,stopCrit);          
    else
        loss{i}(j) = -j;
    end

    if j>1
        lossDir(j) = sign(loss{i}(j)-...
            loss{i}(j-1));
    else
        lossDir(j) = -1;
    end
    
    if maxChans == size(fullZ,1) && j == numChannels+1
        channels{i} = [channels{i} setdiff(1:numel(possChans),channels{i})];
        w = fullX(mvts(i),:)/fullZ(channels{i},:);
        loss{i}(j+1) = stopCritDarpa(fullX(mvts(i),:),...
            w*fullZ(channels{i},:),[],j,stopCrit);
    end
    [~,minInd] = min(loss{i});
    %channels{i} = channels{i}(1:minInd-1);
        
    channels{i} = possChans(channels{i});
    %loss{i} =[];
end
