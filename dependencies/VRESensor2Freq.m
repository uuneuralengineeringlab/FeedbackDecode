function Freq = VRESensor2Freq(VREContactValues,VREContactLabels,VREMotorValues,VREMotorLabels,VREMotorLimits,StimCell,varargin)

BufferedContactVals = VRESensorBuffer(VREContactValues);

Region = StimCell{1};
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});

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
    Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;
else
    Freq = 0;
end