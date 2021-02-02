function [channels, version, akaike] =...
    BayesGramSchmNormChanSelAllMvtsv300(X, Z, mvts, numChannels)

version = mfilename;
posThresh = 5;
%     fullX = zeros(size(X{1},1),0);
%     fullZ = zeros(size(Z{1},1),0);
%     for i = 1:numel(mvts)
%         fullX = [fullX X{i}];
%         fullZ = [fullZ Z{i}];
%     end
    fullX = X(mvts,:);
    fullZ = Z;
    
%    for i = 1:numel(mvts)
        mu = zeros(size(fullX));%zeros(size(fullZ,2),1);
        actives = [];
        newZ = fullZ;
        %allw = zeros(size(fullZ,10));
        for j = 1:numChannels
            
            resid = fullX-mu;
            SSE = resid(:)'*resid(:);%dot(resid',resid');
            
            akaike(j) = numel(resid)*log(SSE/numel(resid))+...
                size(fullX,1)*(j-1)*log(numel(resid));
            
            if j>1
                akaikeDir(j) = sign(akaike(j)-...
                    akaike(j-1));
            else
                akaikeDir(j) = -1;
            end
            
            %zmNewZ = newZ-repmat(mean(newZ')',1,size(newZ,2));
            %zmResid = resid-repmat(mean(resid')',1,size(resid,2));

            corrs = ...%(zmNewZ*(zmResid'))./sqrt(dot(zmNewZ',zmNewZ')'*(dot(zmResid',zmResid')));
                    (newZ*(resid'))./sqrt(dot(newZ',newZ')'*(dot(resid',resid')));
             
            %for k = 1:size(fullZ,1)
            %    corrs2(k) = xcorr(resid, newZ(k,:), 0, 'coeff');
            %end
            
            corrs(isnan(corrs)) = 0;
            
            [val ind] = sort(abs(corrs(:)), 'descend');
            
            [ind1 ind2] = ind2sub(size(corrs),ind);
            
            while(~isempty(find(actives==ind1(1))))
                ind1 = ind1(2:end);
            end
            ind = ind1(1);
            actives = [actives ind];
            
            %w = sign(ind(1))*resid'*resid/(resid'*newZ(ind,:)');
            w = resid*newZ(ind,:)'/(newZ(ind,:)*newZ(ind,:)');
            
            mu = mu + repmat(w,1,size(newZ,2)).*...
                repmat(newZ(ind,:),size(w,1),1);
            
            denom = (newZ(ind,:)*newZ(ind,:)');
            temp = newZ(ind,:)';
            for k = 1: size(fullZ,1)
                w = (newZ(k,:)*temp)/denom;
                newZ(k,:) =  newZ(k,:) - w*newZ(ind,:);
            end
            %allw(ind) = w;
            
            if j>posThresh-1
            if sum(akaikeDir(j-posThresh+1:j)) == posThresh
                break;
            end
            end
        end
        j = j+1;
        resid = fullX-mu;
        SSE = resid(:)'*resid(:);

        akaike(j) = numel(resid)*log(SSE/numel(resid))+...
            size(fullX,1)*(j-1)*log(numel(resid));
        akaikeFeatLoss(j) = size(fullX,1)*(j-1)*log(numel(resid));
        akaikeErrLoss(j) = numel(resid)*log(SSE/numel(resid));
        
        [~,ind] = min(akaike);
        ind = ind-1;
        
        channels = actives(1:ind);
end