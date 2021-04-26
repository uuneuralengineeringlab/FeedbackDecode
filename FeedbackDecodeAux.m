function FeedbackDecodeAux

SS = initSystem;

while SS.Run        
    MLStr = fscanf(SS.UDPEvntAux);
    if isempty(MLStr)
        disp('Timeout...')
    else
        try
            MLCell = regexp(MLStr,':','split');
            eval(MLCell{length(MLCell)}); %saving variables directly to SS structure
            disp(MLStr)
            switch MLCell{1}
                case 'CalibrateDEKA'
                    DEKABLSensors = calibrateDEKA();
%                     DEKABLSensors = calibrateDEKA_wristp();
                    SS.EvntStr = sprintf('CalibrateDEKAFinished:SS.DEKABLSensors=''%s'';',DEKABLSensors);
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished calibrating DEKA')    
                case 'AlignData' %currently not active
                    switch SS.AlignType
                        case 'Global'      
                            SS.KDFTrainFile = regexprep(SS.KDFTrainFile,'@',':');
                            SS.KEFTrainFile =  regexprep(SS.KDFTrainFile,'.kdf$','.kef');
                            [SS.X,SS.Z,SS.K, SS.T,SS.KDFTimes,SS.TrialStruct] = parseTrainingData(SS.KEFTrainFile,SS.KDFTrainFile);
                            [Mvnts,Idxs,MaxLag] = autoSelectMvntsChsCorr_FD(SS.X,SS.Z,SS.AutoThresh,SS.BadKalmanIdxs); %if KalmanType is ReFit, run in velocity mode
                            SS.Z = circshift(SS.Z, MaxLag,2);
                            SS.KDFTrainAlignedFile = regexprep(SS.KDFTrainFile, 'TrainingData', 'TrainingAligned_Global');
                        case 'TrialByTrial'
                            % align data (takes ~95sec on rack computer) % note, to
                            disp('Trial by trial data alignment....');
                            SS.KEFTrainFile =  regexprep(SS.KDFTrainFile,'.kdf$','.kef');
                            [SS.X,SS.Z,SS.K,SS.T,SS.KDFTimes,SS.TrialStruct] = parseTrainingData(SS.KEFTrainFile,SS.KDFTrainFile);
                            [SS.X,SS.Z] = realignIterCombo(SS.X,SS.Z);%
                            MaxLag = 0;
                            SS.KDFTrainAlignedFile = regexprep(SS.KDFTrainFile, 'TrainingData', 'TrainingAligned_TrialByTrial');
                    end
                    % write TrainingAligned_*.kdf

                    SS.KDFTrainAlignedFID = fopen(SS.KDFTrainAlignedFile,'w+');
                    fwrite(SS.KDFTrainAlignedFID,[1;size(SS.Z,1);size(SS.X,1);size(SS.T, 1);size(SS.K, 1)],'single'); %writing header
                    fwrite(SS.KDFTrainAlignedFID,[SS.KDFTimes,SS.Z',SS.X',SS.T',SS.K']','single');
                    fclose(SS.KDFTrainAlignedFID);          
                    SS.EvntStr = sprintf('AlignData:SS.KDFTrainFile=''%s'';SS.Lag=%0.0f;', regexprep(SS.KDFTrainAlignedFile,':','@'),MaxLag);
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with training data alignment');
                    
                case 'AutoPopStandard' % original 'AutoPop'
                    SS.KDFTrainFile = regexprep(SS.KDFTrainFile,'@',':');
                    SS.KEFTrainFile =  regexprep(SS.KDFTrainFile,'.kdf$','.kef');
%                     [SS.X,SS.Z,~,~,SS.KDFTimes,SS.TrialStruct] = parseTrainingData(SS.KEFTrainFile,SS.KDFTrainFile);
                    [SS.X,SS.Z,~,~,SS.KDFTimes,SS.TrialStruct] = parseTrainingData_RandTrials(SS.KEFTrainFile,SS.KDFTrainFile);
                    [Mvnts,Idxs,MaxLag] = autoSelectMvntsChsCorr_FD(SS.X,SS.Z,SS.AutoThresh,SS.BadKalmanIdxs); %if KalmanType is ReFit, run in velocity mode                    
                    SS.KalmanElects = mapRippleUEA(Idxs(Idxs>=1 & Idxs<=192),'i2e',SS.MapType.Neural);
                    SS.KalmanEMG = (Idxs(Idxs>=193 & Idxs<=272)-192)+200;
                    SS.KEMGExtra = (Idxs(Idxs>272)-192)+200;
                    SS.KalmanMvnts = find(any(Mvnts,2));
                    SS.KalmanGain = Mvnts(SS.KalmanMvnts,:);
                    SS.EvntStr = sprintf('AutoPop:KalmanElects=%s;KalmanEMG=%s;KEMGExtra=%s;KalmanMvnts=%s;KalmanGain=%s;Lag=%0.0f;',regexprep(num2str(SS.KalmanElects(:)'),'\s+',','),regexprep(num2str(SS.KalmanEMG(:)'),'\s+',','),regexprep(num2str(SS.KEMGExtra(:)'),'\s+',','),regexprep(num2str(SS.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(SS.KalmanGain(:)'),'\s+',','),MaxLag);                    
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with Standard auto channel selection')    
                    
                case 'AutoPopStepwise'
                    % smw to do: use TrialAlignedData_....kdf instead of
                    % autoSelectMvts...
                    % from main loop: fwrite(SS.UDPEvntAux,sprintf('AutoPopStepwise:SS.KDFTrainFile=''%s'';SS.AutoThresh=%0.2f;SS.BadKalmanIdxs=[%s];',regexprep(SS.KDFTrainFile,':','@'),SS.AutoThresh,regexprep(num2str(SS.BadKalmanIdxs(:)'),'\s+',',')))
                    disp('Starting Gram-Schmidt auto channel selection')
                    SS.KDFTrainFile = regexprep(SS.KDFTrainFile,'@',':');
                    SS.KEFTrainFile =  regexprep(SS.KDFTrainFile,'.kdf$','.kef');
                    [SS.X,SS.Z,~,~,SS.KDFTimes,SS.TrialStruct] = parseTrainingData(SS.KEFTrainFile,SS.KDFTrainFile);
                    [~,~,MaxLag,ZShift] = autoSelectMvntsChsCorr_FD(SS.X,SS.Z,SS.AutoThresh,SS.BadKalmanIdxs); %if KalmanType is ReFit, run in velocity mode
                    Mvnts = [any(SS.X>0,2),any(SS.X<0,2)];
%                     IdxsCell = AkaikeGramSchmChanSelv300(SS.X,ZShift,find(any(Mvnts,2))',floor(SS.AutoThresh*720)); % smw modified last input to limit num channels based on autopop thresh
                    IdxsCell = AkaikeGramSchmChanSelv300_orig05112016(SS.X,ZShift,find(any(Mvnts,2))',floor(SS.AutoThresh*720)); % smw modified last input to limit num channels based on autopop thresh
                    Idxs = unique(cell2mat(IdxsCell));                    
%                     [Mvnts,Idxs] = autoSelectMvntsChsStepWise(SS.Z',SS.X',SS.KDFTimes,SS.TrialStruct);                    
                    Idxs = setdiff(Idxs, SS.BadKalmanIdxs); % remove user selected bad channels
                    SS.KalmanElects = mapRippleUEA(Idxs(Idxs>=1 & Idxs<=192),'i2e',SS.MapType.Neural);
                    SS.KalmanEMG = (Idxs(Idxs>=193 & Idxs<=272)-192)+200;
                    SS.KEMGExtra = (Idxs(Idxs>272)-192)+200;
                    SS.KalmanMvnts = find(any(Mvnts,2));
                    SS.KalmanGain = Mvnts(SS.KalmanMvnts,:);
                    SS.EvntStr = sprintf('AutoPop:KalmanElects=%s;KalmanEMG=%s;KEMGExtra=%s;KalmanMvnts=%s;KalmanGain=%s;Lag=%0.0f;',regexprep(num2str(SS.KalmanElects(:)'),'\s+',','),regexprep(num2str(SS.KalmanEMG(:)'),'\s+',','),regexprep(num2str(SS.KEMGExtra(:)'),'\s+',','),regexprep(num2str(SS.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(SS.KalmanGain(:)'),'\s+',','),MaxLag);
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with Gram-Schmidt auto channel selection')   
                    
                case 'AutoPopGram' % smw 1/10/17 uses new Gram-Schmidt and trial by trial alighment                    
                    % idea: spit out rank of movements after trial
                    % algignment
                    % smw to do: use TrialAlignedData_....kdf instead of
                    % autoSelectMvts...
                    tic
                    disp('Starting Gram-SchmidtDarpa auto channel selection...')
                    SS.KDFTrainFile = regexprep(SS.KDFTrainFile,'@',':');
                    SS.KEFTrainFile =  regexprep(SS.KDFTrainFile,'.kdf$','.kef');
                    
                    [SS.X,SS.Z,SS.Xhat,SS.T,SS.KDFTimes,SS.TrialStruct] = parseTrainingData_RandTrials(SS.KEFTrainFile,SS.KDFTrainFile);
%                     [SS.X,SS.Z,SS.Xhat,SS.T,SS.KDFTimes,SS.TrialStruct] = parseTrainingData(SS.KEFTrainFile,SS.KDFTrainFile);
                    Mvnts = [any(SS.X>0,2),any(SS.X<0,2)];
                    
%                     SS.Z(1:192,:) = 0; % USES EMG ONLY!!! **
                  
                    [~,~,MaxLag,ZShift] = autoSelectMvntsChsCorr_FD(SS.X,SS.Z,SS.AutoThresh,SS.BadKalmanIdxs); % if data align method is method is standard                    
                  
                    % channel select
                    SS.maxchans = 48; % may pass this through from LV at some point
                    IdxsCell = gramSchmDarpa(SS.X,ZShift,[1:length(Mvnts)],SS.maxchans, 0);
                    Idxs = unique(cell2mat(IdxsCell));
                    
                    Idxs = setdiff(Idxs, SS.BadKalmanIdxs); % remove user selected bad channels
                    SS.KalmanElects = mapRippleUEA(Idxs(Idxs>=1 & Idxs<=192),'i2e',SS.MapType.Neural);
                    SS.KalmanEMG = (Idxs(Idxs>=193 & Idxs<=272)-192)+200;
                    SS.KEMGExtra = (Idxs(Idxs>272)-192)+200;
                    SS.KalmanMvnts = find(any(Mvnts,2));
                    SS.KalmanGain = Mvnts(SS.KalmanMvnts,:);

                    SS.EvntStr = sprintf('AutoPop:KalmanElects=%s;KalmanEMG=%s;KEMGExtra=%s;KalmanMvnts=%s;KalmanGain=%s;Lag=%0.0f;',regexprep(num2str(SS.KalmanElects(:)'),'\s+',','),regexprep(num2str(SS.KalmanEMG(:)'),'\s+',','),regexprep(num2str(SS.KEMGExtra(:)'),'\s+',','),regexprep(num2str(SS.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(SS.KalmanGain(:)'),'\s+',','),MaxLag);
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with Gram-SchmidtDarpa auto channel selection');
                    disp('Time_Align_AutoPopGS:')
                    toc
                case 'GenVRWeights' % Virtual rereference weight generation
                    SS.CARFile = regexprep(SS.CARFile,'@',':');
                    Data = readRDF(SS.CARFile);
                    weightsMatrix = createCARWeightsMatrix(Data');
                    SS.WeightsFile = regexprep(regexprep(SS.CARFile, 'CARData_', 'VRWeights_'), '.rdf', '.mat');
                    save(SS.WeightsFile,'weightsMatrix', '-mat');
                    SS.EvntStr = sprintf('GenVRWeights:SS.WeightsFile=''%s'';', regexprep(SS.WeightsFile, ':', '@'));
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with CAR weights matrix generation')
                case 'KalmanTrainStandard'
                    disp('KalmanTrainStandard called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file') % 
                            if ~isempty(strfind(TF.KDFTrainFile,'TrainingAligned'))% for using trial by trial aligned data
                                [subX,subZ,subT,subK,NIPTime] = readKDF(TF.KDFFile); % 
                                subX = subX(TF.KalmanMvnts,:); 
                                subZ = subZ(TF.KalmanIdxs,:);
                                subZ = circshift(subZ,TF.Lag,2); % uses additional lag if specified by user on LV   
                                
                            else % standard method, reparses data with lag from LV
%                                 [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                                [subX,subZ,subK,subT] = parseTrainingData_RandTrials(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                                
                            end
                            TRAIN = kalman_train(subX,subZ);
                            % Steady State Kalman Filter Train
%                             try
%                                 SSTRAIN = kalman_trainSS(subX,subZ);
%                                 save(SS.TrainParamsFile,'-append','SSTRAIN')
%                                 disp('KalmanTrainSteadyState also trained')
%                             catch 
%                                 disp('SSTRAIN failed');
%                             end
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr);
                            disp('KalmanTrainStandard finished')
                        end
                    end                                        
                case 'KalmanTrainMean'
                    tic
                    disp('KalmanTrainMean called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file')
%                             [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                            [subX,subZ,subK,subT] = parseTrainingData_RandTrials(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag);
                            TRAIN = kalman_train_bias(subX,subZ);
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('KalmanTrainMean finished')
                        end
                    end
                    disp('TimeTrain:')
                    toc
                case 'KalmanTrainRefit'
                    disp('KalmanTrainRefit called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file')
                            [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                            if TF.ReTrain
                                TRAIN = kalman_train_vel(subK,subZ,subT,TF.TargRad);
                            else
                                TRAIN = kalman_train_vel(subX,subZ);
                            end
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('KalmanTrainRefit finished')
                        end
                    end
                case 'KalmanTrain_DWPRR'  % smw 1/10/17 not complete
                    disp('KalmanTrain_DWPRR called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file')
%                             [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                            [subX,subZ,subK,subT] = parseTrainingData_RandTrials(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                            
                            minZ = min(subZ,[],2);
                            tempZ = subZ-repmat(minZ,1,size(subZ,2));
%                             tempZ = nthroot(tempZ,3);
                            normalizerZ = max(tempZ,[],2);
                            tempZ = tempZ./repmat(normalizerZ,1,size(tempZ,2));
                            tempZ = nthroot(tempZ,3);
                            tempZ = [tempZ; ones(1,size(tempZ,2))];
                            tempX = subX;
                            tempXPos = zeros(size(tempX));
                            tempXNeg = zeros(size(tempX));
                            tempXPos(tempX >= 0) = tempX(tempX >= 0);
                            tempXNeg(tempX < 0) = tempX(tempX < 0); % note, if there are all zero rows, remove
                            tempX = [tempXPos; tempXNeg];
                            clear w trainEst; 
                            for iDWPRR = 1:size(tempX,1)
                                w(:,iDWPRR) = DWPRR(tempX(iDWPRR,:),tempZ,TF.FreeParam);
                                trainEst(iDWPRR,:) = (w(:,iDWPRR)'*tempZ).^3;
                            end
                            TRAIN = kalman_train(subX,trainEst);
                            
                          %a =
                          % kalman_test(trainEst(:,1),TRAIN,[-1./KalmanGain(:,2),1./KalmanGain(:,1)],1);%
                          %init - happens in feedbackdecode.m resetKalman
                            
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN', 'minZ', 'w', 'trainEst', 'normalizerZ');
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('KalmanTrain_DWPRR finished')
                        end
                    end                                        
                case 'LinSVReg_train'
                    disp('LinSVReg_train called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file')
                            [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input                            
                            %TRAIN = LinSVReg_train(subX,subZ); % generates SVM PARAM struct
                            TRAIN = kalman_train_biasJN(subX,subZ);
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('Finished with LinSVReg_train')
                        end
                    end                
                case 'NonLinSVReg_train'
                    disp('NonLinSVReg_train called')
                    SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                    TF = load(SS.TrainParamsFile);
                    if isfield(TF,'KDFTrainFile')
                        if exist(TF.KDFTrainFile,'file')
                            [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input                            
                            TRAIN = NonLinSVReg_train(subX,subZ); % generates SVM PARAM struct
                            save(SS.TrainParamsFile,'-append','subX','subZ','subK','subT','TRAIN')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('Finished with NonLinSVReg_train')
                        end
                    end   
                case 'StartBakeoff'
                    mj_close;
                    disp('Starting Bakeoff...')
                    switch SS.TestType
                        case 'Bakeoff11'
                            result = Bakeoff_Task11(SS.UDPContAux); % result should be a 3 x num trials (12) matrix for bakeoff1
                        case 'Bakeoff21'
                            result = Bakeoff_Task21(SS.UDPContAux);
                        case 'Bakeoff31'
                            result = Bakeoff_Task31(SS.UDPContAux);
                        case 'Bakeoff32'
                            result = Bakeoff_Task32(SS.UDPContAux); 
                        case 'Bakeoff32_Ball'
                            result = Bakeoff_Task32_BallPinch(SS.UDPContAux);
                        case 'Bakeoff32_Checkers'
                            result = Bakeoff_Task32_Checkers(SS.UDPContAux);
                        case 'Bakeoff32_Pen'
                            result = Bakeoff_Task32_Pen(SS.UDPContAux);
                        case 'FragileBlock'
%                             result = Fragile_Blocks_left(SS.UDPContAux); % DK - switched task for right hand (9/8/2017)
                            result = Fragile_Blocks_right(SS.UDPContAux);
                       
                    end
                    disp(result)
                    SS.EvntStr = sprintf('AuxBakeoffFinished:TestType=''%s'';result=[%s];',SS.TestType,regexprep(num2str(reshape(result',1,[])),'\s+',',')); % smw-send results back to main loop
                    fwrite(SS.UDPEvntAux,SS.EvntStr)
                    disp('Finished with Bakeoff...')
                    mj_close;
                case 'ExportTraining'
                    SS.ExportTrainFile = regexprep(SS.ExportTrainFile,'@',':');
                    try
                        xl_build('Compile2Nomad')
                        disp ('Training compiled to Nomad for testing')
                        try 
                            xl_build('Compile2Nomad_LF')
                            disp('Latching Filter Training compiled to Nomad for testing')
                        catch
                            disp('Latching Filter Training not compiled')
                        end
                    catch
                        disp ('Training failed to compile on the Nomad')
                    end
                     SS.EvntStr = sprintf('AuxCompile2NomadFinished:');
                     fwrite(SS.UDPEvntAux,SS.EvntStr)
                case 'NN_pythonTrain'   %train NN in python
                    % Starting python communication
                    python_path = '\\PNIMATLAB\PNIMatlab_R1\decodeenginepython_DO_NOT_DELETE';
                    if count(py.sys.path,python_path) == 0
                        insert(py.sys.path,int32(0),python_path);
                    end
                    try
                        disp('NN_python started training')
                        SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                        TF = load(SS.TrainParamsFile);
                        if isfield(TF,'KDFTrainFile')
                            if exist(TF.KDFTrainFile,'file')
                                [Kinematics,Features,~,~,NIPTime] = readKDF(TF.KDFTrainFile);
                                TrialStruct = parseKEF(TF.KEFTrainFile);
                                Kinematics = Kinematics(TF.KalmanMvnts,:);
                                Features = Features(TF.KalmanIdxs,:);
                                trainCombo = 1;   %train on combos
                                testCombo = 1;  %test on combos
                                trainPercent = 4/5;  % original was 80 percent
                                trainingType = 'shuffle';   % 'first' X percent. 'last' X percent. or 'shuffle' X percent.
                                if trainPercent == 1
                                    [trainmask,~] = separateTrials(Features,Kinematics,TrialStruct,NIPTime, ...
                                                                      trainCombo,testCombo,trainPercent,trainingType);
                                    trainPercent = 4/5; % 80 percent
                                    [~,testmask] = separateTrials(Features,Kinematics,TrialStruct,NIPTime, ...
                                                                      trainCombo,testCombo,trainPercent,trainingType);
                                else
                                    [trainmask,testmask] = separateTrials(Features,Kinematics,TrialStruct,NIPTime, ...
                                                                      trainCombo,testCombo,trainPercent,trainingType);
                                end
                                                                  


                                NN_Python.TRAIN = train_NN_python(Kinematics, Features, trainmask, testmask, '127.0.0.1', 12000, 1000);
                                NN_Python.TRAIN.subXTrain = Kinematics(:,trainmask);
                                NN_Python.TRAIN.subXTest = Kinematics(:,testmask);
                                NN_Python.TRAIN.subZTrain = Features(:,trainmask);
                                NN_Python.TRAIN.subZTest = Features(:,testmask);
                                NN_Python.TRAIN.subX = Kinematics;
                                NN_Python.TRAIN.subZ = Features;
                                disp('NN_python training finished')
                                disp('Initializing Model')
%                                 z_size =  size(NN_Python.TRAIN.subZ);
%                                 x_size =  size(NN_Python.TRAIN.subX);
%                                 xhat = test_NN_python(NN_Python.TRAIN.subZ(1,:),NN_Python.TRAIN.subX(1,:), NN_Python.TRAIN, 1, '//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/config.json', '//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/model.h5',  z_size(1), x_size(1));
                                disp('Model Initializaed')                                
                                
                                [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag);
                                TRAIN = TF.TRAIN;
                                save(SS.TrainParamsFile,'-append', 'subX', 'subZ', 'subK', 'subT', 'TRAIN', 'NN_Python')
                                SS.EvntStr = sprintf('AuxTrainingFinished:');
                                fwrite(SS.UDPEvntAux,SS.EvntStr)
                                disp('NN_python training complete')
                            end
                        end
                    catch ME
                        disp("Failed training NN python: Please check if the python socket is running and if the paths are right")
                        if isempty(ME.stack)
                            fprintf('message: %s\r\n',ME.message);
                        else
                            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
                        end                              
                    end
                    
                case 'NN_python_classifier_Train'   %train NN in python
                    % Starting python communication
                    python_path = '\\PNIMATLAB\PNIMatlab_R1\decodeenginepython_DO_NOT_DELETE';
                    if count(py.sys.path,python_path) == 0
                        %pyversion('C:\Users\Administrator\Anaconda3\envs\decode_env\pythonw.exe')
                        insert(py.sys.path,int32(0),python_path);
                    end
                    try
                        disp('NN_python MLP Classifier started training')
                        SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                        TF = load(SS.TrainParamsFile);
                        
                        if isfield(TF,'KDFTrainFile')
                            if exist(TF.KDFTrainFile,'file')
                            params_goal = csvread('//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/params_goal_estimator.csv');
                            config_trials = csvread('//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/movement_order.csv');
                            %LUT =  csvread('//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/LUT_movements_goal.csv');
                            window_size = params_goal(1);%10;
                            nbr_class = params_goal(2);%7+6;
                            fully_connected = params_goal(3);%128;
                            delay = params_goal(4);%0;
                            threshold = params_goal(5);%0.6;
                            lpf_coef = params_goal(6);
                            max_movement = params_goal(7);
                            lr = params_goal(8);
                            momentum = params_goal(9);
                            decay = params_goal(10);
                            ip = '127.0.0.1';
                            port = 12000;
                            timeout = 1000;
                            feature_path = 'C:\Users\Administrator\Code\General\MLP\features_training.csv';
                            labels_path = 'C:\Users\Administrator\Code\General\MLP\labels_training.csv';
                            
                            socket = py.socket_client.socket_client(ip, port, timeout);                                                                                                           
                            [Kinematics,Features,Targets,~,NIPTime] = readKDF(TF.KDFTrainFile);
                            TrialStruct = parseKEF(TF.KEFTrainFile);
                            Kinematics = Kinematics(TF.KalmanMvnts,:);
                            Features = Features(TF.KalmanIdxs,:);
                            
                            nbr_pcs = length(Features(:,1));
                            [labels, features] = generate_labels_for_classifier (Targets, Kinematics, Features, config_trials, 1, nbr_class, threshold);


                            csvwrite(feature_path,features)
                            csvwrite(labels_path,labels)

                            ans_client = socket.create_classification_model(nbr_pcs, window_size, nbr_class, fully_connected, lr, momentum, decay);
                            pause(0.1)
                            ans_client = socket.train_classifier(feature_path, labels_path, window_size, delay);
                            pause(0.1)
                            %NN_classifier_Python.TRAIN.socket = socket;
%                             NN_classifier_Python.TRAIN.trained = 1;
                            NN_classifier_Python_trained = 1;

                            disp('KalmanTrainStandard called')
                            SS.TrainParamsFile = regexprep(SS.TrainParamsFile,'@',':');
                            TF = load(SS.TrainParamsFile);
                            if ~isempty(strfind(TF.KDFTrainFile,'TrainingAligned'))% for using trial by trial aligned data
                                [subX,subZ,subT,subK,NIPTime] = readKDF(TF.KDFFile); % 
                                subX = subX(TF.KalmanMvnts,:); 
                                subZ = subZ(TF.KalmanIdxs,:);
                                subZ = circshift(subZ,TF.Lag,2); % uses additional lag if specified by user on LV   
                                
                            else % standard method, reparses data with lag from LV
%                                 [subX,subZ,subK,subT] = parseTrainingData(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                                [subX,subZ,subK,subT] = parseTrainingData_RandTrials(TF.KEFTrainFile,TF.KDFTrainFile,TF.KalmanMvnts,TF.KalmanGain,TF.KalmanIdxs,TF.Lag); %td: added lag as input
                                
                            end
                            TRAIN = kalman_train(subX,subZ);       
                            save(SS.TrainParamsFile,'-append', 'TRAIN','subX','subZ','subK','subT', 'NN_classifier_Python_trained', 'max_movement')
                            SS.EvntStr = sprintf('AuxTrainingFinished:');
                            fwrite(SS.UDPEvntAux,SS.EvntStr)
                            disp('NN_python MLP classifier training complete')
                                
                            end
                            
                        end
                        
                    catch ME 
                        
                        disp("Failed training MLP Classifier: Please check if the python socket is running and if the paths are right")
                        if isempty(ME.stack)
                            fprintf('message: %s\r\n',ME.message);
                        else
                            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
                        end 
                        
                    end
               
                case 'Stop'
                    SS.Run = 0;
                    disp('stopping...')
            end
        catch ME
            assignin('base','ME',ME)
            if isempty(ME.stack)
                fprintf('failed on labview command: %s\nmessage: %s\n',MLStr,ME.message);
            else
                fprintf('failed on labview command: %s\nmessage: %s\nname: %s\nline: %0.0f\n',MLStr,ME.message,ME.stack(1).name,ME.stack(1).line);
            end
        end
    end                    
end

closeSystem(SS);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = initSystem

delete(instrfindall);

% Opening network for UDP communication with auxillary matlab loop
warning('off','instrument:fscanf:unsuccessfulRead');

SS.UDPEvntAux = udp('127.0.0.1',9003,'localhost','127.0.0.1','localport',9004); %Sending/receiving string commands to auxillary matlab loop for delayed processing
SS.UDPEvntAux.InputBufferSize = 65535; SS.UDPEvntAux.InputDatagramPacketSize = 13107; SS.UDPEvntAux.OutputBufferSize = 65535; SS.UDPEvntAux.OutputDatagramPacketSize = 13107;

SS.UDPContAux = udp('127.0.0.1',9006,'localhost','127.0.0.1','localport',9007); %Sending/receiving continuous data for bakeoff tests
SS.UDPContAux.InputBufferSize = 65535; SS.UDPContAux.InputDatagramPacketSize = 13107; SS.UDPContAux.OutputBufferSize = 65535; SS.UDPContAux.OutputDatagramPacketSize = 13107;

fopen(SS.UDPEvntAux); 
fopen(SS.UDPContAux); 

SS.Run = 1;
fwrite(SS.UDPEvntAux,'MatlabAuxReady');


function closeSystem(SS)
assignin('base','SS',SS)
fclose(SS.UDPEvntAux); delete(SS.UDPEvntAux); mj_close;
clear all; close all; fclose all;
delete(instrfindall) % dk 1/29/2018
