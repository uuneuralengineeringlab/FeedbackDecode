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