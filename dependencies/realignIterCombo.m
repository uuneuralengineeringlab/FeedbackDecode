function [newKine,feat] = realignIter(kine,feat,varargin)

allKine = sum(abs(kine),1);
% [~,kineCenters] = findpeaks(allKine);
kineCenters = findpeaks(allKine);
kineCenters = kineCenters.loc;

windCon = 28;

if numel(varargin)>0
    centers = varargin{1};
else
   centers = kineCenters; 
end

newKine = zeros(size(kine));
newerKine = zeros(size(kine));    

for i = 1:numel(centers)
    
    kineWind = kineCenters(i)-windCon:kineCenters(i)+windCon;
    featWind = centers(i)-windCon:centers(i)+windCon;
    if kineWind(1)< 1
        kineWind = kineWind-kineWind(1)+1;
    end
    if kineWind(end)>size(kine,2)
        kineWind = kineWind -(kineWind(end)-size(kine,2));
    end
    
     if featWind(1)< 1
        featWind = featWind-featWind(1)+1;
    end
    if featWind(end)>size(kine,2)
        featWind = featWind -(featWind(end)-size(kine,2));
    end
    
    newKine(:,featWind) = kine(:,kineWind);
end

%ind = find(allKine>1);

%if ~isempty(ind)
%    comboKine = newKine(:,ind(1)-windCon:end);
%    comboFeat = feat(:,ind(1)-windCon:end);
    
%    newKine(:,ind(1)-windCon:end) = [];
%    feat(:,ind(1)-windCon:end) = [];
%end
    
for j = 1:10
    [~,kCen] = findpeaks(sum(abs(newKine)),'MINPEAKHEIGHT',.99);    % smw note, shouuld use KEF file for finding trial centers
    
    for i = 1:size(newKine,1)
        w = newKine(i,:)/feat;
        estX(i,:) = w*feat;
        MSE(i,j) = sum((newKine(i,:)-estX(i,:)).^2);
    end
        
    lags = -6:6;

    newerKine = zeros(size(kine));            
    for k = 1:numel(kCen)
        wind = kCen(k)-windCon:kCen(k)+windCon;

        while lags(1)+wind(1)<1
            wind(1) = [];
        end
        while lags(end)+wind(end)>size(estX,2)
            wind(end) = [];
        end

        for l = 1:numel(lags)
            estWind = wind+lags(l);
            lagMse(l) = sum(sum((newKine(:,wind)-estX(:,estWind)).^2));
        end
        [~,minLag] = min(lagMse);
        newerKine(:,wind+lags(minLag)) = newKine(:,wind);
    end
    newKine = newerKine;
    
end
end

