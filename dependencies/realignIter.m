function [newKine,feat] = realignIter(kine,feat,varargin)

allKine = sum(abs(kine),1);
[~,kineCenters] = findpeaks(allKine);

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

ind = find(allKine>1);

if ~isempty(ind)
    newKine(:,ind(1)-windCon:end) = [];
    feat(:,ind(1)-windCon:end) = [];
end
    
for i = 1:size(newKine,1)
    for j = 1:10
        w = newKine(i,:)/feat;
        estX = w*feat;
        MSE(j) = sum((newKine(i,:)-estX).^2);
        [~,kCen] = findpeaks(abs(newKine(i,:)),'MINPEAKHEIGHT',.99);
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
                lagMse(l) = sum((newKine(i,wind)-estX(estWind)).^2);
            end
            [~,minLag] = min(lagMse);
            newerKine(i,wind+lags(minLag)) = newKine(i,wind);
        end
        newKine(i,:) = newerKine(i,:);
    end
end