function ARDAmp = VRESensor2ARD(VREContactValues,VREMotorValue,VREMotorLimit,varargin)

MinAmp = 55;
MaxAmp = 255;

NormVal = VREContactValues./20;
if ~isempty(varargin)
    if strcmp(varargin{1},'Luke')
        NormVal = VREContactValues./200;
    end
end
NormVal(6) = (VREMotorValue-VREMotorLimit(1))/diff(VREMotorLimit);

NormVal(NormVal<0) = 0;
NormVal(NormVal>1) = 1;

ARDAmp = floor(NormVal*(MaxAmp-MinAmp) + MinAmp);

ARDAmp(NormVal==0) = 0;

