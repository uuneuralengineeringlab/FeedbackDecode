function Amp = VRESensor2Amp_step(VREContactValues,VREContactLabels,VREMotorValues,VREMotorLabels,VREMotorLimits,StimCell,varargin)

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
            NormVal = ContactVal/200;     %200 is assumed max force?
        end
    end
elseif any(IdxMotor)
    lims = VREMotorLimits(IdxMotor,:);
    NormVal = (VREMotorValues(IdxMotor)-lims(1))/diff(lims);
end
NormVal(NormVal<0) = 0;
NormVal(NormVal>1) = 1;

if NormVal>0
    if NormVal < (10/200)           %Step function: 0<low<15N, 15<medium<40,  40<high
        Amp = MinAmp;
    elseif NormVal >= (10/200) && NormVal < (60/200)        %divide all by 200 since force was normalized by 200
        Amp = (MaxAmp - MinAmp)/2 + MinAmp;
    elseif NormVal >= (60/200)
        Amp = MaxAmp;
    end
else
    Amp = 0;
end

% DK added on 20171027 for personal analysis
function BufferedContactVals = VRESensorBuffer(ContactVals)

persistent MaxMat
persistent MaxIdx

blength = 5;

if isempty(MaxMat)
   MaxMat = zeros(length(ContactVals),blength); 
   MaxIdx = 1;
end

MaxMat(:,MaxIdx) = ContactVals;
MaxIdx = MaxIdx + 1;
if MaxIdx>blength
    MaxIdx = 1;
end

BufferedContactVals = max(MaxMat,[],2);