function Amp = VRESensor2Amp(VREContactValues,VREContactLabels,VREMotorValues,VREMotorLabels,VREMotorLimits,StimCell,varargin)

BufferedContactVals = VRESensorBuffer(VREContactValues);

Region = StimCell{1};
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});

IdxContact = strcmp(Region,VREContactLabels);
IdxMotor = strcmp(Region,VREMotorLabels);

NormVal = 0;
if any(IdxContact)
    ContactVal = BufferedContactVals(IdxContact);
    NormVal = ContactVal/20; %MPL
    if ~isempty(varargin)
        if strcmp(varargin{1},'Luke')
            NormVal = ContactVal/200;
        end
    end
elseif any(IdxMotor)
    lims = VREMotorLimits(IdxMotor,:);
    NormVal = (VREMotorValues(IdxMotor)-lims(1))/diff(lims);
end
NormVal(NormVal<0) = 0;
NormVal(NormVal>1) = 1;

if NormVal>0
    Amp = NormVal*(MaxAmp-MinAmp) + MinAmp;
else
    Amp = 0;
end