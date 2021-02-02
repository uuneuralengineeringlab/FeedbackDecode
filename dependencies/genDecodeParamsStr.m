function DecodeParamsStr = genDecodeParamsStr(Features,Kinematics,TRAIN,Gain,Threshold,BaseLoopTime,IntSpeed,IntType)

AStr = 'A=[';
WStr = 'W=[';
GainStr = 'Gain=[';
ThreshStr = 'Thresh=[';
for k=1:size(TRAIN.A,1) %number of kinematics
    tmpA = regexprep(num2str(TRAIN.A(k,:)),'\s+',',');
    tmpW = regexprep(num2str(TRAIN.W(k,:)),'\s+',',');
    tmpGain = regexprep(num2str(Gain(k,:)),'\s+',',');
    tmpTheshold = regexprep(num2str(Threshold(k,:)),'\s+',',');
    
    if k<size(TRAIN.A,1)
        AStr = [AStr,tmpA,';'];
        WStr = [WStr,tmpW,';'];
        GainStr = [GainStr,tmpGain,';'];
        ThreshStr = [ThreshStr,tmpTheshold,';'];
    else
        if size(TRAIN.A,1)>1
            AStr = [AStr,tmpA,';'];
            WStr = [WStr,tmpW,';'];
            GainStr = [GainStr,tmpGain,';'];
            ThreshStr = [ThreshStr,tmpTheshold,';'];
        else
            AStr = [AStr,tmpA];
            WStr = [WStr,tmpW];
            GainStr = [GainStr,tmpGain];
            ThreshStr = [ThreshStr,tmpTheshold];
        end
    end
end
AStr = [AStr,'];'];
WStr = [WStr,'];'];
GainStr = [GainStr,'];'];
ThreshStr = [ThreshStr,'];'];


HStr = 'H=[';
QStr = 'Q=[';
for k=1:size(TRAIN.H,1) %number of features
    tmpH = regexprep(num2str(TRAIN.H(k,:)),'\s+',',');
    tmpQ = regexprep(num2str(TRAIN.Q(k,:)),'\s+',',');
    
    if k<size(TRAIN.H,1)
        HStr = [HStr,tmpH,';'];
        QStr = [QStr,tmpQ,';'];
    else
        if size(TRAIN.H,1)>1
            HStr = [HStr,tmpH,';'];
            QStr = [QStr,tmpQ,';'];
        else
            HStr = [HStr,tmpH];
            QStr = [QStr,tmpQ];
        end
    end
end
HStr = [HStr,'];'];
QStr = [QStr,'];'];

% DecodeParamsStr = [['Features=[',regexprep(num2str((Features-192)'),'\s+',','),'];'],['Kinematics=[',regexprep(num2str(Kinematics),'\s+',','),'];'],AStr,WStr,HStr,QStr,GainStr,ThreshStr,['BaseLoopTime=[',num2str(BaseLoopTime),'];'],['IntSpeed=[',num2str(IntSpeed),'];'],['IntType=[''',IntType,'''];']];
DecodeParamsStr = [['Features=[',regexprep(num2str((Features-192)'),'\s+',','),'];'],AStr,WStr,HStr,QStr,GainStr,ThreshStr];


