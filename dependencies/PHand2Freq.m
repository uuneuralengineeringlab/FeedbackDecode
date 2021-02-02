function Freq = PHand2Freq(PHandContactVals,PHandContactLabels,PHandMotorVals,PHandMotorLabels,StimCell)

Region = StimCell{1};
MinFreq = str2double(StimCell{6});
MaxFreq = str2double(StimCell{7});

IdxContact = strcmp(Region,PHandContactLabels);
IdxMotor = strcmp(Region,PHandMotorLabels);

Freq = 0;
if any(IdxContact)
    NormVal = PHandContactVals(IdxContact)/10;
%     if strcmp(Region, 'palm_pinky')
%         NormVal(NormVal<0.13) = 0;
%     else
%         NormVal(NormVal<0.06) = 0;
%     end
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;   
    end
elseif any(IdxMotor)
    NormVal = PHandMotorVals(IdxMotor)/255;
    NormVal(NormVal<0) = 0;
    NormVal(NormVal>1) = 1;
    if NormVal>0
        Freq = NormVal*(MaxFreq-MinFreq) + MinFreq;   
    end
end

