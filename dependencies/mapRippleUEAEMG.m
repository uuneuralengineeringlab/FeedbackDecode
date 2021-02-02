function vout = mapRippleUEAEMG(vin,mode, varargin)

% Works when two arrays are attached to Ports A/B with an optional 32
% channel (i.e. EMG) headstage attached to Port C
%  Mode = 'e2i', 'i2e' etc.  
% mapname = 'haptix' (passive gators) or 'haptixActive' (active gators)
% updated for ripple gator connectors 8/31/15 smw 
if nargin > 1
    mapname = varargin{1};
else
    mapname = 'haptix'; % passive gator
end

vin = vin(:);
vout = nan(length(vin),1);
lut = [257,193,292;258,194,282;259,195,272;260,196,262;261,197,293;262,198,283;263,199,273;264,200,263;265,201,294;266,202,284;267,203,274;268,204,264;269,205,295;270,206,285;271,207,275;272,208,265;273,209,296;274,210,286;275,211,276;276,212,266;277,213,297;278,214,287;279,215,277;280,216,267;281,217,298;282,218,288;283,219,278;284,220,268;285,221,299;286,222,289;287,223,279;288,224,269]; %col: channel, index, electrode

for k=1:length(vin)
    switch mode
        case 'e2c'
            if vin(k)>200
                c = lut(vin(k)==lut(:,3),2);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 128*floor((vin(k)-1)/100) + e2c(rem((vin(k)-1),100)+1,mapname);
            end
        case 'c2e'
            if vin(k)>256
                c = lut(vin(k)==lut(:,1),3);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 100*floor(vin(k)/128) + c2e(rem(vin(k),128),mapname);
            end
        case 'c2i'
            if vin(k)>256
                c = lut(vin(k)==lut(:,1),2);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 96*floor(vin(k)/128) + rem(vin(k),128);
            end
        case 'i2c'
            if vin(k)>192
                c = lut(vin(k)==lut(:,2),1);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 128*floor((vin(k)-1)/96) + (rem((vin(k)-1),96)+1);
            end
        case 'e2i'
            if vin(k)>200
                c = lut(vin(k)==lut(:,3),2);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 96*floor((vin(k)-1)/100) + e2c(rem((vin(k)-1),100)+1,mapname);
            end
        case 'i2e'
            if vin(k)>192
                c = lut(vin(k)==lut(:,2),3);
                if ~isempty(c)
                    vout(k) = c;
                end
            else
                vout(k) = 100*(floor((vin(k)-1)/96)) + c2e(rem((vin(k)-1),96)+1, mapname);
            end
    end
end











