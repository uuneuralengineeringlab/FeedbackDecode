function outFile = convertKDF_EMGPassive2ActiveMap(kdfFile)
% rearranges feature data from EMG which was recorded to kdf file with the
% passive map instead of the active map

outFile = regexprep(kdfFile, '.kdf$', '_remappedEMG.kdf');

[X,Z,T,K,KDFTimes] = readKDF(kdfFile); % read KDF file

ZEmg = Z(193:end, :);


[EMGMatrix,EMGChanPairs] = genEMGMatrix([]);

nanInd = isnan(EMGChanPairs(:,2));
temp = EMGChanPairs(:,2);
temp(~nanInd) =  p2a(EMGChanPairs(~nanInd,2));
p2aChanPairs = [p2a(EMGChanPairs(:,1)), temp];

lut = zeros(size(p2aChanPairs,1),1);
for k = 1:length(lut)
    if ~isnan(EMGChanPairs(k,2))
        lut(k) = find(((p2aChanPairs(k,1) == EMGChanPairs(:,1))| (p2aChanPairs(k,1) == EMGChanPairs(:,2))) &...
            (p2aChanPairs(k,2) == EMGChanPairs(:,2) | p2aChanPairs(k,2) == EMGChanPairs(:,1)) );
    else
        lut(k) = find(p2aChanPairs(k,1) == EMGChanPairs(:,1) & isnan(EMGChanPairs(:,2)));
    end
end


Zremapped = [Z(1:192,:); ZEmg(lut,:);];

% write data to new kdf file
FID = fopen(outFile,'w+');
fwrite(FID,[1;size(Z,1);size(X,1);size(T,1);size(K,1)],'single'); %writing header (1+(96*NumUEAs+528)+12+12+12)
for k = 1: length(KDFTimes)
    fwrite(FID,[KDFTimes(k);Zremapped(:,k);X(:,k);T(:,k);K(:,k)],'single'); %saving data to fTask file (*.kdf filespec, see readKDF)
end

fclose(FID);


