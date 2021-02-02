function [channels version akaike] = AkaikeGramSchmChanSelv300(X, Z, mvts, numChannels)
%Sample Call: [channels version akaike] = AkaikeGramSchmChanSelv300(X, Z, 1:12, 720);

posThresh = 5; %how many samples need to be increasing in the akaike metric

version = mfilename;
%     fullX = zeros(size(X{1},1),0);
%     fullZ = zeros(size(Z{1},1),0);
%     for i = 1:numel(mvts)
%         fullX = [fullX X{i}];
%         fullZ = [fullZ Z{i}];
%     end
    fullX = X;
    fullZ = Z;
    allW = fullZ'\fullX';
    for i = 1:numel(mvts)
        %Akaike stuff
        S2 = mean((fullX(i,:)-allW(:,i)'*fullZ).^2);
        meanX = mean(fullX(i,:));
        SStot = sum((fullX(i,:)-meanX).^2);
        
        mu = zeros(size(fullZ,2),1); %estimate of X
        actives = []; %channels that are chosen
        newZ = fullZ;
        allw = zeros(size(fullZ,10));
        for j = 1:numChannels
            
            resid = fullX(mvts(i),:)'-mu;
            SSE = resid'*resid;
            
          akaike{i}(j) = numel(resid)*log(SSE)+(j-1)*log(numel(resid)); %Bayesian info crit. using Gaussian (Least Squares), chooses fewest channels
%             
%             akaike{i}(j) =  2*(j-1) + numel(resid)*... %Akaike using LS maximum likelihood
%                log((resid'*resid))+2*(j)*(j-1)/(numel(resid)-j-2);
            
%             akaike{i}(j) = 2*(j-1) + numel(resid)*... % Wrong but original method Akaike using LS maximum likelihood
%                 log((resid'*resid)) + 2*(j-1)*(j-2);
            if j>1
                akaikeDir{i}(j) = sign(akaike{i}(j)-...
                    akaike{i}(j-1));
            else
                akaikeDir{i}(j) = -1;
            end
            
            corrs = newZ*(resid)./sqrt((resid'*resid)*dot(newZ',newZ')');
            corrs(isnan(corrs)) = 0;
%             corrs = newZ*(resid);
                        
            [val ind] = sort(abs(corrs), 'descend');
            
            %Add first channel not added
            while(~isempty(find(actives==ind(1))))
                ind = ind(2:end);
            end
            ind = ind(1);
            actives = [actives ind];
            
            %w = sign(ind(1))*resid'*resid/(resid'*newZ(ind,:)');
            w = resid'*newZ(ind,:)'/(newZ(ind,:)*newZ(ind,:)');
                       
            mu = mu + w*newZ(ind,:)';
            
            %estimating every other channe (Gram-Schmidt)
            denom = (newZ(ind,:)*newZ(ind,:)');
            temp = newZ(ind,:)';
            for k = 1: size(fullZ,1)
                w = (newZ(k,:)*temp)/denom;
                
                newZ(k,:) =  newZ(k,:) - w*newZ(ind,:);
            end
            allw(ind) = w;
            
            %Check for increasing Akaike
            if j>4
            if sum(akaikeDir{1}(j-posThresh+1:j)) == posThresh
                break;
            end
            end  
        end
        %[~,minInd] = min(akaike{i});
        %channels{i} = actives(1:minInd);
        j=j+1;
        resid = fullX(mvts(i),:)'-mu;
        SSE = resid'*resid;

      
        akaike{i}(j) = numel(resid)*log(SSE)+(j-1)*log(numel(resid)); %Bayesian info crit. using Gaussian (Least Squares), chooses fewest channels

%         akaike{i}(j) =  2*(j-1) + numel(resid)*... %Akaike using LS maximum likelihood
%            log((resid'*resid))+2*(j)*(j-1)/(numel(resid)-j-2);

%         akaike{i}(j) = 2*(j-1) + numel(resid)*... % Wrong but original method Akaike using LS maximum likelihood
%             log((resid'*resid)) + 2*(j-1)*(j-2);
       [~,minInd] = min(akaike{i});
        if minInd>1
            channels{i} = actives(1:minInd-1);
        else
            channels{i} =[];
        end
    end
end