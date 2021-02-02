function [channels version akaike] = gramSchm(X, Z, mvts, numChannels)

posThresh = 5;

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
        S2 = mean((fullX(i,:)-allW(:,i)'*fullZ).^2);
        meanX = mean(fullX(i,:));
        SStot = sum((fullX(i,:)-meanX).^2);
        
        mu = zeros(size(fullZ,2),1);
        actives = [];
        newZ = fullZ;
        allw = zeros(size(fullZ,10));
        for j = 1:numChannels
            
            resid = fullX(mvts(i),:)'-mu;
            SSE = resid'*resid;
            
            %akaike{i}(j) = SSE/S2-size(X,2)+2*(j-1);
            akaike{i}(j) = 2*(j-1) + numel(resid)*...
                log((resid'*resid)) + 2*(j-1)*(j-2);
            if j>1
                akaikeDir{i}(j) = sign(akaike{i}(j)-...
                    akaike{i}(j-1));
            else
                akaikeDir{i}(j) = -1;
            end
                
            corrs = newZ*(resid);
                        
            [val ind] = sort(abs(corrs), 'descend');
            
            while(~isempty(find(actives==ind(1))))
                ind = ind(2:end);
            end
            ind = ind(1);
            actives = [actives ind];
            
            %w = sign(ind(1))*resid'*resid/(resid'*newZ(ind,:)');
            w = resid'*newZ(ind,:)'/(newZ(ind,:)*newZ(ind,:)');
            
            mu = mu + w*newZ(ind,:)';
            
            denom = (newZ(ind,:)*newZ(ind,:)');
            temp = newZ(ind,:)';
            for k = 1: size(fullZ,1)
                w = (newZ(k,:)*temp)/denom;
                newZ(k,:) =  newZ(k,:) - w*newZ(ind,:);
            end
            allw(ind) = w;
                                           
            
            if j>4
            if sum(akaikeDir{1}(j-posThresh+1:j)) == posThresh
                [~,minInd] = min(akaike{i});
                channels{i} = actives(1:minInd);
                break;
            end
            end
            
            if j == numChannels
                [~,minInd] = min(akaike{i});
                channels{i} = actives(1:minInd);
            end
            
        end
        %[~,minInd] = min(akaike{i});
        %channels{i} = actives(1:minInd);
    end
end