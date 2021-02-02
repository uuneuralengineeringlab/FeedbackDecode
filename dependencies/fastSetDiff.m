function [z,zidx] = fastSetDiff(x,y)

% Author: Tyler Davis
% Version: 20160411

xy = x(:)*(1./reshape(y,1,[]));
xy = round(xy.*1e4)./1e4;

zidx = find(all(xy~=1,2));
z = x(zidx);

[z,idx] = sort(z);
zidx = zidx(idx);