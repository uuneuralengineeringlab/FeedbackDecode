function Amp = PHand2Amp(PHandContactVals,PHandContactLabels,PHandMotorVals,PHandMotorLabels,StimCell)

Region = StimCell{1};
MinAmp = str2double(StimCell{4});
MaxAmp = str2double(StimCell{5});

IdxContact = strcmp(Region,PHandContactLabels);
IdxMotor = strcmp(Region,PHandMotorLabels);

Amp = 0;
if any(IdxContact)
    NormVal = PHandContactVals(IdxContact)/10;
%     if strcmp(Region, 'palm_pinky')
%         NormVal(NormVal<0.13) = 0;
%     else
%         NormVal(NormVal<0.06) = 0;
%     end
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Amp = NormVal*(MaxAmp-MinAmp) + MinAmp;   
    end
elseif any(IdxMotor)
    NormVal = PHandMotorVals(IdxMotor)/255;
    NormVal(NormVal<0) = 0;
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Amp = NormVal*(MaxAmp-MinAmp) + MinAmp;   
    end
end

