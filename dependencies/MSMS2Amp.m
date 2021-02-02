function Amp = MSMS2Amp(MSMSContactVals,MSMSContactLabels,MSMSMotorVals,MSMSMotorLabels,StimCell)

Region = StimCell{1};
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});

IdxContact = strcmp(Region,MSMSContactLabels);
IdxMotor = strcmp(Region,MSMSMotorLabels);

Amp = 0;
if any(IdxContact)
    Amp = MSMSContactVals(IdxContact);
elseif any(IdxMotor)
%     NormVal = abs(MSMSMotorVals(IdxMotor));
    NormVal = (MSMSMotorVals(IdxMotor)+1)/2;
    NormVal(NormVal<0) = 0;
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Amp = NormVal*(MaxAmp-MinAmp) + MinAmp;   
    end
end