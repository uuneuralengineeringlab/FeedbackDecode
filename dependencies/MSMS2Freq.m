function Freq = MSMS2Freq(MSMSContactVals,MSMSContactLabels,MSMSMotorVals,MSMSMotorLabels,StimCell)

Region = StimCell{1};
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});

IdxContact = strcmp(Region,MSMSContactLabels);
IdxMotor = strcmp(Region,MSMSMotorLabels);

Freq = 0;
if any(IdxContact)
    Freq = MSMSContactVals(IdxContact);
elseif any(IdxMotor)
%     NormVal = abs(MSMSMotorVals(IdxMotor));
    NormVal = (MSMSMotorVals(IdxMotor)+1)/2;
    NormVal(NormVal<0) = 0;
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;   
    end
end

