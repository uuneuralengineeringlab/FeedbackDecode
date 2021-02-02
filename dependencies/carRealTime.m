function D = carRealTime(D,SurrChans)

% Dcar = zeros(size(D));
% for k=1:96
%     Dcar(:,k) = D(:,k) - mean(D(:,SurrChans{k}),2);
% end


D = D-(D*SurrChans);

