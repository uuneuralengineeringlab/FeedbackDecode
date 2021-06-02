function FeedbackDecode(LabviewIP)

% Starting log file
SS.RootDir = fileparts(mfilename('fullpath'));
SS.LogFID = fopen(fullfile(SS.RootDir,'FeedbackDecode_Log.txt'),'w+');

% Initializing system variables
try
    SS = initSystem(LabviewIP,SS);
catch ME
    fprintf(SS.LogFID,'message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
end

% Initializing timer
t = timer;
t.ExecutionMode = 'fixedRate';
t.Period = SS.BaseLoopTime;
t.TasksToExecute = 1e12;
t.BusyMode = 'drop';
t.TimerFcn = @mainLoop;
t.StopFcn = @closeSystem;

t.UserData = SS;
fprintf('starting timer\n');
start(t);
wait(t);
fprintf('finished timer\n');
% delete(t);

%%%%%%%%%%%%%%%%%%%%%%%%% Timer Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mainLoop(t,~)
try
    SS = t.UserData;
    SS.MCalcTic = double(xippmex_1_12('time'));
    SS = acqEvents(SS);
    if SS.Stop
        stop(t);
    end
    SS = acqData(SS);
    SS = acqAuxEvents(SS);
    SS = acqCont(SS);
    SS = acqTraining(SS);
    SS = acqBaseline(SS);
    SS = runTesting(SS); %SS.XHat
    SS = cogLoad(SS);
    SS = sendStim(SS);
    SS = saveContStim(SS);
    SS = saveTask(SS);
    SS = savePHand(SS);
    SS.MCalcTime = (double(xippmex_1_12('time'))-SS.MCalcTic)/30000; %calculation time within loop
    SS.MTotalTime = t.InstantPeriod; %overall loop time
    SS.LoopCnt = t.TasksExecuted;
    t.UserData = SS;
catch ME
    assignin('base','ME',ME)
    fprintf(SS.LogFID,'message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    t.UserData = SS;
    %     stop(t);
end

function closeSystem(t,~)
SS = t.UserData;
SS.RecEnd = double(xippmex_1_12('time')); %smw - get end NIP time for Synching purposes
SS = orderfields(SS);
assignin('base','SS',SS)
xippmex_1_12('stim','enable',0); pause(1);
try
    %     xippmex_1_12('trial',SS.XippOpers,'stopped'); pause(1);
    xippmex_1_12('trial','stopped'); pause(1);
catch
    disp('xippmex call to stop recording crashed...')
end
xippmex_1_12('close'); clear('xippmex_1_12'); mj_close;
SS.SSFile = fullfile(SS.FullDataFolder,['\SSStruct_',SS.DataFolder,'.mat']);
save(SS.SSFile,'SS');
fwrite(SS.UDPEvnt,'MatlabReady'); %Tell LV that matlab has shut down
fwrite(SS.UDPContAux,[zeros(6,1);0;SS.BakeoffDirect],'single')
fwrite(SS.UDPEvntAux,'Stop:'); %tell MLAux to stop
fclose(SS.UDPEvnt); fclose(SS.UDPEvntAux); fclose(SS.UDPCont); fclose(SS.UDPContAux); fclose(SS.TaskFID); fclose(SS.ContStimFID); fclose(SS.LogFID);
delete(SS.UDPEvnt); delete(SS.UDPEvntAux); delete(SS.UDPCont); delete(SS.UDPContAux);
if isfield(SS,'UDPNIP')
    fclose(SS.UDPNIP);
    delete(SS.UDPNIP);
end
if SS.ARD1.Ready; SS.ARD1.Ready = ctrlRBArduino; end
if SS.VTStruct.Ready; SS.VTStruct.Obj.close; end
if SS.ARD3.Ready; fclose(SS.ARD3.Obj); delete(SS.ARD3.Obj); end
if isfield(SS,'PHandFID'); fclose(SS.PHandFID); end
if SS.DEKA.Ready; lkmex('stop'); clear lkmex; end
if SS.TASKA.Ready; closeTASKA(SS.TASKA.Obj); delete(SS.TASKA.Obj); end % dk 2018-01-26
if SS.TASKASensors.Ready; closeTASKASensors_simple(SS.TASKASensors.Obj); delete(SS.TASKASensors.Obj); end % jag 7/26/18
if SS.ConnectECG
    if isfield(SS,'shimmerECG')
        ecgstop(SS.shimmerECG);
        pause(0.01);
        ecgdisconnect(SS.shimmerECG);
    end
end
if SS.ConnectIMU
    if isfield(SS,'shimmerIMU')
        for i = 2:length(SS.shimmerIMU)
            imudisconnect(SS.shimmerIMU(i));
        end
    end
end
fclose(SS.DEKAFID);
fclose(SS.TASKAFID);
fclose(SS.CogLoadFID);
% delete(t);
delete(instrfindall);
close all; fclose all;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%% Subfunctions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialization function
function SS = initSystem(LabviewIP,SS)

delete(instrfindall); delete(timerfindall);
xippmex_1_12('close'); clear('xippmex_1_12'); mj_close;

if strcmp(LabviewIP,'127.0.0.1')
    SS.LocalIP = '127.0.0.2';
else
    % Find local computer name
    [~,compstr] = system('powershell get-wmiobject -class win32_computersystem');
    SS.LocalComp = cell2mat(regexp(compstr,'Name\s+:\s([^\s]+)','tokens','once'));
    
    % Find ip address of local computer
    [~,netstr] = system('powershell ipconfig');
    stroffset = regexp(netstr,'Matlab_Network');
    SS.LocalIP = regexp(netstr(stroffset:end),'\d+\.\d+\.\d+\.\d+','match'); SS.LocalIP = SS.LocalIP{1};
end

% Saving LabviewIP to structure
SS.LabviewIP = LabviewIP;

% Opening network for UDP communication with LV
warning('off','instrument:fscanf:unsuccessfulRead');

SS.UDPEvnt = udp(SS.LabviewIP,9002,'localhost',SS.LocalIP,'localport',9002); %Sending/receiving string commands
SS.UDPEvnt.InputBufferSize = 65535; SS.UDPEvnt.InputDatagramPacketSize = 13107; SS.UDPEvnt.OutputBufferSize = 65535; SS.UDPEvnt.OutputDatagramPacketSize = 13107;

SS.UDPCont = udp(SS.LabviewIP,9005,'localhost',SS.LocalIP,'localport',9005); %Sending/receiving continuous
SS.UDPCont.InputBufferSize = 65535; SS.UDPCont.InputDatagramPacketSize = 13107; SS.UDPCont.OutputBufferSize = 65535; SS.UDPCont.OutputDatagramPacketSize = 13107;

fopen(SS.UDPEvnt);
fopen(SS.UDPCont);

% Opening network for UDP communication with auxiliary matlab loop
SS.UDPEvntAux = udp('127.0.0.1',9004,'localhost','127.0.0.1','localport',9003); %Sending/receiving string commands to auxiliary matlab loop for delayed processing
SS.UDPEvntAux.InputBufferSize = 65535; SS.UDPEvntAux.InputDatagramPacketSize = 13107; SS.UDPEvntAux.OutputBufferSize = 65535; SS.UDPEvntAux.OutputDatagramPacketSize = 13107;

SS.UDPContAux = udp('127.0.0.1',9007,'localhost','127.0.0.1','localport',9006); %Sending/receiving continuous data for bakeoff tests
SS.UDPContAux.InputBufferSize = 65535; SS.UDPContAux.InputDatagramPacketSize = 13107; SS.UDPContAux.OutputBufferSize = 65535; SS.UDPContAux.OutputDatagramPacketSize = 13107;

fopen(SS.UDPEvntAux);
fopen(SS.UDPContAux);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% COB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Opening network for UDP with NIP
% SS.UDPNIP = udp('192.168.42.1',5075,'localhost','192.168.42.132','localport',5076);
% SS.UDPNIP.InputBufferSize = 4096; SS.UDPNIP.InputDatagramPacketSize = 1024; SS.UDPNIP.OutputBufferSize = 4096; SS.UDPNIP.OutputDatagramPacketSize = 1024;
% SS.UDPNIP.ByteOrder = 'littleEndian';
% fopen(SS.UDPNIP);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Connecting to NIP
disp('Initializing NIP...')
SS = initNIP(SS);

% Reading initial event values from LV
fwrite(SS.UDPEvnt,'MatlabReady');  %fprintf writes a termination character (fwrite does not)
eval(fscanf(SS.UDPEvnt)); %SS.KalmanElects=[];SS.Lag=0;SS.KernelWidth=0.3;SS.DataFolder='';SS.BadUEAElects=[];SS.SelElect=1;SS.ThreshMode=0;SS.ThreshVal=-150;
% smw to do: list SS.Fields received from labview
% td: Added SS.Prosthesis (i.e. MaleLeft, MaleRight, etc.) from labview. Might want to do something with this variable?

% Initializing file structure variables
if isempty(SS.DataFolder); SS.DataFolder='00000000-000000'; end
SS.DataDir = regexprep(SS.DataDir,'@',':');
SS.BuildDir = regexprep(SS.BuildDir,'@',':');
SS.FullDataFolder = fullfile(SS.DataDir,SS.DataFolder);
if ~isfolder(SS.FullDataFolder)
    mkdir(SS.FullDataFolder)
end

% Parsing Map
switch SS.Map
    case 'pNeural/pEMG'
        SS.MapType.Neural = 'haptix';
        SS.MapType.EMG = 'passive';
    case 'pNeural/aEMG'
        SS.MapType.Neural = 'haptix';
        SS.MapType.EMG = 'active';
    case 'aNeural/pEMG'
        SS.MapType.Neural = 'haptixActive';
        SS.MapType.EMG = 'passive';
    case 'aNeural/aEMG'
        SS.MapType.Neural = 'haptixActive';
        SS.MapType.EMG = 'active';
    case 'N2021/pEMG'
        SS.MapType.Neural = 'haptix2021';
        SS.MapType.EMG = 'passive';
    otherwise
        disp('Incorrect map selected...')
        return;
end

if SS.StartMLAux
    % system('powershell start-process "D:\RemoteRepo\FeedbackDecodeAux.exe" -verb runAs');
    switch SS.NumComp
        case '1 Computer'
            system(['psexec -i -d -u Administrator -p UUNEL@CNC "',fullfile(SS.BuildDir,'FeedbackDecodeAux.exe"')]);
        otherwise
            system('psexec -i -d -u Administrator -p UUNEL@CNC D:\RemoteRepo\FeedbackDecodeAux.exe');
    end
else
    disp('Start auxiliary loop manually');
end

while 1
    MLAuxStr = fscanf(SS.UDPEvntAux);
    if strcmp(MLAuxStr,'MatlabAuxReady')
        break;
    else
        disp('Waiting for MatlabAux to start...')
    end
end

% opening connection with arduino
SS.ARD6.Ready = 0;
SS = connectARD(SS);
pause(2);

% initializing LEAP
SS.LEAP.Ready = 0;
SS = connectLEAP(SS);

% initializing cyberglove
SS.CyberGlove.Ready = 0;
SS.CyberGlove.Kinematics = zeros(4,1);

% Initialize SS.shimmerIMU_Ready
SS.shimmerIMU_Ready = 0;

% Initialize low-cost Nathan Taska wrist TNT 4/7/21
try
    [SS.LCWrist, SS.LCWrist_LastKin ] = initiateTaskaWrist();
    SS.LCWrist_Ready = 1;
    disp("Low-Cost Taska Wrist Connected");
    
catch
    disp("No Low-Cost Taska Wrist found, IS THE PATH ADDED???");
    SS.LCWrist_Ready = 0;
end

% Initializing loop timing
SS.BaseLoopTime=0.033; %smw - change to 0.025 at some point?
% SS.BaseLoopTime=0.02; %dk TASKA testing
SS.MCalcTic = double(xippmex_1_12('time'));
SS.MCalcTime = 0;
SS.MTotalTime = 0;
SS.Stop = 0;
SS.LoopCnt = 1; %total loop iterations from start
SS.TrainCnt = 1; %number of loop iterations during training
SS.StartBakeoff = false;
if any(strcmp(SS.CtrlMode,'Velocity'))
    SS.BakeoffDirect = 1;
else
    SS.BakeoffDirect = 0;
end
SS.PulseStim = 0;
SS.ManualType = 'Max'; %use min/max freq/amp in labview table for stim params
SS.StimWf = zeros(52,1);

% Initializing electrode/chan variables, buffers
SS.Fs = 30000;
SS.FsEMG = 1000;
SS.NumUEAs = 2;
SS.NumNeuralIdxs = 96*SS.NumUEAs;
SS.NumNeuralElects = 100*SS.NumUEAs;
SS.NumNeuralChans = 128*SS.NumUEAs;
SS.NumEMGIdxs = 528; %all possible pair combinations across all 8 leads plus individual
SS.NumDOF = 12; %thumb,index,middle,ring,little,thumbint,indexint,ringint,littleint,wrist,wristyaw,wristroll
SS.ManualDOF = false(SS.NumDOF,1);
SS.DLNeuralMaxMS = ceil(SS.BaseLoopTime*1000*1.1);
SS.DLNeuralMax = SS.DLNeuralMaxMS*(SS.Fs/1000); %max length of data acquired each loop iteration
SS.BadUEAElectsPrev = -1;
SS.BaselineData = zeros(SS.NumNeuralIdxs+SS.NumEMGIdxs,1); %baseline subtraction for features

SS.VRSurrIdxs = zeros(SS.NumNeuralIdxs,SS.NumNeuralIdxs);
% SS.VRSurrIdxsGPU = gpuArray(SS.VRSurrIdxs);% initializing VRsurrIdx

SS.NeuralChanList = mapRippleUEA(1:SS.NumNeuralIdxs,'i2c',SS.MapType.Neural); %list of NIP channels instead of indices to use with mex functions
[~,SS.AvailNeuralIdx] = intersect(SS.NeuralChanList,SS.AvailNeural);
% SS.EMGChanList = (1:32)+256; %NIP channels for EMG
SS.EMGChanList = (1:96)+256; %NIP channels for EMG
[~,SS.AvailEMGIdx] = intersect(SS.EMGChanList,SS.AvailEMG);

% add for VTStim if no neural stim FEs
VTChans = mapRippleUEA(2:7,'e2c',SS.MapType.Neural);
VTChans = reshape(VTChans,1,[]);
if SS.VTStruct.Ready && ~sum(ismember(VTChans, SS.AvailStim))
    SS.AvailStim = [VTChans SS.AvailStim];
end

%variables sent to labview (jag 10/4/17)
SS.decodeOutput = zeros(12,1);

% Starting python communication
switch SS.NumComp
    case '2 Computers'
        python_path = '\\PNIMATLAB\PNIMatlab_R1\decodeenginepython_DO_NOT_DELETE';
        try %MP20201223: Compiled MATLAB 2020b was having issues with python.
            temppy = py.sys.path;
            clear temppy;
        catch % set environment if compiled MATLAB isn't there.
            pyenv('Version', "\\pnimatlab\Users\Administrator\Anaconda3\envs\decode_env\python.exe");
        end
        
        if count(py.sys.path,python_path) == 0
            insert(py.sys.path,int32(0),python_path);
        end
end
% Set latching filter
SS.LF_C = 1;
SS.LatchingFilter = 0;
SS.CogLoadStimOn = 0;
SS.CogLoadButtonPress = 0;
SS.TargOn = 0;
SS.CogLoadNextStimTS = 0;
rng('shuffle'); % shuffle for CogLoad Secondary Task (MDP 20200125)
% Set Online Adaptation parameters
if isdeployed
    temp = csvread('HybridParams.csv');
else
    temp = csvread(fullfile(fileparts(mfilename('fullpath')),'dependencies','HybridParams.csv'));
end
numBetas = temp(1);
numTrialsPerBeta = temp(2);
SS.maxBetaIdx = numBetas*numTrialsPerBeta;
tempBetaValues = temp(3:3+numBetas-1);
SS.betaValues = [];
for iBetas = 1:numBetas
    SS.betaValues = [SS.betaValues tempBetaValues(iBetas)*ones(1,numTrialsPerBeta)];
end
SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
SS.betaIdx = 1;
disp({'Beta Values:' num2str(SS.betaValues)})

SS.AdaptOnline.ShouldAdapt = 1;
SS.AdaptOnline.AdaptationRate = SS.betaValues(SS.betaIdx);
SS.AdaptOnline.GoalX = [];
rng('shuffle'); % ensure unique seed for randn
disp('Goal Adaptation set')

% Initializing variables
SS = initStim(SS);
SS = initVRE(SS);
SS = initDEKA(SS);
SS = initTASKA(SS); % dk 2018-01-26
SS = initTASKASensors(SS);
SS = initAnalogSensors(SS);
SS = updateIdxs(SS); %creates/updates SS.KalmanChans, SS.SelChan, SS.BadChans, and also parses SS.StimCell
SS = initBuffers(SS);
SS = resetKalman(SS);


SS.GoalNoiseFixed = SS.GoalNoise*randn(1,1) + zeros(size(SS.T(SS.KalmanMvnts)));
SS.GoalNoiseHistory = zeros(12,1);
SS.betaHistory = [];
%%%%%%%%%%%%%%%%%%%%%%%%%%% COB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SS = sendDecode2NIP(SS);
% SS.pIdx = 1;
% SS.pBuffSize = 300;
% SS.pBuff = zeros(length(SS.KalmanMvnts),SS.pBuffSize);
% % SS.pBuff = zeros(length(SS.KalmanIdxs),SS.pBuffSize);
% SS.fH = figure('windowstyle','docked');
% SS.aH = axes('parent',SS.fH);
% SS.pH = plot(SS.aH,1:SS.pBuffSize,SS.pBuff');
% hold on
% SS.pH(end+1) = plot(SS.aH,[SS.pIdx,SS.pIdx],[-1000,1000],'r');
% hold off
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initializing other variables
[SS.bHP,SS.aHP] = butter(4,750/(SS.Fs/2),'high'); %butterworth filter (high-pass 250Hz) to use with FilterM (mex function for filtering)
SS.cHP = zeros(4,SS.NumNeuralIdxs); %initial conditions for filter for all channels

% Sending initial continuous data. This needs to be done so the 1st
% continuous read in LV will be successful, thus starting the synchronized
% passes of continuous data between the two systems.
SS.ContML = [SS.TrainCnt;SS.MCalcTime;SS.MTotalTime;SS.XHat;...
    %     SS.X;length(SS.NeuralElectRatesMA);SS.NeuralElectRatesMA;SS.EMGPwrMA(1:80);SS.ThreshRMS(SS.SelIdx);...
    SS.X;length(SS.NeuralElectRatesMA);SS.NeuralElectRatesMA;SS.EMGPwrMA;SS.ThreshRMS(SS.SelIdx);...
    length(SS.SelData);SS.SelData;SS.SelWfs(:)];
% disp(SS.ContML); disp('initsystem')%smw
fwrite(SS.UDPCont,typecast(flipud(single(SS.ContML)),'uint8'));

% Starting task file
SS.TaskFile = fullfile(SS.FullDataFolder,['\TaskData_',SS.DataFolder,'.kdf']);
warning('off','MATLAB:MKDIR:DirectoryExists')
mkdir(fileparts(SS.TaskFile));
SS.TaskFID = fopen(SS.TaskFile,'w+');
fwrite(SS.TaskFID,[1;length(SS.Z);length(SS.X);length(SS.T);length(SS.XHat)],'single'); %writing header (1+(96*NumUEAs+528)+12+12+12)


% Starting physical (3D) hand file
if SS.ARD3.Ready
    SS.PHandFile = fullfile(SS.FullDataFolder,['\PHandData_',SS.DataFolder,'.phf']);
    mkdir(fileparts(SS.PHandFile));
    SS.PHandFID = fopen(SS.PHandFile,'w+');
    fwrite(SS.PHandFID,[1;length(SS.PHandContactVals);length(SS.PHandMotorVals)],'single'); %writing header (1+(96*NumUEAs+528)+12+12+12)
end

% Starting continuous stim file
SS.ContStimFile = fullfile(SS.FullDataFolder,['\ContStim_',SS.DataFolder,'.csf']);
SS.ContStimFID = fopen(SS.ContStimFile,'w+');
fwrite(SS.ContStimFID,[1;length(SS.AllContStimAmp);length(SS.AllContStimFreq)],'single'); %saving data to ContStim file (*.csf filespec, see readCSF)

% Start Cognitive Load Params File (MDP 1/21/20)
SS.CogLoadFile = fullfile(SS.FullDataFolder,['\CogLoad_',SS.DataFolder,'.clf']);
mkdir(fileparts(SS.CogLoadFile));
SS.CogLoadFID = fopen(SS.CogLoadFile,'w+');


% Start recording and get time
pause(1)
try
    SS.XippTS = double(xippmex_1_12('time'));
    SS.RecStart = SS.XippTS; %get time when recording started (skipped if xippmex command fails)
    if SS.StartXippRec %only automatically start recording if command sent from LV
        %         xippmex_1_12('trial',SS.XippOpers,'recording',fullfile(SS.FullDataFolder,[SS.DataFolder,'-']));
        %         xippmex_1_12('trial','recording',fullfile(SS.FullDataFolder,[SS.DataFolder,'-']));
        xippmex_1_12('trial','recording',fullfile(SS.FullDataFolder, SS.DataFolder));
        RecStart = SS.RecStart;
        save(fullfile(SS.FullDataFolder,['\RecStart_',SS.DataFolder,'.mat']),'RecStart')
    end
    pause(1); %set to specified file and start recording (remote control must be selected on Trellis)
catch ME
    if isempty(ME.stack)
        fprintf('message: %s\r\n',ME.message);
    else
        fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    end
end

% Starting VRE
SS = startVRE(SS);
SS = startDEKA(SS);
SS = startTASKA(SS); % dk 2018-01-26

% Start both LV and ML loops at the same time
pause(1)
fwrite(SS.UDPEvnt,'MatlabReady');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Acquiring data
function SS = acqData(SS)

% Getting neural data from xippmex
SS.DNeural = zeros(SS.NumNeuralIdxs,SS.DLNeuralMax);
if ~isempty(SS.AvailNeural)
    [DNeural,DNeuralTS] = xippmex_1_12('cont',SS.AvailNeural,SS.DLNeuralMaxMS,'raw'); SS.CurrTS = double(DNeuralTS); %slow (1.08)
    if ~isempty(DNeural)
        SS.DNeural(SS.AvailNeuralIdx,:) = DNeural; %slow (0.23)
    end
else
    SS.CurrTS = double(xippmex_1_12('time'))-SS.DLNeuralMax;
end

SS.ApCell = cell(SS.NumNeuralIdxs,1); SS.ApWfCell = repmat({cell(1,[])},SS.NumNeuralIdxs,1); %slow (0.13)
SS.StCell = cell(SS.NumNeuralIdxs,1); SS.StWfCell = repmat({cell(1,[])},SS.NumNeuralIdxs,1);
% if ~isempty(SS.AvailNeural)
%     [~,ApCell,ApWfCell] = xippmex_1_12('spike',SS.AvailNeural,0); %slow (1.78)
%     [~,StCell,StWfCell] = xippmex_1_12('spike',SS.AvailNeural,1); %slow (1.57)
%     SS.ApCell(SS.AvailNeuralIdx) = ApCell;
%     SS.ApWfCell(SS.AvailNeuralIdx) = ApWfCell;
%     SS.StCell(SS.AvailNeuralIdx) = StCell;
%     SS.StWfCell(SS.AvailNeuralIdx) = StWfCell;
% end

% Getting emg data from xippmex
SS.DEMG = zeros(length(SS.AvailEMG),SS.DLNeuralMaxMS);
if ~isempty(SS.AvailEMG)
    DEMG = xippmex_1_12('cont',SS.AvailEMG,SS.DLNeuralMaxMS,'lfp',SS.CurrTS);
    if ~isempty(DEMG)
        SS.DEMG(SS.AvailEMGIdx,1:size(DEMG,2)) = DEMG;
        if strcmp(SS.MapType.EMG,'active')
            if length(SS.AvailEMG)<=32
                SS.DEMG = SS.DEMG(p2a(1:32),:);
            end
        end
    end
end

% Stopping stim if big red button is pressed
[~,SS.DigIO_TS,SS.DigEvents] = xippmex_1_12('digin');
if ~isempty(SS.DigEvents)
    if any([SS.DigEvents.reason]==4) %sma2 -- digital I/O input 2
        xippmex_1_12('stim','enable',0);
        SS.StimMode = 'Off';
        fwrite(SS.UDPEvnt,'StopStim:');
        disp('Stopping Stim...')
    end
end

% Calculating data length for current iteration
SS.DLNeural = min(floor(abs(SS.CurrTS-SS.XippTS)),SS.DLNeuralMax); SS.DLEMG = floor(SS.DLNeural/30); %samples since last acquisition
SS.XippTS = SS.CurrTS;
if SS.DLNeural
    SS.dNeural = SS.DNeural(:,end-SS.DLNeural+1:end)'; %slow (0.62)
    %     SS.dEMG = SS.DEMG(:,end-SS.DLEMG+1:end)'; %td: removed 0.2 factor since updated xippmex returns uV
    SS.dEMG = 0.2*SS.DEMG(:,end-SS.DLEMG+1:end)'; % smw- question, what is this 0.2; td: Conversion to uV. For some reason, dNeural doesn't need this (may be fixed in newer xippmex.
end

% Filtering and performing CAR
[SS.dNeural,SS.cHP] = FilterX(SS.bHP,SS.aHP,SS.dNeural,SS.cHP);

% [dNeural,cHP] = filter(SS.bHP,SS.aHP,gpuArray(SS.dNeural),SS.cHP);
% SS.dNeural = gather(dNeural);
% SS.cHP = gather(cHP);

if SS.CAR
    switch SS.CARType
        case {0,'Standard'} %standard
            %             SS.dNeural = gather((gpuArray(SS.dNeural)*SS.NeuralSurrIdxsGPU))
            SS.dNeural = SS.dNeural*SS.NeuralSurrIdxs;
        case {1,'NN'} %vr
            %             SS.dNeural = gather((gpuArray(SS.dNeural)*SS.VRSurrIdxsGPU));
            SS.dNeural = SS.dNeural*SS.VRSurrIdxs;
    end
end
SS.dNeural(:,SS.BadUEAIdxs) = nan;

% update RMS buffer and calculating spike threshold
SS.NeuralRMSBuff(:,SS.NeuralRMSBuffIdx(1)) = std(SS.dNeural,0,1)'; %slow(0.82) %This method of updating the buffer is faster
SS.NeuralRMSBuffIdx = circshift(SS.NeuralRMSBuffIdx,[0,-1]);
if strcmp(SS.ThreshMode,'RMS Auto')
    SS.ThreshRMS(1:SS.NumNeuralIdxs) = mean(SS.NeuralRMSBuff,2)*SS.ThreshVal;
end

% Finding spikes and calculating rates
if SS.NIPSpikes % use NIP spike detection
    SS.StTS = unique(cell2mat(SS.StCell'))';
    for k=1:SS.NumNeuralIdxs
        SS.ApTS = SS.ApCell{k,1};
        if ~isempty(SS.ApWfCell{k})
            %             SS.Wf = SS.ApWfCell{k}{1}(1:48)';
            SS.Wf = SS.ApWfCell{k}(1,1:48)';
        else
            SS.Wf = nan(48,1);
        end
        if ~isempty(SS.StTS) && ~isempty(SS.ApTS)
            SS.NeuralRates(k) = sum(all(abs(bsxfun(@minus,SS.StTS,SS.ApTS))>150,1))/SS.BaseLoopTime; %an attempt to remove stim artifact, ignoring all threshold crossings that occur with in 150 samples of the stim pulse
        else
            SS.NeuralRates(k) = length(SS.ApTS)/SS.BaseLoopTime;
        end
        if k==SS.SelIdx
            SS.SelWfs = SS.Wf;
        end
    end
else % use "standard" spike detection
    [SS.NeuralRates,SS.WfIdx,SS.NeuralREM,SS.Wf] = findSpikesRealTimeMex(SS.dNeural,SS.ThreshRMS(1:SS.NumNeuralIdxs),SS.NeuralREM,SS.XippTS); %slow (0.34)
    if SS.SelIdx>SS.NumNeuralIdxs
        SS.SelWfs = nan(48,1);
    else
        SS.SelWfs = SS.Wf(1:48,SS.SelIdx);
    end
    SS.NeuralRates = SS.NeuralRates./SS.BaseLoopTime;
end

% Update spike rate buffer
SS.NeuralRatesBuff(:,2:end) = SS.NeuralRatesBuff(:,1:end-1);
SS.NeuralRatesBuff(:,1) = SS.NeuralRates; %current firing rate for all neural indices
SS.NeuralRatesMA = mean(SS.NeuralRatesBuff,2); %moving average firing rate for all neural indices

% Update continuous EMG buffer
% SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),:) = mtimesx(SS.dEMG,SS.EMGMatrix,'speed');
% SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),:) = gather(gpuArray(SS.dEMG)*SS.EMGMatrixGPU); %~300x(80+448) (time x all possible diff pairs on a single lead plus all other possible pairs across leads - see genEMGMatrix.m)
if length(SS.AvailEMG)<=32
    SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),:) = SS.dEMG*SS.EMGMatrix; %slow (0.29)
else
    SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),1:length(SS.AvailEMG)) = SS.dEMG;
end
if SS.Log10
    SS.EMGPwrMA = mean(10*log10(abs(SS.EMGDiffBuff)+1),1)';
else
    SS.EMGPwrMA = mean(abs(SS.EMGDiffBuff),1)'; %slow (0.24) %emg pwr averaged over kernel width
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%
% Subtracting baseline
if SS.ApplyBaseline
    SS.NeuralRatesMA = SS.NeuralRatesMA - SS.BaselineData(1:SS.NumNeuralIdxs);
    SS.EMGPwrMA = SS.EMGPwrMA - SS.BaselineData((1:SS.NumEMGIdxs)+SS.NumNeuralIdxs);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Updating kalman
SS.Z = [SS.NeuralRatesMA;SS.EMGPwrMA]; %moving average for spike rate (channel x rate) with emg appended (720 x rate or pwr)

% Updating NN
try
    NNdata = circshift(SS.NN.FeatureBuffer,-1,2);  %shifts data down (oldest value now at index 1)
    if(SS.NN.neuralFeatures)    %determine feature size
        Features = SS.Z;   %all features including neural
    else
        if(SS.NN.numFeatures == 32)
            Features = SS.EMGPwrMA(SE);
        else
            Features = SS.EMGPwrMA;   %first X EMG channels go into buffer for NN
        end
    end
    temp = length(Features);
    % discretize?
    if(SS.NN.discrete)
        steps = SS.NN.steps;
        Features(Features <= steps(1)) = 0;
        for ii = 1:length(steps)-1
            indxs = (   (Features > steps(ii)) & (Features <= steps(ii+1))   );
            Features(indxs) = ii;
        end
        Features(Features > steps(end)) = ii;
    end
    % scale?
    if(SS.NN.scaled)
        Features = (Features - SS.NN.minmax(1) ) / SS.NN.minmax(2);
    end
    % update features
    NNdata(1:temp,1) = Features;
    % add kinematic features if needed
    if(SS.NN.kinematicFeatures)
        NNdata(temp+1:end,1) = SS.NN.Prediction;
    end
    SS.NN.FeatureBuffer = NNdata;
catch
    %disp('Failed Updated NN Features');
end

% Updating neural data that are sent continuously to labview
SS.NeuralElectRatesMA(mapRippleUEA(1:SS.NumNeuralIdxs,'i2e',SS.MapType.Neural)) = SS.NeuralRatesMA; %this gets sent back to LV for heatmaps

% Processing data for selected channel
if SS.SelIdx<=SS.NumNeuralIdxs %displaying neural
    SS.SelData = [min(SS.dNeural(:,SS.SelIdx));max(SS.dNeural(:,SS.SelIdx))];
elseif SS.SelIdx>SS.NumNeuralIdxs && SS.SelIdx<=(SS.NumNeuralIdxs+SS.NumEMGIdxs) %displaying emg
    SS.SelData = [min(SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),SS.SelIdx-SS.NumNeuralIdxs));max(SS.EMGDiffBuff(SS.EMGDiffBuffIdx(1:SS.DLEMG),SS.SelIdx-SS.NumNeuralIdxs))];
end

% This needs to be shifted after getting selected channel data
SS.EMGDiffBuffIdx = circshift(SS.EMGDiffBuffIdx,[0,-SS.DLEMG]);

% Acquire TASKA Sensor values
if(SS.TASKASensors.Ready)
    %prep buffer
    SS.TASKASensors.IRraw = circshift(SS.TASKASensors.IRraw,-1,2);
    SS.TASKASensors.baroraw = circshift(SS.TASKASensors.baroraw,-1,2);
    %read data
    [SS.TASKASensors.IRraw(:,end), SS.TASKASensors.baroraw(:,end)] = readTASKASensors_simple(SS.TASKASensors.Obj,SS.TASKASensors.Count);
    %subtract baseline
    SS.TASKASensors.prevIR = SS.TASKASensors.IR; % TCH 7/7/20
    SS.TASKASensors.IR = median(SS.TASKASensors.IRraw,2) - SS.TASKASensors.BL.IR;% - 0.05*SS.TASKASensors.BL.IR;   %subtract baseline and small error window
    SS.TASKASensors.baro = median(SS.TASKASensors.baroraw,2) - SS.TASKASensors.BL.baro;
    SS.TASKASensors.IR(SS.TASKASensors.IR < 0) = 0;
    SS.TASKASensors.baro(SS.TASKASensors.baro < 0) = 0;
    %update thumb pressure to account for drift
    if(SS.TASKASensors.IR(4) <= 40)
        tempP = median(SS.TASKASensors.baroraw,2);
        SS.TASKASensors.BL.baro(4) = tempP(4);
    end
end

% IMU Stuff
% pull live IMU data, compute kinematics, send to decode, etc
if SS.shimmerIMU_Ready
    newIMUdata = [];
    for index = 1:length(SS.shimmerIMU)
        newstuff = SS.shimmerIMU(index).getdata('c');
        if ~isempty(newstuff)
            newIMUdata = [newIMUdata newstuff(end,:)];
        else
            newIMUdata = [newIMUdata zeros(1,10)];
        end
    end
    SS.shimmerIMUData = newIMUdata;
    
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read parameters from Labview for Kalman control
function SS = acqEvents(SS)

% Waiting for UDP packet from LV
if SS.UDPEvnt.BytesAvailable
    LVStr = fscanf(SS.UDPEvnt); % SS.Elect=17; or AbortStim: or SendStim:SS.Elect=[35,36,];...
    disp(LVStr);
    try
        % Parsing LVStr
        LVCell = regexp(LVStr,':','split','once');
        eval(LVCell{length(LVCell)}) %saving variables directly to SS structure
        SS = updateIdxs(SS); %any time an electrode number is transmitted, it will be immediately converted to an index into the data matrices
        % Execute cases that match term preceding ":" operator
        switch LVCell{1}
            case 'AlignData'
                fwrite(SS.UDPEvntAux,sprintf('AlignData:SS.KDFTrainFile=''%s'';SS.AlignType=''%s'';SS.AutoThresh=%1.1f;SS.BadKalmanIdxs=[%s];',...
                    regexprep(SS.KDFTrainFile,':','@'), SS.AlignType,SS.AutoThresh,...
                    regexprep(num2str(SS.BadKalmanIdxs(:)'),'\s+',',')));
                disp('Calling AlignData case in AUX Loop')
            case 'ApplyTraining'
                SS = resetKalman(SS);
                if isfield(SS,'KDFTrainFile')
                    SS.TrainParamsFile = [SS.KDFTrainFile(1:end-4),'_',datestr(clock,'HHMMSS'),'.mat'];
                    save(SS.TrainParamsFile,'-struct','SS','Lag','KernelWidth','TargRad','ApplyBaseline','BaselineData','KalmanElects','KalmanEMG','KalmanIdxs','BadUEAElects','KEMGExtra','BadEMGChans','KalmanMvnts','KalmanGain','KalmanThresh','KalmanType','ReTrain','TRAIN','KDFTrainFile','KEFTrainFile','BaseLoopTime','NumDOF','NumNeuralIdxs','NumEMGIdxs','FreeParam')
                    switch SS.KalmanType
                        case {0,'Standard'} %standard
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrainStandard:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrainStandard case in AUX Loop')
                        case {1,'Mean'} %mean
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrainMean:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrainMean case in AUX Loop')
                        case {2,'Refit'} %refit
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrainRefit:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrainReFit case in AUX Loop')
                        case {3,'LinSVReg'} %LinSVReg ,to do: type 3 on LV, receive aux event
                            fwrite(SS.UDPEvntAux,sprintf('LinSVReg_train:SS.TrainParamsFile=''%s''; ', regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling LinSVReg_train function from AUX Loop')
                        case {4,'NonLinSVReg'} %NonLinSvm
                            fwrite(SS.UDPEvntAux,sprintf('NonLinSVReg_train:SS.TrainParamsFile=''%s''; ', regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling NonLinSVReg_train function from AUX loop')
                        case {6,'DWPRR'} % smw 1/11/17
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrain_DWPRR:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrain_DWPRR case in AUX Loop')
                        case {7,'AdaptKF'}
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrainStandard:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrainStandard case in AUX Loop')
                            temp = csvread('HybridParams.csv');
                            numBetas = temp(1);
                            numTrialsPerBeta = temp(2);
                            SS.maxBetaIdx = numBetas*numTrialsPerBeta;
                            tempBetaValues = temp(3:3+numBetas-1);
                            SS.betaValues = [];
                            for iBetas = 1:numBetas
                                SS.betaValues = [SS.betaValues...
                                    tempBetaValues(iBetas)*ones(1,numTrialsPerBeta)];
                            end
                            SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                            SS.betaIdx = 1;
                            disp({'Beta Values:' num2str(SS.betaValues)})
                        case {9,'NN_python'}
                            fwrite(SS.UDPEvntAux,sprintf('NN_pythonTrain:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling NN_pythonTrain case in AUX Loop')
                            temp = csvread('HybridParams.csv');
                            numBetas = temp(1);
                            numTrialsPerBeta = temp(2);
                            SS.maxBetaIdx = numBetas*numTrialsPerBeta;
                            tempBetaValues = temp(3:3+numBetas-1);
                            SS.betaValues = [];
                            for iBetas = 1:numBetas
                                SS.betaValues = [SS.betaValues...
                                    tempBetaValues(iBetas)*ones(1,numTrialsPerBeta)];
                            end
                            SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                            SS.betaIdx = 1;
                            disp({'Beta Values:' num2str(SS.betaValues)})
                        case {10,'AdaptKF2'}
                            fwrite(SS.UDPEvntAux,sprintf('KalmanTrainStandard:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            disp('Calling KalmanTrainStandard case in AUX Loop')
                            temp = csvread('HybridParams.csv');
                            numBetas = temp(1);
                            numTrialsPerBeta = temp(2);
                            SS.maxBetaIdx = numBetas*numTrialsPerBeta;
                            tempBetaValues = temp(3:3+numBetas-1);
                            SS.betaValues = [];
                            for iBetas = 1:numBetas
                                SS.betaValues = [SS.betaValues...
                                    tempBetaValues(iBetas)*ones(1,numTrialsPerBeta)];
                            end
                            SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                            SS.betaIdx = 1;
                            disp({'Beta Values:' num2str(SS.betaValues)})
                        case {11,'KF_Short_Goal'}
                            fwrite(SS.UDPEvntAux,sprintf('NN_python_classifier_Train:SS.TrainParamsFile=''%s'';',regexprep(SS.TrainParamsFile,':','@')));
                            
                            disp('Calling NN_pythonTrain MLP classifier case in AUX Loop')
                            temp = csvread('HybridParams.csv');
                            numBetas = temp(1);
                            numTrialsPerBeta = temp(2);
                            SS.maxBetaIdx = numBetas*numTrialsPerBeta;
                            tempBetaValues = temp(3:3+numBetas-1);
                            SS.betaValues = [];
                            for iBetas = 1:numBetas
                                SS.betaValues = [SS.betaValues...
                                    tempBetaValues(iBetas)*ones(1,numTrialsPerBeta)];
                            end
                            SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                            SS.betaIdx = 1;
                            disp({'Beta Values:' num2str(SS.betaValues)})
                    end
                else
                    fwrite(SS.UDPEvnt,'TrainingFinished:'); %nothing happens if apply training is pressed and no training file exists
                end
                disp('Training Applied')
            case 'AutoPop'
                switch SS.AutoPopType
                    case {0,'Standard'} % 'Standard'
                        disp('Calling Standard AutoPop function')
                        fwrite(SS.UDPEvntAux,sprintf('AutoPopStandard:SS.KDFTrainFile=''%s'';SS.MapType.Neural=''%s'';SS.AutoThresh=%0.2f;SS.BadKalmanIdxs=[%s];',regexprep(SS.KDFTrainFile,':','@'),SS.MapType.Neural,SS.AutoThresh,regexprep(num2str(SS.BadKalmanIdxs(:)'),'\s+',',')))
                    case {1,'Stepwise'} % 'Stepwise'
                        disp('Calling Stepwise AutoPop function')
                        fwrite(SS.UDPEvntAux,sprintf('AutoPopStepwise:SS.KDFTrainFile=''%s'';SS.MapType.Neural=''%s'';SS.AutoThresh=%0.2f;SS.BadKalmanIdxs=[%s];',regexprep(SS.KDFTrainFile,':','@'),SS.MapType.Neural,SS.AutoThresh,regexprep(num2str(SS.BadKalmanIdxs(:)'),'\s+',',')))
                    case {2,'Gram'} % smw 1/10/17
                        disp('Calling Gram-SchmidtDarpa AutoPop function')
                        try
                            if(SS.ExcludeSE)
                                temp = unique([SS.BadKalmanIdxs; 192+SE']);
                            else
                                temp = SS.BadKalmanIdxs;
                            end
                        catch
                            temp = SS.BadKalmanIdxs;
                        end
                        fwrite(SS.UDPEvntAux,sprintf('AutoPopGram:SS.KDFTrainFile=''%s'';SS.MapType.Neural=''%s'';SS.AutoThresh=%0.2f;SS.BadKalmanIdxs=[%s];',regexprep(SS.KDFTrainFile,':','@'),SS.MapType.Neural,SS.AutoThresh,regexprep(num2str(temp(:)'),'\s+',','))); % note SS.AutoThresh not necessary here
                end
            case 'ChangeKalmanType' %since kalman testing is always running, if kalman type is changed, the variables must be initialized to match the specific algorithm
                SS = resetKalman(SS);
                disp('Changing Kalman Type')
            case 'ChangeLag'
                disp('Changing lag')
            case 'ChangeTargRad'
                if SS.VRETargetsEnabled
                    if SS.TargRad <= 0.15
                        SS.TargSize = 'S';
                        SS.CurVRETargetIdx = SS.VRETargetIdx(1:6);
                        SS.HiddenVRETargetIdx = SS.VRETargetIdx(7:18);
                    elseif SS.TargRad > 0.15 && SS.TargRad <= 0.18
                        SS.TargSize = 'M';
                        SS.CurVRETargetIdx = SS.VRETargetIdx(7:12);
                        SS.HiddenVRETargetIdx = SS.VRETargetIdx(1:6,13:18);
                    else
                        SS.TargSize = 'L';
                        SS.CurVRETargetIdx = SS.VRETargetIdx(13:18);
                        SS.HiddenVRETargetIdx = SS.VRETargetIdx(1:12);
                    end
                    for k = 1:length(SS.HiddenVRETargetIdx) % turn off hidden, other size targets
                        mj_set_rgba('geom',SS.HiddenVRETargetIdx(k),[0 0 0 0]);
                    end
                    for k = 1:length(SS.CurVRETargetIdx) % turn on cur targets
                        mj_set_rgba('geom',SS.CurVRETargetIdx(k),[0 1 0 0.5]);
                    end
                end
                disp('Changing TargRad')
            case 'ChangeKernel'
                SS.NeuralRatesBuff = zeros(SS.NumNeuralIdxs,round(SS.KernelWidth/SS.BaseLoopTime));
                SS.EMGDiffBuff = zeros(floor(SS.KernelWidth*SS.FsEMG),size(SS.EMGMatrix,2)); SS.EMGDiffBuffIdx = 1:size(SS.EMGDiffBuff,1);
                disp('Changing kernel width')
            case 'EnableCAR'
                disp('Enabling CAR')
            case {'EnableLog10','DisableLog10'}
                if SS.Log10
                    disp('Enabling Log10')
                else
                    disp('Disabling Log10')
                end
            case 'EEGTrigger'
                if SS.EEGTrigger
                    disp('EEG Trigger on')
                else
                    disp('EEG Trigger off')
                end
            case 'EndTrial' %acquiring endtrial event
                GNF = zeros(12,1); GNF(SS.KalmanMvnts) = SS.GoalNoiseFixed;
                SS.GoalNoiseHistory = [SS.GoalNoiseHistory,GNF];
                SS.GoalNoiseFixed = SS.GoalNoise*randn(1,1) + zeros(size(SS.T(SS.KalmanMvnts)));
                SS.betaHistory = [SS.betaHistory SS.betaValues(SS.betaIdx)];
                SS.betaIdx = SS.betaIdx + 1;
                if SS.betaIdx>SS.maxBetaIdx
                    SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                    SS.betaIdx = 1;
                    disp({'Beta Values:' num2str(SS.betaValues)})
                end
                SS.AdaptOnline.AdaptationRate = SS.betaValues(SS.betaIdx);
                if SS.AcqTraining && strcmp(SS.KinSrc,'Training')
                    if exist(SS.KEFTrainFile,'file')
                        fprintf(SS.KEFTrainFID,'SS.TrialTS=%0.0f;%s\r\n',SS.XippTS-SS.RecStart,LVCell{length(LVCell)});
                    end
                end
                if SS.EEGTrigger && (strcmp(SS.KinSrc, 'Decode'))
                    % send stop trigger
                    disp('Stop EEG Trigger')
                    xippmex_1_12('digout',5,targ2EEGEvent(SS.TargRad, SS.T, 'TargOff'))
                end
                %                 if ~SS.AcqTraining && strcmp(SS.KinSrc,'Decode')
                %                     r = rand;
                %                     if r<0.33
                %                         SS.VREInfo.mocap.pos = [-0.05 0 0]; %large
                %                     elseif r>=0.33 && r<0.67
                %                         SS.VREInfo.mocap.pos = [0.21 0 0]; %small
                %                     else
                %                         SS.VREInfo.mocap.pos = [0.41 0 0]; %null
                %                     end
                %                     mj_set_mocap(SS.VREInfo.mocap);
                %                 end
            case {'EnableHideSpheres','DisableHideSpheres'}
                %                 if SS.VRETargetsEnabled
                %                     for k = 1:length(SS.VRETargetIdx) % Turn off all targs
                %                         mj_set_rgba('geom',SS.VRETargetIdx(k),[0 0 0 0]);
                %                     end
                %                 end
                disp('Hide or unhide Spheres...')
            case 'Failure'
                SS.TargOn = 0;
            case 'LinkDOF' % SS.LinkedDOF = {[1,3,4];[2,5];};
                disp('linking DOF');
            case 'LoadTrainFile'
                SS.TrainFileLV = regexprep(SS.TrainFileLV,'@',':'); %SS.TrainFileLV='D@\RemoteRepo\FeedbackDecode\00000000-000000\TrainingParams_00000000-000000_122200_122212.mat';
                TrainFileExt = cell2mat(regexp(SS.TrainFileLV,'\..+$','match'));
                if exist(SS.TrainFileLV,'file')
                    if strcmp(TrainFileExt,'.mat')
                        TF = load(SS.TrainFileLV);
                        SS.KDFTrainFile = regexprep(SS.TrainFileLV,'_\d+\.mat$','.kdf');
                        SS.KEFTrainFile = regexprep(SS.KDFTrainFile,'kdf$','kef');
                        SS.EvntStr = sprintf('LoadTrainFile:Lag=%0.0f;KernelWidth=%0.2f;TargRad=%0.2f;KalmanElects=%s;KalmanEMG=%s;KalmanMvnts=%s;KalmanGain=%s;KalmanThresh=%s;KalmanType=%s;KEMGExtra=%s;BadUEAElects=%s;BadEMGChans=%s;',TF.Lag,TF.KernelWidth,TF.TargRad,regexprep(num2str(TF.KalmanElects(:)'),'\s+',','),regexprep(num2str(TF.KalmanEMG(:)'),'\s+',','),regexprep(num2str(TF.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(TF.KalmanGain(:)'),'\s+',','),regexprep(num2str(TF.KalmanThresh(:)'),'\s+',','),TF.KalmanType,regexprep(num2str(TF.KEMGExtra(:)'),'\s+',','),regexprep(num2str(TF.BadUEAElects(:)'),'\s+',','),regexprep(num2str(TF.BadEMGChans(:)'),'\s+',','));
                    elseif strcmp(TrainFileExt,'.kdf')
                        SS.KDFTrainFile = SS.TrainFileLV;
                        SS.KEFTrainFile = regexprep(SS.KDFTrainFile,'kdf$','kef');
                        SS.EvntStr = sprintf('LoadTrainFile:Lag=%0.0f;KernelWidth=%0.2f;TargRad=%0.2f;KalmanElects=%s;KalmanEMG=%s;KalmanMvnts=%s;KalmanGain=%s;KalmanThresh=%s;KalmanType=%s;KEMGExtra=%s;BadUEAElects=%s;BadEMGChans=%s;',SS.Lag,SS.KernelWidth,SS.TargRad,regexprep(num2str(SS.KalmanElects(:)'),'\s+',','),regexprep(num2str(SS.KalmanEMG(:)'),'\s+',','),regexprep(num2str(SS.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(SS.KalmanGain(:)'),'\s+',','),regexprep(num2str(SS.KalmanThresh(:)'),'\s+',','),SS.KalmanType,regexprep(num2str(SS.KEMGExtra(:)'),'\s+',','),regexprep(num2str(SS.BadUEAElects(:)'),'\s+',','),regexprep(num2str(SS.BadEMGChans(:)'),'\s+',','));
                    end
                    fwrite(SS.UDPEvnt,SS.EvntStr); %sending back to LV to populate front panel (applytraining must be pressed)
                else
                    fwrite(SS.UDPEvnt,'LoadTrainFile:');
                end
                disp('Loading training file')
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            case 'LoadNN'
                disp('Loading NN .mat file...')
                load(SS.NN.path)
                %need to store and load in the following variables
                try
                    SS.NN.windowSize = windowSize;
                    SS.NN.numFeatures = numFeatures;
                    SS.NN.neuralFeatures = neuralFeatures;
                    SS.NN.kinematicFeatures = kinematicFeatures;
                    SS.NN.net = net;
                    SS.NN.Prediction = zeros(12,1);
                    try     %discrete?
                        SS.NN.steps = steps;
                        SS.NN.discrete = 1;
                    catch
                        SS.NN.discrete = 0;
                    end
                    try     %scaled?
                        SS.NN.minmax = minMAX;
                        SS.NN.scaled = 1;
                    catch
                        SS.NN.scaled = 0;
                    end
                    try
                        SS.NN.postKalmanTRAIN = postKalmanTRAIN;
                        SS.NN.postKalman = 1;
                        kalman_test(zeros(12,1),SS.NN.postKalmanTRAIN,[-1,1],1);
                    catch
                        SS.NN.postKalman = 0;
                    end
                    %when loading in training and variables, need to setup the buffer with zeros
                    %inputSize = [numFeatures,windowSize,1];
                    SS.NN.FeatureBuffer = zeros(SS.NN.numFeatures,SS.NN.windowSize);
                    SS.NN.Prediction = zeros(SS.NumDOF,1);
                    disp('Loaded NN .mat file sucessfully.')
                    
                catch
                    %                     SS.subX = TF.subX;
                    %                     SS.subZ = TF.subZ;
                    %                     SS.subK = TF.subK;
                    %                     SS.subT = TF.subT;
                    SS.KalmanEMG = TF.KalmanEMG;
                    SS.KalmanElects = TF.KalmanElects;
                    SS.KalmanGain = TF.KalmanGain;
                    SS.KalmanMvnts = TF.KalmanMvnts;
                    SS.KEMGExtra = TF.KEMGExtra;
                    SS.KalmanIdxs = TF.KalmanIdxs;
                    SS.EvntStr = sprintf('LoadTrainFile:Lag=%0.0f;KernelWidth=%0.2f;TargRad=%0.2f;KalmanElects=%s;KalmanEMG=%s;KalmanMvnts=%s;KalmanGain=%s;KalmanThresh=%s;KalmanType=%s;KEMGExtra=%s;BadUEAElects=%s;BadEMGChans=%s;',SS.Lag,SS.KernelWidth,SS.TargRad,regexprep(num2str(SS.KalmanElects(:)'),'\s+',','),regexprep(num2str(SS.KalmanEMG(:)'),'\s+',','),regexprep(num2str(SS.KalmanMvnts(:)'),'\s+',','),regexprep(num2str(SS.KalmanGain(:)'),'\s+',','),regexprep(num2str(SS.KalmanThresh(:)'),'\s+',','),SS.KalmanType,regexprep(num2str(SS.KEMGExtra(:)'),'\s+',','),regexprep(num2str(SS.BadUEAElects(:)'),'\s+',','),regexprep(num2str(SS.BadEMGChans(:)'),'\s+',','));
                    fwrite(SS.UDPEvnt,SS.EvntStr); %sending back t
                    SS = resetKalman(SS); %zeros out Kalman variables (if Kalman file loaded)
                    SS.TRAIN = TF.TRAIN;
                end
            case 'LoadCyberGlove'
                disp('Loading CyberGlove .mat calibration file...')
                load(SS.CyberGlove.Calibration)
                %need to store and load in the following variables
                SS.CyberGlove.Eqs = eqs;
                SS.CyberGlove.Ready = 1;
                disp('CyberGlove Calibration loaded correctly.')
            case 'UpdateStim' %happens when value change in ParamsTable, button selection
                disp('Updating stim...')
            case 'ClearStim' %happens when ParamsTable is cleared
                %                 xippmex_1_12('stim','enable',0);
                disp('Clearing stim...')
            case 'ChangeStimMode'
                switch SS.StimMode
                    case 'Off'
                        xippmex_1_12('stim','enable',0);
                end
                disp('Changing stim mode...')
            case 'ManualStim'
                if SS.ManualStim
                    disp('Starting manual stim...')
                else
                    %                     xippmex_1_12('stim','enable',0);
                    disp('Stopping manual stim...')
                end
            case 'ChangeStimStep'
                for k=1:length(SS.AvailStimHS)
                    StimIdx = SS.StimStepSize(any(SS.AvailStimHS(k)==SS.StimStepSizeHS));
                    if ~isempty(StimIdx)
                        if StimIdx>=1 && StimIdx<=6
                            xippmex_1_12('stim','res',SS.AvailStimHS(k),StimIdx)
                        end
                    end
                end
                disp('Changing stim step...')
            case 'ChangeTestType'
                disp('Changing Test Type...')
            case 'EnableStartTrials'
                if ~strcmp(SS.TestType,'MSMS') && (strcmp(regexp(SS.TestType,'^[^_]+','match','once'),SS.VREInfo.IDLabel) || strcmp(SS.TestType,'Bakeoff21'))
                    mj_close;
                    SS.StartBakeoff = true;
                    fwrite(SS.UDPContAux,[zeros(6,1);1;SS.BakeoffDirect],'single')
                    fwrite(SS.UDPEvntAux,sprintf('StartBakeoff:SS.TestType=''%s'';',SS.TestType))
                    disp('Starting Bakeoff in Aux...')
                end
                if SS.ECGTriggerTargets && ~SS.AcqTraining
                    ecgStartRecordTS = ecgstart(SS.shimmerECG);
                    fprintf(SS.CogLoadFID,'TargetSetStart,NIPTime=%0.0f,TargRad=%0.2f,ShimmerUnixTime_ms=%0.0f\r\n', ...
                        [SS.XippTS - SS.RecStart, SS.TargRad, ecgStartRecordTS]);
                end
            case 'DisableStartTrials'
                if SS.StartBakeoff
                    SS.StartBakeoff = false;
                    SS.VREStatus = false;
                    SS.VREInfo.IDIdx = 0;
                    SS.VREInfo.IDLabel = '';
                    SS.VREInfo.HandType = '';
                    fwrite(SS.UDPContAux,[zeros(6,1);0;SS.BakeoffDirect],'single')
                end
                SS.TargOn = 0;
                if SS.ECGTriggerTargets && ~SS.AcqTraining
                    ecgStopRecordTS = ecgstop(SS.shimmerECG);
                    fprintf(SS.CogLoadFID,'TargetSetEnd,NIPTime=%0.0f,TargRad=%0.2f,ShimmerUnixTime_ms=%0.0f\r\n', ...
                        [SS.XippTS - SS.RecStart, SS.TargRad, ecgStopRecordTS]);
                end
            case 'ResetVRE'
                SS = startVRE(SS);
                disp('Resetting VRE...')
            case 'StopVRE'
                mj_close;
                SS.StartBakeoff = false;
                SS.VREStatus = false;
                SS.VREInfo.IDIdx = 0;
                SS.VREInfo.IDLabel = '';
                SS.VREInfo.HandType = '';
                fwrite(SS.UDPContAux,[zeros(6,1);0;SS.BakeoffDirect],'single')
                disp('Disconnecting VRE...')
            case 'ConARD'
                disp('Reconnecting serial connections...')
                %                 SS.f = parfeval(@conARD,1,SS);
                SS = connectARD(SS);
                SS = initTASKA(SS);
                SS = initTASKASensors(SS);
            case 'CalibrateDEKA'
                % below is for LabVIEW control
                %                 disp('DEKA Calibration Finished...')
                %                 SS.EvntStr = 'CalDEKAFinished:';
                %                 fwrite(SS.UDPEvnt,SS.EvntStr); %sending back to LV to populate front panel
                % below is for MATLAB control
                disp('Calibrating DEKA/TASKA Sensors...')
                if (SS.DEKA.Ready)
                    SS.DEKA.BLSensors = calibrateDEKA();
                end
                %                 SS.DEKA.BLSensors = calibrateDEKA_wristp(); % fixed for wrists in pos mode (dk 2018-03-16)
                %fwrite(SS.UDPEvntAux,sprintf('CalibrateDEKA:'));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'CalibrateTASKA'
                if (SS.TASKASensors.Ready)
                    tempLen = 200;
                    tempIR = zeros(4,tempLen);
                    tempbaro = zeros(4,tempLen);
                    tempfiltIR = zeros(4,tempLen-SS.TASKASensors.window);
                    tempfiltbaro = zeros(4,tempLen-SS.TASKASensors.window);
                    for tind = 1:tempLen %median filter the data with window size
                        [tempIR(:,tind), tempbaro(:,tind)] = readTASKASensors_simple(SS.TASKASensors.Obj,SS.TASKASensors.Count);
                        if (tind > SS.TASKASensors.window)
                            tempfiltIR(:,tind-SS.TASKASensors.window) = median(tempIR(:,tind-SS.TASKASensors.window:tind),2);
                            tempfiltbaro(:,tind-SS.TASKASensors.window) = median(tempbaro(:,tind-SS.TASKASensors.window:tind),2);
                        end
                    end % take the max of the median filtered data
                    TEMP_IR = max(tempfiltIR,[],2);
                    TEMP_BR = max(tempfiltbaro,[],2);
                    % keep new baseline only if it's greater than the
                    % previous baseline
                    SS.TASKASensors.BL.IR(TEMP_IR > SS.TASKASensors.BL.IR) = TEMP_IR(TEMP_IR > SS.TASKASensors.BL.IR);
                    SS.TASKASensors.BL.baro(TEMP_BR > SS.TASKASensors.BL.baro) = TEMP_BR(TEMP_BR > SS.TASKASensors.BL.baro);
                    % flush buffer to reduce lag
                    flushinput(SS.TASKASensors.Obj);
                end
            case 'CalibrateTASKAreset'
                SS.TASKASensors.BL.IR = [0;0;0;0];
                SS.TASKASensors.BL.baro = [0;0;0;0];
            case 'RestartDEKA'
                SS.DEKA.Ready = 0;
                lkmex('stop')
                clear lkmex
                lkmex('start')
                if strcmp(SS.Prosthesis(end-4:end),'Right')
                    SS.DEKA.RightHand = 1;
                else
                    SS.DEKA.RightHand = 0;
                end
                disp('DEKA communication restarted. You can turn the hand back on now.');
                % restarting taska as well
                %                 while 1
                %                     TaskaPrompt = input('Connect Taska? (Y/N): ', 's');
                %
                %                     if length(TaskaPrompt) == 1 && any(TaskaPrompt == 'YyNn10')
                %                         if any(TaskaPrompt == 'Yy1')
                %                             attemptConnection = 1;
                %                         else
                %                             attemptConnection = 0;
                %                         end
                %                         break
                %                     end
                %                 end
                if SS.StartTaska
                    [SS.TASKA.Obj, SS.TASKA.Ready] = openTASKA(); % please don't uncomment without asking TCH first
                end
            case 'EnableNIPSpikes'
                disp('Switching to NIP spike detection')
            case 'DisableNIPSpikes'
                disp('Switching to standard spike detection')
            case 'SendBad'
                SS = resetKalman(SS);
                disp('Updating bad channels')
            case 'StartAcqBaseline'
                SS.TrainCnt = 1;
                SS.DateStr = datestr(clock,'HHMMSS');
                SS.BaselineFile = fullfile(SS.FullDataFolder,['\BaselineData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                SS.BaselineFID = fopen(SS.BaselineFile,'w+');
                fwrite(SS.BaselineFID,[length(SS.XippTS);length(SS.Z);length(SS.X);length(SS.T);length(SS.XHat)],'single');
                disp('Starting baseline data collection for subtraction during training')
            case 'StartAcqCAR'
                SS.TrainCnt = 1;
                SS.DateStr = datestr(clock,'HHMMSS');
                SS.CARFile = fullfile(SS.FullDataFolder,['\CARData_',SS.DataFolder,'_',SS.DateStr,'.rdf']);
                SS.CARFID = fopen(SS.CARFile,'w+');
                fwrite(SS.CARFID,[SS.XippTS-SS.RecStart;SS.NumUEAs;SS.DLNeuralMax],'single');
                disp('Starting CAR data collection for weighting')
            case 'StartTraining' %SS.AcqTraining=1;
                SS.TrainCnt = 1;
                SS.DateStr = datestr(clock,'HHMMSS');
                SS.KDFTrainFile = fullfile(SS.FullDataFolder,['\TrainingData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                SS.KDFTrainFID = fopen(SS.KDFTrainFile,'w+');
                fwrite(SS.KDFTrainFID,[length(SS.XippTS);length(SS.Z);length(SS.X);length(SS.T);length(SS.XHat)],'single'); %writing header
                SS.KEFTrainFile = fullfile(SS.FullDataFolder,['\TrainingData_',SS.DataFolder,'_',SS.DateStr,'.kef']);
                SS.KEFTrainFID = fopen(SS.KEFTrainFile,'w+');
                if(SS.CyberGlove.Ready)
                    SS.CyberGlove.TrainFile = fullfile(SS.FullDataFolder,['\CyberGloveTrainingData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                    SS.CyberGlove.FID = fopen(SS.CyberGlove.TrainFile,'w+');
                    fwrite(SS.CyberGlove.FID,[length(SS.XippTS);length(SS.Z);length(SS.X);length(SS.T);length(SS.XHat);length(SS.CyberGlove.Kinematics)],'single'); %writing header
                end
                if(SS.LEAP.Ready)
                    SS.LEAP.TrainFile = fullfile(SS.FullDataFolder,['\LEAPTrainingData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                    SS.LEAP.FID = fopen(SS.LEAP.TrainFile,'w+');
                    fwrite(SS.LEAP.FID,[length(SS.XippTS);length(SS.Z);length(SS.X);length(SS.T);length(SS.XHat);length(SS.LEAP.Kinematics);length(SS.LEAP.Connected);length(SS.LEAP.IsRight);length(SS.LEAP.Kinematics2);length(SS.LEAP.Connected2);length(SS.LEAP.IsRight2)],'single'); %writing header
                    SS.LEAP.TRAININGDATA = [];
                end
                if SS.RecordIMUwithTraining
                    
                    %imuStartRecordTS = imustart(SS.shimmerIMU);
                    SS.shimmerIMUTrainFile = fullfile(SS.FullDataFolder,['\IMUTrainingData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                    SS.shimmerIMUTrainFID = fopen(SS.shimmerIMUTrainFile,'w+');
                    fwrite(SS.shimmerIMUTrainFID,[length(SS.XippTS);length(SS.shimmerIMU);length(SS.shimmerIMUData)],'single'); %writing header
                    
                    %fprintf(SS.CogLoadFID,'TrainingSetStart,NIPTime=%0.0f,ShimmerUnixTime_ms=%0.0f\r\n', ...
                    %    [SS.XippTS - SS.RecStart, imuStartRecordTS]);
                end
                disp('Training started')
            case 'StopAcqBaseline'
                fclose(SS.BaselineFID);
                [~,Z] = readKDF(SS.BaselineFile);
                SS.BaselineData = mean(Z,2);
                disp('Stopping AcqBaseline')
            case 'StopAcqCAR'
                fclose(SS.CARFID);
                disp('Generating CAR Weights')
            case 'StopTraining' %SS.AcqTraining=0;
                fclose(SS.KDFTrainFID);
                fclose(SS.KEFTrainFID);
                if(SS.CyberGlove.Ready)
                    fclose(SS.CyberGlove.FID);
                end
                if(SS.LEAP.Ready)
                    fclose(SS.LEAP.FID); % close file, save mat raw data.
                    TRAININGDATA = fullfile(SS.FullDataFolder,['\LEAPRawTrainingData_',SS.DataFolder,'_',SS.DateStr,'.mat']);
                    LEAPFrames = SS.LEAP.TRAININGDATA;
                    save(TRAININGDATA,'LEAPFrames');
                end
                [~,fname] = fileparts(SS.KDFTrainFile);
                fwrite(SS.UDPEvnt,sprintf('StopAcqTraining:KDFFile=%s.kdf;',fname));
                
                if SS.RecordIMUwithTraining
                    %imuStopRecordTS = imustop(SS.shimmerIMU);
                    %fprintf(SS.CogLoadFID,'TrainingSetEnd,NIPTime=%0.0f,ShimmerUnixTime_ms=%0.0f\r\n', ...
                    %[SS.XippTS - SS.RecStart, imuStopRecordTS]);
                    
                    fclose(SS.shimmerIMUTrainFID);
                end
                
                disp('Training stopped')
            case 'Success'
                SS.TargOn = 0;
            case 'TargOn' %acquiring targon event during training
                SS.TargOn = 1; % MDP 20200125
                if SS.AcqTraining && strcmp(SS.KinSrc,'Training')
                    if exist(SS.KEFTrainFile,'file')
                        fprintf(SS.KEFTrainFID,'SS.TargOnTS=%0.0f;',SS.XippTS-SS.RecStart);
                    end
                end
                if SS.EEGTrigger && (strcmp(SS.KinSrc, 'Decode')) % MDP 20190813
                    % send trigger
                    disp('Send EEG Trigger')
                    xippmex_1_12('digout',5,targ2EEGEvent(SS.TargRad, SS.T, 'TargOn'))
                end
                if SS.SecondaryTask
                    if ~SS.CogLoadStimOn
                        SS.CogLoadNextStimTS = SS.CurrTS + ... % min + random up to var (*30 for 30k timestamp)
                            30*(SS.SecondaryTaskMinBetweenStim + SS.SecondaryTaskVarBetweenStim*rand());
                    end
                end
            case 'UpdateFreeParam'
                SS.AdaptOnline.AdaptationRate = SS.FreeParam;
                disp('Updating Free Parameter')
            case 'UpdateKGainThresh' %executes when KalmanGain, KalmanThresh, CtrlMode, CtrlSpeed in LV are changed
                if size(SS.xhat,1)~=length(SS.KalmanMvnts) %executes if KalmanUEA, KalmanEMG, or KalmanMvnts are changed on the LV side (ApplyTraining must occur after this)
                    SS = resetKalman(SS);
                    disp('Resetting Kalman...')
                end
                if isfield(SS,'TrainParamsFile')
                    if exist(SS.TrainParamsFile,'file')
                        save(SS.TrainParamsFile,'-append','-struct','SS','KalmanGain','KalmanThresh')
                    end
                end
                if any(strcmp(SS.CtrlMode,'Velocity')) %position is fed directly to VRE velocity
                    SS.BakeoffDirect = 1;
                else
                    SS.BakeoffDirect = 0;
                end
            case 'UpdateThresh'
                if SS.SelIdx<=SS.NumNeuralIdxs
                    switch SS.ThreshMode
                        case {0,'RMS Single'}
                            SS.ThreshRMS(SS.SelIdx) = mean(SS.NeuralRMSBuff(SS.SelIdx))*SS.ThreshVal;
                            disp('RMS Single')
                        case {1,'RMS All'}
                            SS.ThreshRMS = mean(SS.NeuralRMSBuff,2)*SS.ThreshVal;
                            disp('RMS All')
                        case {2,'RMS Auto'}
                            disp('RMS Auto')
                        case {3,'Volt Single'}
                            SS.ThreshRMS(SS.SelIdx) = SS.ThreshVal;
                            disp('Voltage Single')
                        case {4,'Volt All'}
                            SS.ThreshRMS = repmat(SS.ThreshVal,length(SS.ThreshRMS),1);
                            disp('Voltage All')
                    end
                end
            case 'ExportTraining'
                disp('Exporting Training File for Nomad')
                SS.ExportTrainFile = [SS.DataDir,'\',SS.DataFolder,'\ExportTraining_',SS.DataFolder,'_',SS.DateStr,'.mat'];
                TF = load(SS.TrainParamsFile);
                if isfield(TF,'TRAIN')
                    %                     SS.SSTRAIN = TF.SSTRAIN;
                    SS.TRAIN = TF.TRAIN;
                    if exist(SS.ExportTrainFile,'file')
                        SS.ExportTrainFile = [SS.ExportTrainFile(1:end-4),'_',datestr(clock,'HHMMSS'),'.mat'];
                    end
                    save(SS.ExportTrainFile,'-struct','SS',...
                        'ApplyBaseline','AvailNeuralIdx','AvailNeural','AvailEMGIdx','AvailEMG',...
                        'BaselineData','BadEMGChans','KalmanElects','BaseLoopTime','BadKalmanIdxs','CtrlMode','CtrlSpeed',...
                        'EMGChanList',...
                        'KalmanEMG','KalmanElects','KalmanIdxs','KernelWidth','KEMGExtra','KalmanMvnts','KalmanGain','KalmanThresh','KalmanType','KDFTrainFile','KEFTrainFile',...
                        'LinkedDOF','NeuralChanList','NeuralSurrIdxs','NumDOF','NumNeuralIdxs','NumEMGIdxs','NumNeuralChans','NumNeuralElects','NumUEAs','MapType',...
                        'ReTrain','TRAIN','ThreshMode','ThreshVal','ThreshRMS'); %% Removed SSTRAIN 7/30/18
                    disp('Saved ExportTrain.mat file')
                    try
                        load2nomad(SS.ExportTrainFile)
                        disp ('Training exported with SS Kalman parameters')
                        %                         Do this is AUX  nb bxl_build('runK')
                        %disp ('runKalman compiled on nomad')
                    catch
                        disp ('Training export failed')
                    end
                else
                    disp('Fail: Error with TF.TRAIN structure')
                end
                % call Aux to compile the training parameters to the Nomad
                fwrite(SS.UDPEvntAux,sprintf('ExportTraining:SS.ExportTrainFile=''%s'';',regexprep(SS.ExportTrainFile,':','@')));
                disp('Calling Compile2Nomad')
            case 'ResetTrial'
                SS.betaValues = SS.betaValues(randperm(numel(SS.betaValues)));
                SS.betaIdx = 1;
                SS.AdaptOnline.AdaptationRate = SS.betaValues(SS.betaIdx);
                disp({'Beta Values:' num2str(SS.betaValues)})
            case 'ConnectECG'
                if SS.ConnectECG % connect shimmer ECG device
                    [SS.shimmerECG, ~] = ecgconnect();
                else % disconnect
                    if isfield(SS,'shimmerECG')
                        ecgdisconnect(SS.shimmerECG);
                    end
                end
            case 'ConnectIMU'
                if SS.ConnectIMU % connect shimmer IMU
                    [SS.shimmerIMU, ~,SS.shimmerIMU_Ready] = imuconnect(3);
                    
                    % Starting IMU task file
                    SS.shimmerIMUData = zeros(1,10*length(SS.shimmerIMU));
                    SS.shimmerIMUTaskFile = fullfile(SS.FullDataFolder,['\IMUTaskData_',SS.DataFolder,'_',SS.DateStr,'.kdf']);
                    SS.shimmerIMUTaskFID = fopen(SS.shimmerIMUTaskFile,'w+');
                    fwrite(SS.shimmerIMUTaskFID, [length(SS.XippTS);length(SS.shimmerIMU);length(SS.shimmerIMUData)],'single'); %writing header
                    
                    for i = 1:length(SS.shimmerIMU)
                        SS.shimmerIMU(i).start;
                    end
                else %  disconnect
                    if isfield(SS,'shimmerIMU')
                        imudisconnect(SS.shimmerIMU);
                    end
                end
        end %switch
    catch ME
        assignin('base','ME',ME)
        if isempty(ME.stack)
            fprintf('failed on labview command: %s\nmessage: %s\n',LVStr,ME.message);
        else
            fprintf('failed on labview command: %s\nmessage: %s\nname: %s\nline: %0.0f\n',LVStr,ME.message,ME.stack(1).name,ME.stack(1).line);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = acqAuxEvents(SS)

if isfield(SS,'f')
    if strcmp(SS.f.State,'finished')
        tmpSS = fetchOutputs(SS.f);
        objFields = fieldnames(tmpSS);
        
        for k = 1:length(objFields)
            SS(1).(objFields{k}) = tmpSS(1).(objFields{k});
        end
        % to do: step through field names, case statement
        %         SS.ARD1 = tmpSS.ARD1;
        %         if SS.ARD1.Ready
        %             disp('3DHand Connected')
        %         else
        %             disp('3DHand Not Connected')
        %         end
        delete(SS.f)
        SS = rmfield(SS,'f');
    end
end

% Waiting for UDP packet from MLAux
if SS.UDPEvntAux.BytesAvailable
    MLAuxStr = fscanf(SS.UDPEvntAux);
    disp(MLAuxStr)
    try
        MLAuxCell = regexp(MLAuxStr,':','split');
        % Execute cases that match term preceding ":" operator
        switch MLAuxCell{1}
            case 'CalibrateDEKAFinished'
                disp('DEKA Calibration Finished...')
            case 'AlignData'
                eval(regexprep(MLAuxCell{length(MLAuxCell)},'@',':'));
            case 'AutoPop'
                SS.EvntStr = ['AutoPop:',MLAuxCell{length(MLAuxCell)}];
                fwrite(SS.UDPEvnt,SS.EvntStr); %sending back to LV to populate front panel
                disp('received auto channel selection')
            case 'GenVRWeights'
                % load in weights from createCARMatrix
                disp('received NN_VR file from Aux loop, loading weights into SS.VRSurrIdx')
                eval(MLAuxCell{length(MLAuxCell)});
                SS.WeightsFile = regexprep(SS.WeightsFile,'@',':');
                load(SS.WeightsFile,'-mat'); % loads variable 'weightsMatrix'
                SS.VRSurrIdxs = weightsMatrix;  % SS.VRSurrIdxsGPU = gpuArray(SS.VRSurrIdxs);
            case 'AuxTrainingFinished'
                disp('Received Training from Aux')
                SS = resetKalman(SS); %zeros out Kalman variables
                TF = load(SS.TrainParamsFile);
                SS.subX = TF.subX;
                SS.subZ = TF.subZ;
                SS.subK = TF.subK;
                SS.subT = TF.subT;
                SS.TRAIN = TF.TRAIN;
                % update NN data into SS struct
                if isfield(TF, 'NN_Python')
                    SS.NN_Python = TF.NN_Python;
                    SS.NN_Python.TRAIN.socket = py.socket_client.socket_client('127.0.0.1', 12000, 1000);
                end
                if isfield(TF, 'NN_classifier_Python_trained')
                    SS.NN_classifier_Python.TRAIN.max_movement = TF.max_movement;
                    SS.NN_classifier_Python_trained = TF.NN_classifier_Python_trained;
                    SS.NN_classifier_Python.TRAIN.LUT = csvread('//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/LUT_movements_goal.csv');
                    SS.socket_python = py.socket_client.socket_client('127.0.0.1', 12000, 1000);
                end
                
                % smw 1/11/17 for DWPRR decode
                if isfield(TF, 'normalizerZ')
                    SS.minZ = TF.minZ;
                    SS.w = TF.w;
                    SS.normalizerZ = TF.normalizerZ;
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%% COB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %                 SS = sendDecode2NIP(SS);
                %
                %                 SS.pIdx = 1;
                %                 SS.pBuffSize = 300;
                %                 SS.pBuff = zeros(length(SS.KalmanMvnts),SS.pBuffSize);
                % %                 SS.pBuff = zeros(length(SS.KalmanIdxs),SS.pBuffSize);
                %                 SS.fH = figure('windowstyle','docked');
                %                 SS.aH = axes('parent',SS.fH);
                %                 SS.pH = plot(SS.aH,1:SS.pBuffSize,SS.pBuff');
                %                 hold on
                %                 SS.pH(end+1) = plot(SS.aH,[SS.pIdx,SS.pIdx],[-1000,1000],'r');
                %                 hold off
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                fwrite(SS.UDPEvnt,'TrainingFinished:');
            case 'AuxBakeoffFinished'
                mj_close;
                SS.EvntStr = sprintf('BakeoffFinished:');
                SS.StartBakeoff = false;
                SS.VREStatus = false;
                SS.VREInfo.IDIdx = 0;
                SS.VREInfo.IDLabel = '';
                SS.VREInfo.HandType = '';
                fwrite(SS.UDPEvnt,SS.EvntStr);
                disp('Sending Bakeoff finished back to Labview')
                eval(MLAuxCell{length(MLAuxCell)}); % smw
                SS.DateStr = datestr(clock,'HHMMSS');
                switch TestType
                    case 'Bakeoff11'
                        result = reshape(result,4,[])';
                    case 'Bakeoff21'
                        result = reshape(result,18,[])';
                    case 'Bakeoff31'
                        result = reshape(result,2,[])';
                    case 'Bakeoff32'
                        result = reshape(result,3,[])';
                    case 'Bakeoff32_Checkers'
                        result = reshape(result,3,[])';
                    case 'Bakeoff32_Pen'
                        result = reshape(result,3,[])';
                    case 'Bakeoff32_Ball'
                        result = reshape(result,3,[])';
                    case 'FragileBlock'
                        result = reshape(result,5,[])';
                end
                resultFileName = fullfile(SS.FullDataFolder,['\',TestType, '_', SS.DataFolder, '_', SS.DateStr,'.mat']);
                save(resultFileName, 'result', 'TestType');
            case 'AuxCompile2NomadFinished'
                disp ('Training Compiled on Nomad')
        end
    catch ME
        assignin('base','ME',ME)
        if isempty(ME.stack)
            fprintf('failed on labview command: %s\nmessage: %s\n',MLAuxStr,ME.message);
        else
            fprintf('failed on labview command: %s\nmessage: %s\nname: %s\nline: %0.0f\n',MLAuxStr,ME.message,ME.stack(1).name,ME.stack(1).line);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read kinematics/targets from LV and sending data back to LV
function SS = acqCont(SS)
if SS.UDPCont.BytesAvailable
    %     SS.ContLV = fread(SS.UDPCont,SS.NumDOF*2+6,'single');
    SS.ContLV = fread(SS.UDPCont,SS.NumDOF*2+6+13+8+12+4,'single'); %6 target values from MSMS, 13 DEKA sensors, 8 DEKA motors, 12 manual dof
    
    % Kinematics and targets from LV
    SS.X = SS.ContLV(1:SS.NumDOF); %thumb,index,middle,ring,little,thumbint,indexint,ringint,littleint,wristpitch,wristyaw,wristroll
    SS.T = SS.ContLV(SS.NumDOF+1:SS.NumDOF*2);
    
    % Continuous frequencies for 6 targets on MSMS hand
    SS.ContStimMSMS = SS.ContLV(25:30);
    
    
    % Continuous sensor values from DEKA (update past values first)
    % no longer being used - JAG - 10/3/17
    %     SS.PastDEKASensors(:,5) = SS.PastDEKASensors(:,4);
    %     SS.PastDEKASensors(:,4) = SS.PastDEKASensors(:,3);
    %     SS.PastDEKASensors(:,3) = SS.PastDEKASensors(:,2);
    %     SS.PastDEKASensors(:,2) = SS.PastDEKASensors(:,1);
    %     SS.PastDEKASensors(:,1) = SS.ContDEKASensors;
    %     SS.ContDEKASensors = SS.ContLV(31:43);
    
    
    % Continuous motor values from DEKA (update past values first)
    % no longer being used - JAG - 10/3/17
    %     SS.PastDEKAMotors(:,4) = SS.PastDEKAMotors(:,3);
    %     SS.PastDEKAMotors(:,3) = SS.PastDEKAMotors(:,2);
    %     SS.PastDEKAMotors(:,2) = SS.PastDEKAMotors(:,1);
    %     SS.PastDEKAMotors(:,1) = SS.ContDEKAMotors;
    %     SS.ContDEKAMotors = SS.ContLV(44:51);
    
    % Continuous manual dof checkbox
    SS.ManualDOF = logical(SS.ContLV(52:63));
    
    % Continuous analog sensor values from NI DAQmx (update past values first)
    SS.AnalogSensors(:,6) = SS.AnalogSensors(:,5);
    SS.AnalogSensors(:,5) = SS.AnalogSensors(:,4);
    SS.AnalogSensors(:,4) = SS.AnalogSensors(:,3);
    SS.AnalogSensors(:,3) = SS.AnalogSensors(:,2);
    SS.AnalogSensors(:,2) = SS.AnalogSensors(:,1);
    SS.AnalogSensors(:,1) = SS.ContLV(64:67) / 5; %thumb(64),index,middle,ring(67) -- divide to normalize 0 to 1
    
    if(SS.CyberGlove.Ready)
        tempIdx = 63;
        for ii = 1:length(SS.CyberGlove.Kinematics)
            SS.CyberGlove.Kinematics(ii) = SS.CyberGlove.Eqs{ii}(SS.ContLV(tempIdx + ii));
        end
    end
    
    if(SS.LEAP.Ready)
        [SS.LEAP.Kinematics,SS.LEAP.Connected,SS.LEAP.IsRight,SS.LEAP.Kinematics2,SS.LEAP.Connected2,SS.LEAP.IsRight2, SS.LEAP.Frame] = sampleLeapMotion();
        %         disp(SS.LEAP.Kinematics(1))
    end
    
    % Checking VREID
    if isfield(SS.VREInfo,'IDIdx')
        if isempty(SS.VREInfo.IDIdx)
            SS.VREInfo.IDIdx = 0;
        end
    else
        SS.VREInfo.IDIdx = 0;
    end
    
    % Sending back to LV
    %      disp(num2str(SS.X)); %smw
    
    if ~isempty(SS.StimChan) && ismember(SS.StimChan(1), SS.AvailStimList)
        [~,~,SS.StimWfCell] = xippmex_1_12('spike',SS.StimChan(1),1);
        if ~isempty(SS.StimWfCell{1})
            %             SS.StimWf = SS.StimWfCell{1}{1}(:);
            SS.StimWf = SS.StimWfCell{1}(1,:)';
        end
    end
    % send data to labview
    SS.ContML = [SS.TrainCnt;SS.MCalcTime;SS.MTotalTime;SS.XHat;...
        SS.X;length(SS.NeuralElectRatesMA);SS.NeuralElectRatesMA;SS.EMGPwrMA;SS.ThreshRMS(SS.SelIdx);...
        length(SS.SelData);SS.SelData;SS.SelWfs(:);SS.XippTS-SS.RecStart;SS.VREInfo.IDIdx;SS.StimWf;SS.ContDEKASensors;SS.decodeOutput;SS.TASKASensors.IR;SS.TASKASensors.baro];
    fwrite(SS.UDPCont,typecast(flipud(single(SS.ContML)),'uint8'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Collecting training data
function SS = acqTraining(SS)
% Waiting for train flag from labview
if SS.AcqTraining
    fwrite(SS.KDFTrainFID,[SS.XippTS-SS.RecStart;SS.Z;SS.X;SS.T;SS.XHat],'single'); %saving data to fTraining file (*.kdf filespec, see readKDF)
    %write cyberglove KDF file if connected and enabled
    if(SS.CyberGlove.Ready)
        fwrite(SS.CyberGlove.FID,[SS.XippTS-SS.RecStart;SS.Z;SS.X;SS.T;SS.XHat;SS.CyberGlove.Kinematics],'single');
    end
    if(SS.LEAP.Ready)
        fwrite(SS.LEAP.FID,[SS.XippTS-SS.RecStart;SS.Z;SS.X;SS.T;SS.XHat;SS.LEAP.Kinematics;SS.LEAP.Connected;SS.LEAP.IsRight;SS.LEAP.Kinematics2;SS.LEAP.Connected2;SS.LEAP.IsRight2],'single');
        SS.LEAP.TRAININGDATA = [SS.LEAP.TRAININGDATA SS.LEAP.Frame];
    end
    if SS.shimmerIMU_Ready
        fwrite(SS.shimmerIMUTrainFID,[SS.XippTS-SS.RecStart,SS.shimmerIMUData],'single');
    end
    SS.TrainCnt = SS.TrainCnt + 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Collecting baseline data for CAR and training
function SS = acqBaseline(SS)
if SS.AcqBaseline
    fwrite(SS.BaselineFID,[SS.XippTS-SS.RecStart;SS.Z;SS.X;SS.T;SS.XHat],'single');
    SS.TrainCnt = SS.TrainCnt + 1;
end
if SS.AcqCAR
    fwrite(SS.CARFID,[SS.dNeural;nan(SS.DLNeuralMax-SS.DLNeural,SS.NumUEAs*96)],'single');
    SS.TrainCnt = SS.TrainCnt + 1;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Kalman testing (decode testing)
function SS = runTesting(SS)
switch SS.KinSrc
    case 'Decode'
        SS.COBFlag = false;
        switch SS.KalmanType
            case {0,'Standard'} %standard
                SS.xhat = kalman_test(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
            case {1,'Mean'} % mean subtracted (MRB, MDP updated to include bias term)
                SS.xhat = kalman_test_bias(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
            case {2,'Refit'} %refit velocity decode
                SS.xhat = kalman_test_vel(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
            case {3,'LinSVReg'} % LinSVReg smw
                %SS.xhat = LinSVReg_test(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
                sameLead =  [197:202, 207:212, 217:222,...
                    227:232, 237:242, 247:252, 257:262, 267:272];
                tempZ = SS.Z(sameLead)./SS.TRAIN.ZMax;
                tempZ(isnan(tempZ)) = 0;
                tempVel = HOLD_Test(tempZ,SS.TRAIN);
                tempVel = tempVel([SS.KalmanMvnts SS.KalmanMvnts+12]);
                
                posInd = SS.xhat>0;
                negInd = SS.xhat<0;
                neutInd = SS.xhat == 0;
                
                posInd(neutInd&(tempVel([true(size(neutInd)); false(size(neutInd))])>...
                    tempVel([false(size(neutInd));true(size(neutInd))]))) = 1;
                negInd(neutInd&(tempVel([true(size(neutInd)); false(size(neutInd))])<...
                    tempVel([false(size(neutInd));true(size(neutInd))]))) = 1;
                
                SS.xhat(posInd) = SS.xhat(posInd) + tempVel(...
                    [posInd;false(size(posInd))]);
                SS.xhat(posInd&SS.xhat<0)=0;
                
                SS.xhat(negInd) = SS.xhat(negInd)-tempVel(...
                    [false(size(negInd));negInd]);
                SS.xhat(negInd&SS.xhat>0)=0;
                
                SS.xhat(SS.xhat>1) = 1;
                SS.xhat(SS.xhat<-1) = -1;
                
            case {4,'NonLinSVReg'} % NonLinSVReg smw
                %SS.xhat = NonLinSVReg_test(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
                SS.xhat = kalman_test_bias(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
            case {6, 'DWPRR'} % smw 1/11/17
                tempZ = SS.Z(SS.KalmanIdxs)-SS.minZ;
                %                 tempZ = nthroot(tempZ,3);
                tempZ = tempZ./SS.normalizerZ;
                tempZ = nthroot(tempZ,3);
                tempZ = [tempZ; 1];
                tempFeat = (SS.w'*tempZ).^3;
                SS.xhat = kalman_test(tempFeat,SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
                
                %                 % add together method:
                %                 tempMat = repmat(eye(numel(SS.KalmanMvnts)),1,2);
                %                 SS.xhat = tempMat*tempFeat;
            case {7,'AdaptKF'}
                % Set Goals with noise
                Targets = SS.T(SS.KalmanMvnts);
                idx = Targets == 0;
                %                 if max(Targets + SS.GoalNoiseFixed) > 0.5 %%% if statement added temporarily 7/11/18 for P201701 visit; revert to contents of else statement by next visit and/or intact experiments (TCH)
                %                     SS.AdaptOnline.GoalX = Targets - SS.GoalNoiseFixed; % put noise on other side of target (i.e. side that can be remedied by flexion if only flexion trained)
                %                 else
                SS.AdaptOnline.GoalX = Targets + SS.GoalNoiseFixed;
                %                 end
                SS.AdaptOnline.GoalX(idx) = 0;
                % Check if goals are not over 1 and under -1
                idx = SS.AdaptOnline.GoalX > 1;
                SS.AdaptOnline.GoalX(idx) = 1;
                idx = SS.AdaptOnline.GoalX < -1;
                SS.AdaptOnline.GoalX(idx) = -1;
                % Call kalman test with trajectory adapt
                SS.xhat = kalman_test_adaptation(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0, SS.AdaptOnline, SS.KalmanThresh);
            case {8,'NN'}
                try
                    SS.xhat = predict(SS.NN.net,SS.NN.FeatureBuffer);  %predict values
                    SS.NN.Prediction = SS.xhat;
                    if(SS.NN.postKalman)
                        SS.xhat = kalman_test(SS.xhat',SS.NN.postKalmanTRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0)';
                    end
                    SS.xhat = SS.xhat(SS.KalmanMvnts)';
                catch
                    SS.xhat = zeros(length(SS.KalmanMvnts),1);
                    disp('NN prediction failed.');
                    if(SS.NN.postKalman)
                        disp('reset kalman.')
                        kalman_test(zeros(1,12),SS.NN.postKalmanTRAIN,[-1,1],1);
                    end
                    
                end
            case {9,'NN_python'}
                try
                    if isfield(SS, 'NN_Python')
                        if isfield(SS.NN_Python, 'TRAIN')
                            % Set Goals with noise
                            Targets = SS.T(SS.KalmanMvnts);
                            idx = Targets == 0;
                            %                             if max(Targets + SS.GoalNoiseFixed) > 0.5 %%% if statement added temporarily 7/11/18 for P201701 visit; revert to contents of else statement by next visit and/or intact experiments (TCH)
                            %                                 SS.AdaptOnline.GoalX = Targets - SS.GoalNoiseFixed; % put noise on other side of target (i.e. side that can be remedied by flexion if only flexion trained)
                            %                             else
                            SS.AdaptOnline.GoalX = Targets + SS.GoalNoiseFixed;
                            %                             end
                            SS.AdaptOnline.GoalX(idx) = 0;
                            % Check if goals are not over 1 and under -1
                            idx = SS.AdaptOnline.GoalX > 1;
                            SS.AdaptOnline.GoalX(idx) = 1;
                            idx = SS.AdaptOnline.GoalX < -1;
                            SS.AdaptOnline.GoalX(idx) = -1;
                            % Call kalman test with trajectory adapt
                            xhat = test_NN_python(SS.Z(SS.KalmanIdxs), SS.XHat(SS.KalmanMvnts), ...
                                SS.NN_Python.TRAIN, 0);
                            combine = 0.02;
                            C = 4;
                            
                            X_filt = combine * xhat + (1 - combine) * SS.XHat(SS.KalmanMvnts);
                            deltaX_squared = C*(X_filt-xhat).^2;
                            deltaX_squared(deltaX_squared>1) = 1;
                            SS.xhat = deltaX_squared.*xhat + (1-deltaX_squared).*X_filt;
                            try
                                xhat = SS.xhat;
                                AdaptOnline = SS.AdaptOnline;
                                thresh = SS.KalmanThresh;
                                if AdaptOnline.ShouldAdapt == true && ~isempty(AdaptOnline.GoalX)
                                    for iXhat = 1:size(xhat,1)
                                        if AdaptOnline.GoalX(iXhat)>0
                                            xhat(iXhat) = xhat(iXhat) - AdaptOnline.AdaptationRate *...
                                                (xhat(iXhat) - ((AdaptOnline.GoalX(iXhat))*(1-thresh(iXhat,1))+thresh(iXhat,1)));
                                        elseif AdaptOnline.GoalX(iXhat)<0
                                            xhat(iXhat) = xhat(iXhat) - AdaptOnline.AdaptationRate *...
                                                (xhat(iXhat) - ((AdaptOnline.GoalX(iXhat))*(1-thresh(iXhat,2))-thresh(iXhat,2)));
                                        else
                                            xhat(iXhat) = xhat(iXhat) - AdaptOnline.AdaptationRate *...
                                                (xhat(iXhat));
                                        end
                                    end
                                end
                                SS.xhat = xhat;
                            catch
                                disp('Something wrong with goal adaptation')
                            end
                        end
                    end
                catch ME2
                    if isempty(ME2.stack)
                        fprintf('message: %s\r\n',ME2.message);
                    else
                        fprintf('message: %s; name: %s; line: %0.0f\r\n',ME2.message,ME2.stack(1).name,ME2.stack(1).line);
                    end
                    disp("NN python prediction failed")
                    SS.xhat = zeros(length(SS.KalmanMvnts),1);
                end
            case {10,'AdaptKF2'}
                % Set Goals with noise
                Targets = SS.T(SS.KalmanMvnts);
                idx = Targets == 0;
                SS.AdaptOnline.GoalX = Targets + SS.GoalNoiseFixed;
                SS.AdaptOnline.GoalX(idx) = 0;
                % Check if goals are not over 1 and under -1
                idx = SS.AdaptOnline.GoalX > 1;
                SS.AdaptOnline.GoalX(idx) = 1;
                idx = SS.AdaptOnline.GoalX < -1;
                SS.AdaptOnline.GoalX(idx) = -1;
                % Call kalman test with trajectory adapt
                SS.xhat = kalman_test_adaptation2(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0, SS.AdaptOnline, SS.KalmanThresh);
            case {11, 'KF_Short_Goal'} %JAG added on 3/27/19 - case for new shared controller with OSU
                %replace line below, make sure SS.xhat is populated at the
                %end of this case execution
                if isfield(SS, 'TRAIN')
                    if isfield(SS, 'NN_classifier_Python_trained')
                        if SS.NN_classifier_Python_trained == 1
                            ans_client = SS.socket_python.test_classification(SS.Z(SS.KalmanIdxs));
                            
                            char_array = ans_client.char;
                            trimmed_char_array = [char_array(3:end-2), '}'];
                            value = jsondecode(trimmed_char_array);
                            predictions = value.data;
                            %class_predicted = find(predictions==max(predictions));
                            movement = SS.NN_classifier_Python.TRAIN.LUT(predictions+1, :);
                            SS.AdaptOnline.GoalX = movement(SS.KalmanMvnts);
                            
                            SS.xhat = kalman_test_adaptation_limited(SS.Z(SS.KalmanIdxs),SS.TRAIN,...
                                [-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0, ...
                                SS.AdaptOnline, SS.KalmanThresh, ...
                                SS.NN_classifier_Python.TRAIN.max_movement);
                            %SS.xhat = kalman_test(SS.Z(SS.KalmanIdxs),SS.TRAIN,[-1./SS.KalmanGain(:,2),1./SS.KalmanGain(:,1)],0);
                        end
                        
                    end
                end
                
        end
        KM = false(12,1); KM(SS.KalmanMvnts) = true;
        SS.xhat(SS.ManualDOF(SS.KalmanMvnts)) = SS.X(SS.ManualDOF & KM);
    case 'COB'
        %%%%%%%%%%%%%%%%%%%%%%%%%%%% COB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if SS.UDPNIP.BytesAvailable
            %             disp(SS.UDPNIP.BytesAvailable)
            SS.COBFlag = true;
            try
                SS.xhat = zeros(length(SS.KalmanMvnts),1);
                SS.xhatout = fread(SS.UDPNIP,[length(SS.KalmanMvnts),1],'double');
                %                 SS.xhatout = fread(SS.UDPNIP,[length(SS.KalmanIdxs),1],'double');
                disp(length(SS.xhatout))
                
                if length(SS.xhatout)==length(SS.KalmanMvnts)
                    %                     disp(SS.UDPNIP.BytesAvailable)
                    SS.pBuff(:,SS.pIdx) = SS.xhatout;
                    %                     SS.pBuff(:,SS.pIdx) = SS.Z(SS.KalmanIdxs);
                    for k=1:size(SS.pBuff,1)
                        set(SS.pH(k),'ydata',SS.pBuff(k,:));
                    end
                    set(SS.pH(end),'xdata',[SS.pIdx,SS.pIdx])
                    if SS.pIdx<SS.pBuffSize
                        SS.pIdx = SS.pIdx+1;
                    else
                        SS.pIdx = 1;
                    end
                end
            catch
                disp('e')
            end
            
            SS.xhatout(length(SS.KalmanMvnts)+1:end) = [];
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case 'LEAP'
        SS.xhat = zeros(12,1);
        if(SS.LEAP.Ready)
            [kin, ~, RHFlag,kin2,conFlag,~] = sampleLeapMotion();
            if(SS.DEKA.RightHand)
                if(RHFlag)
                    SS.xhat = kin;
                else
                    if(conFlag)
                        SS.xhat = kin2;
                    end
                end
            else
                if(~RHFlag)
                    SS.xhat = kin;
                else
                    if(conFlag)
                        SS.xhat = kin2;
                    end
                end
            end
        end
        SS.xhat = SS.xhat(SS.KalmanMvnts);
    otherwise
        SS.COBFlag = false;
        SS.xhat = zeros(length(SS.KalmanMvnts), 1);
end

%unthresholded decode output (for visualization) - jag 10/4/17
pos = (SS.xhat>=0);
SS.decodeOutput = SS.xhat;
if any(pos)
    SS.decodeOutput(pos) = SS.decodeOutput(pos).*SS.KalmanGain(pos,1); %apply flexion gains/thresholds
end
if any(~pos)
    SS.decodeOutput(~pos) = SS.decodeOutput(~pos).*SS.KalmanGain(~pos,2); %apply extension gains/thresholds
end

if SS.LatchingFilter
    if ~isfield(SS,'xhatLF')
        SS.xhatLF = zeros(size(SS.xhat));
    elseif length(SS.xhat)~=length(SS.xhatLF)
        SS.xhatLF = zeros(size(SS.xhat));
    end
    [~, SS.xhatLF] = latch_filter(SS.xhat,SS.xhatLF,SS.LF_C,strcmp('Latching',SS.CtrlMode));
    SS.xhat = SS.xhatLF;
end

% applying gains and thresholds
if ~isempty(SS.xhat)
    
    if ~SS.COBFlag
        pos = (SS.xhat>=0); %check sign before applying gain/threshold
        
        %%%%%%%%%%%%%%%%%% Dynamic Thresholds %%%%%%%%%%%%%%%%%%%%%%%%%%
        SS.DynamicThresh = SS.KalmanThresh;
        if SS.DynFlag
            SS.DynamicThresh((SS.xhattiming*SS.BaseLoopTime)<0.5,:) = 0.2;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        if any(pos)
            SS.xhat(pos) = (SS.xhat(pos).*SS.KalmanGain(pos,1)-SS.DynamicThresh(pos,1))./(1-SS.DynamicThresh(pos,1)); %apply flexion gains/thresholds
        end
        if any(~pos)
            SS.xhat(~pos) = (SS.xhat(~pos).*SS.KalmanGain(~pos,2)+SS.DynamicThresh(~pos,2))./(1-SS.DynamicThresh(~pos,2)); %apply extension gains/thresholds
        end
        
        %%%%%%%%%%%%%%%%%% Dynamic Thresholds %%%%%%%%%%%%%%%%%%%%%%%%%%
        dynidx = ((SS.xhat>0 & ~pos) | (SS.xhat<0 & pos)); %xhat is below thresholds
        SS.xhattiming(~dynidx) = 0;
        SS.xhattiming(dynidx) = SS.xhattiming(dynidx) + 1;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        posidx = strcmp(SS.CtrlMode,'Position')|strcmp(SS.CtrlMode,'Velocity');
        SS.xhat(dynidx & posidx') = 0;
        SS.xhatout(posidx) = SS.xhat(posidx);
        
        latidx = strcmp(SS.CtrlMode,'Latching');
        SS.xhat(dynidx & latidx') = 0;
        SS.xhatout(latidx) = SS.xhat(latidx)*SS.BaseLoopTime.*SS.CtrlSpeed(latidx)'+SS.xhatout(latidx);
        
        leaidx = strcmp(SS.CtrlMode,'Leaky');
        cond1 = (SS.xhat<=0 & ~pos) | (SS.xhat>=0 & pos); %xhat is greater than threshold
        cond2 = ((SS.xhat>0 & ~pos) | (SS.xhat<0 & pos)) & SS.xhatout<=0; %xhat is less than threshold and xhatout is negative
        cond3 = ((SS.xhat>0 & ~pos) | (SS.xhat<0 & pos)) & SS.xhatout>=0; %xhat is less than threshold and xhatout is positive
        SS.xhatout(cond1 & leaidx') = SS.xhat(cond1 & leaidx')*SS.BaseLoopTime.*SS.CtrlSpeed(cond1 & leaidx')'+SS.xhatout(cond1 & leaidx');
        SS.xhatout(cond2 & leaidx') = min(abs(SS.xhat(cond2 & leaidx')*SS.BaseLoopTime.*SS.CtrlSpeed(cond2 & leaidx')')+SS.xhatout(cond2 & leaidx'),0);
        SS.xhatout(cond3 & leaidx') = max(-abs(SS.xhat(cond3 & leaidx')*SS.BaseLoopTime.*SS.CtrlSpeed(cond3 & leaidx')')+SS.xhatout(cond3 & leaidx'),0);
        
        %         switch SS.CtrlMode{1}
        %             case {0,'Position','Velocity'} %no integration
        %                 SS.xhat(SS.xhat<0 & pos) = 0;
        %                 SS.xhat(SS.xhat>0 & ~pos) = 0;
        %                 SS.xhatout = SS.xhat;
        %             case {1,'Latching'} %latching
        %                 SS.xhat(SS.xhat<0 & pos) = 0;
        %                 SS.xhat(SS.xhat>0 & ~pos) = 0;
        %                 SS.xhatout = SS.xhat*SS.BaseLoopTime*SS.CtrlSpeed(1)+SS.xhatout;
        %             case {2,'Leaky'} %leaky
        %                 cond1 = (SS.xhat<=0 & ~pos) | (SS.xhat>=0 & pos); %xhat is greater than threshold
        %                 cond2 = ((SS.xhat>0 & ~pos) | (SS.xhat<0 & pos)) & SS.xhatout<=0; %xhat is less than threshold and xhatout is negative
        %                 cond3 = ((SS.xhat>0 & ~pos) | (SS.xhat<0 & pos)) & SS.xhatout>=0; %xhat is less than threshold and xhatout is positive
        %                 SS.xhatout(cond1) = SS.xhat(cond1)*SS.BaseLoopTime*SS.CtrlSpeed(1)+SS.xhatout(cond1);
        %                 SS.xhatout(cond2) = min(abs(SS.xhat(cond2)*SS.BaseLoopTime*SS.CtrlSpeed(1))+SS.xhatout(cond2),0);
        %                 SS.xhatout(cond3) = max(-abs(SS.xhat(cond3)*SS.BaseLoopTime*SS.CtrlSpeed(1))+SS.xhatout(cond3),0);
        %         end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end %COBFlag
    
    SS.xhatout(SS.xhatout<-1) = -1; % apply limits to integrated signal
    if  SS.LimitExt
        xhatsub = SS.xhatout(SS.KalmanMvnts<=5); %changed from 9 to 5 to handle thumb intrinsic
        xhatsub(xhatsub<0) = 0;
        SS.xhatout(SS.KalmanMvnts<=5) = xhatsub;
    end
    SS.xhatout(SS.xhatout>1) = 1;
    SS.XHat(SS.KalmanMvnts) = SS.xhatout;
    
    % SS.LinkedDOF = {[1,3,4];[2,5];}; % example input, links 1,3,4 and 2,5
    if ~isempty(SS.LinkedDOF)
        try
            for k=1:length(SS.LinkedDOF)
                SS.XHat(SS.LinkedDOF{k}(2:end)) = SS.XHat(SS.LinkedDOF{k}(1));
            end
        catch ME
            if isempty(ME.stack)
                fprintf('message: %s\r\n',ME.message);
            else
                fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
            end
        end
    end
    
end

% sending output to DEKA
if SS.DEKA.Ready
    try
        %determine motor input
        switch SS.KinSrc
            case 'Training'
                CurrX = SS.X;
            case {'Decode','COB'}
                CurrX = SS.XHat;
            case 'Manual'
                CurrX = SS.XHat;
            otherwise
                CurrX = zeros(SS.NumDOF,1);
        end
        %temp fix (10/4/17 - jag) - simple PID control for DEKA wrist in velocity
        switch SS.KinSrc
            case {'Training','Decode','COB','Manual'}
                [CurrX(12), CurrX(10)] = wristPositionToVelocity(CurrX(12),CurrX(10),SS.DEKA.RightHand);
                %                     [CurrX(12), CurrX(10)] = wristPositionToVelocity_dk(CurrX(12),CurrX(10),SS.DEKA.RightHand); % might be faster, but less precise 20180413-dk
        end
        %end temp fix % removed for wrists in pos mode (dk 2018-03-16)
        
        %update DEKA position & get updated values of motors & sensors
        [motors, sensors] = updateDEKA(CurrX,SS.DEKA.RightHand);
        %         [motors, sensors] = updateDEKA_wristp(CurrX,SS.DEKA.Neutral,SS.DEKA.RightHand); % wrist in pos mode (dk 2018-03-16)
        %save raw data
        SS.DEKA.RAW.sensors = sensors;
        SS.DEKA.RAW.motors = motors;
        %         disp(SS.DEKA.RAW.sensors)
        %scale each motor to bounds of 0 to 1 or -1 to 1
        motors(1) = setLimit(motors(1)/7680,[-1,1]);
        motors(2) = setLimit(motors(2)/3520,[-1,1]);
        motors(3) = setLimit(motors(3)/5760,[0,1]);
        motors(4) = setLimit(motors(4)/5760,[0,1]);
        motors(7) = setLimit(motors(7)/6400,[0,1]);
        motors(8) = setLimit(motors(8)/5760,[0,1]);
        %interpolate between calibration component to normalize values
        %based on movement
        fudge = 1;
        BLineInterp(1) = (motors(3)*diff(SS.DEKA.BLSensors(1,:)) + SS.DEKA.BLSensors(1,1)) + fudge; % index_medial
        BLineInterp(2) = (motors(3)*diff(SS.DEKA.BLSensors(2,:)) + SS.DEKA.BLSensors(2,1)) + fudge; % index_distal
        BLineInterp(3) = (motors(4)*diff(SS.DEKA.BLSensors(3,:)) + SS.DEKA.BLSensors(3,1)) + fudge; % middle_distal
        BLineInterp(4) = (motors(4)*diff(SS.DEKA.BLSensors(4,:)) + SS.DEKA.BLSensors(4,1)) + fudge; % ring_distal
        BLineInterp(5) = (motors(4)*diff(SS.DEKA.BLSensors(5,:)) + SS.DEKA.BLSensors(5,1)) + fudge; % pinky_distal
        BLineInterp(6) = ((1-motors(4))*diff(SS.DEKA.BLSensors(6,:)) + SS.DEKA.BLSensors(6,1)) + fudge; % palm_distal
        BLineInterp(7) = ((1-motors(4))*diff(SS.DEKA.BLSensors(7,:)) + SS.DEKA.BLSensors(7,1)) + fudge; % palm_prox
        BLineInterp(8) = (motors(2)*diff(SS.DEKA.BLSensors(8,:)) + SS.DEKA.BLSensors(8,1)) + fudge; % palm_side
        BLineInterp(9) = (motors(2)*diff(SS.DEKA.BLSensors(9,:)) + SS.DEKA.BLSensors(9,1)) + fudge; % palm_back
        BLineInterp(10) = ((1-motors(8))*diff(SS.DEKA.BLSensors(10,:)) + SS.DEKA.BLSensors(10,1)) + fudge; % thumb_ulnar
        BLineInterp(11) = (motors(8)*diff(SS.DEKA.BLSensors(11,:)) + SS.DEKA.BLSensors(11,1)) + fudge; % thumb_medial
        BLineInterp(12) = (motors(7)*diff(SS.DEKA.BLSensors(12,:)) + SS.DEKA.BLSensors(12,1)) + fudge; % thumb_distal
        BLineInterp(13) = ((1-motors(7))*diff(SS.DEKA.BLSensors(13,:)) + SS.DEKA.BLSensors(13,1)) + fudge; % thumb_dorsal
        cSensors = sensors(10:22);
        pSensors = sensors(1:9);
        for i=1:length(cSensors)
            %subtract baseline, divide by maximum possible value
            val = (cSensors(i) - BLineInterp(i)) / (25.5-BLineInterp(i));
            %scale between 0 and 1
            cSensors(i) = setLimit(val,[0,1]);
        end
        %update past DEKA sensor & motor values
        SS.PastDEKASensors(:,5) = SS.PastDEKASensors(:,4);
        SS.PastDEKASensors(:,4) = SS.PastDEKASensors(:,3);
        SS.PastDEKASensors(:,3) = SS.PastDEKASensors(:,2);
        SS.PastDEKASensors(:,2) = SS.PastDEKASensors(:,1);
        SS.PastDEKASensors(:,1) = SS.ContDEKASensors;
        SS.PastDEKAMotors(:,4) = SS.PastDEKAMotors(:,3);
        SS.PastDEKAMotors(:,3) = SS.PastDEKAMotors(:,2);
        SS.PastDEKAMotors(:,2) = SS.PastDEKAMotors(:,1);
        SS.PastDEKAMotors(:,1) = SS.ContDEKAMotors;
        %update current sensor & motor values
        SS.ContDEKASensors =  cSensors;
        SS.ContDEKAPositions = pSensors;
        SS.ContDEKAMotors = motors;
        
    catch ME
        if isempty(ME.stack)
            fprintf('message: %s\r\n',ME.message);
        else
            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
        end
        SS.DEKA.Ready = 0;
    end
end

% sending output to VRE
try
    switch SS.KinSrc
        case 'Training'
            CurrX = SS.X;
        case {'Decode','COB'}
            CurrX = SS.XHat;
        case 'Manual'
            CurrX = SS.XHat;
        otherwise
            CurrX = zeros(SS.NumDOF,1);
    end
    
    if SS.StartBakeoff
        if SS.UDPContAux.BytesAvailable
            sensors = fread(SS.UDPContAux,17,'single');
            SS.VREInfo.sensors.contact = sensors(1:11);
            SS.VREInfo.sensors.motor_pos = sensors(12:17);
            switch SS.TestType
                case 'Bakeoff11'
                    fwrite(SS.UDPContAux,[MSMS2Luke_Bakeoff11(CurrX,SS.BakeoffDirect)*(SS.CtrlSpeed(1)*SS.BakeoffDirect + ~SS.BakeoffDirect);1;SS.BakeoffDirect],'single');
                case 'Bakeoff21'
                    fwrite(SS.UDPContAux,[MSMS2Luke_Bakeoff11(CurrX,SS.BakeoffDirect)*(SS.CtrlSpeed(1)*SS.BakeoffDirect + ~SS.BakeoffDirect);1;SS.BakeoffDirect],'single');
                case 'Bakeoff31'
                    fwrite(SS.UDPContAux,[MSMS2Luke_Bakeoff31(CurrX,SS.BakeoffDirect)*(SS.CtrlSpeed(1)*SS.BakeoffDirect + ~SS.BakeoffDirect);1;SS.BakeoffDirect],'single');
                case {'Bakeoff32','Bakeoff32_Ball','Bakeoff32_Checkers','Bakeoff32_Pen','FragileBlock'}
                    fwrite(SS.UDPContAux,[MSMS2Luke_Bakeoff32(CurrX,SS.BakeoffDirect)*(SS.CtrlSpeed(1)*SS.BakeoffDirect + ~SS.BakeoffDirect);1;SS.BakeoffDirect],'single');
            end
            saveVRE(SS,0); %saving vre data to binary file (flag 1 writes header)
        end
        
    else
        if SS.VREStatus
            switch SS.VREInfo.HandType
                case 'Luke'
                    SS.VRECommand.ref_pos(1:6) = MSMS2Luke(CurrX);
                case 'MPL'
                    SS.VRECommand.ref_pos(1:13) = MSMS2VRE(CurrX);
            end
            
            SS.VREInfo.mocap = mj_get_mocap;
            SS.VREInfo.state = mj_get_state;
            SS.VREInfo.sensors = hx_update(SS.VRECommand);
            SS = findVREID(SS);
            
            saveVRE(SS,0); %saving vre data to binary file (flag 1 writes header)
        end
    end
catch ME
    if isempty(ME.stack)
        fprintf('message: %s\r\n',ME.message);
    else
        fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    end
    if isfield(SS,'VREFID')
        fclose(SS.VREFID);
    end
    mj_close;
    SS.VREStatus = false;
    SS.VREInfo.IDIdx = 0;
    SS.VREInfo.IDLabel = '';
    SS.VREInfo.HandType = '';
end

% sending output to arduino
if SS.ARD1.Ready
    val = zeros(1,5);
    val(SS.XHat([2:5,1])> 0.1) = 1;
    SS.ARD1.Ready = ctrlRBArduino(val);
end

% sending output to open bionics hand
if SS.ARD3.Ready
    try
        %thumb, pinky, ring, middle, index, wristrotate, wristflex
        pos = [SS.XHat(1),SS.XHat(5),SS.XHat(4),SS.XHat(3),SS.XHat(2),SS.XHat(12),SS.XHat(10)];
        pos(pos<-1) = -1;
        pos(pos>1) = 1;
        [SS.PHandMotorVals,SS.PHandContactVals] = updateOB(SS.ARD3.Obj,pos);
        %         clc; disp(SS.PHandContactVals')
    catch ME
        disp('3DHand Ard3 connection failed at run testing...');
        if isempty(ME.stack)
            fprintf('message: %s\r\n',ME.message);
        else
            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
        end
        SS.ARD3.Ready = 0;
    end
end

% sending output to HANDi hand
if SS.ARD4.Ready
    try
        %thumb int, thumb, index, middle, ring, pinky
        pos = [SS.XHat(6),SS.XHat(1),SS.XHat(2),SS.XHat(3),SS.XHat(4),SS.XHat(5)];
        pos(pos<-1) = -1;
        pos(pos>1) = 1;
        [SS.HANDiHandMotorVals,SS.HANDiHandMotorPos,SS.HANDiHandContactVals] = updateHH(SS.ARD4.Obj,pos); %??
    catch ME
        disp('HANDiHand Ard4 connection failed at run testing...');
        if isempty(ME.stack)
            fprintf('message: %s\r\n',ME.message);
        else
            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
        end
        SS.ARD4.Ready = 0;
    end
end

% sending output to TASKA hand  dk 2018-01-26
if SS.TASKA.Ready
    try
        %determine motor input
        % DK added to try to get TASKA to move in training 20180504
        switch SS.KinSrc
            case 'Training'
                CurrX = SS.X;
            case {'Decode','COB'}
                CurrX = SS.XHat;
            case 'Manual'
                CurrX = SS.XHat;
            otherwise
                CurrX = zeros(SS.NumDOF,1);
                %%%%
        end
        
        % Index, middle, ring, little, thumbF, thumbAb
        pos = [CurrX(2),CurrX(3),CurrX(4),CurrX(5),CurrX(1),-CurrX(6)];
        %         pos = [SS.XHat(2),SS.XHat(3),SS.XHat(4),SS.XHat(5),SS.XHat(1),-SS.XHat(6)];
        if(SS.TASKASensors.SharedControl.Ready)
            %if shared control is enabled, taska control is shared between
            %human and computer, where computer goal is determined on TASKA
            %IR and baro sensors
            HumanGoal = pos;    %output from decode
            ComputerGoal = calcComputerGoal(SS.TASKASensors,SS.TASKAMotors);
            pos = shareTASKAControl(HumanGoal, ComputerGoal,SS.TASKASensors);
            pos(~SS.TASKASensors.SharedEnabled) = HumanGoal(~SS.TASKASensors.SharedEnabled);
            pos(4) = pos(3); % link ring and pinky
        end
        motorLim = 1;
        pos(pos<-motorLim) = -motorLim;
        pos(pos>motorLim) = motorLim;   % Limits to prevent motor churning/jitter
        if SS.TASKA.Count >= SS.TASKA.CountMax  % Updating every cycle causes lag
            updateTASKA(SS.TASKA.Obj,pos',SS.TASKA.RestPositions);
            SS.TASKA.Count = 0;
            SS.TASKAMotors = pos;
            if SS.LCWrist_Ready
                
                %                 %%% Use to save Kinematic Data to use with LPF %%%  NOT
                %                 IMPLEMENTED IN FEEDBACK DECODE BUT IMPLEMENTED WITH LEAP
                %                 MOTION
                %                 Saved_LPFKinematics(:,r+1) = [CurrX(10);CurrX(12)]; %;kinematics(2)
                %                 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %                 LPF_Kinematics = mean(Saved_LPFKinematics(:,r+1-length_minus_1:r+1),2); % Takes the mean of the last 30 values(r increases by 1 each loop)
                %
                %                 updateTaskaWrist(SS.LCWrist, [-CurrX(10);CurrX(12)]); % values negative because Left hand
                
                SS.LCWrist_LastKin = taskamover(SS.LCWrist, SS.LCWrist_LastKin, [CurrX(10) ; -CurrX(12)]);
                
            end
        else
            SS.TASKA.Count = SS.TASKA.Count+1;
        end
    catch ME
        SS.TASKA.Ready = 0;
        disp('TASKA serial connection failed at run testing...');
        if(SS.TASKA.reconnectFlag)
            try
                [SS.TASKA.Obj, SS.TASKA.Ready] = openTASKA(0);
                disp('Reconnected!')
                SS.TASKA.reconnectFlag = 1;
            catch
                disp('Unable to reconnect!...')
                SS.TASKA.reconnectFlag = 0;
                SS.TASKA.Ready = 0;
                if isempty(ME.stack)
                    fprintf('message: %s\r\n',ME.message);
                else
                    fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
                end
            end
        end
    end
end

%Saving DEKA values
try
    saveDEKA(SS,0); %saving deka data to binary file (flag 1 writes header)
catch
    disp('DEKA saving failed!')
    fclose(SS.DEKAFID);
end

%Saving TASKA values
try
    saveTASKA(SS,0); %saving deka data to binary file (flag 1 writes header)
catch
    disp('TASKA saving failed!')
    fclose(SS.TASKAFID);
end

if isfield(SS,'ARD6')
    if isfield(SS.ARD6,'Ready')
        if SS.ARD6.Ready
            try
                % Get StimCell and convert DEKA sensor values
                if isempty(SS.StimCell)
                    SS.ARD6.StimElec = []; %vector of electrodes for stim (comes from SS.StimCell)
                    SS.ARD6.StimAmpMin = []; %vector of corresponding amp (uA) for stim
                    SS.ARD6.StimAmpMax = []; %vector of corresponding amp (uA) for stim
                    SS.ARD6.StimFreqMin = []; %vector of corresponding min freq (Hz) for stim
                    SS.ARD6.StimFreqMax = []; %vector of corresponding max freq (Hz) for stim
                    SS.ARD6.StimDur = []; %vector of corresponding dur (ms) for stim
                    SS.ARD6.ContStimFreq = zeros(length(SS.StimElec),1); %vector of current freq (can be fixed, updating from VRE sensors, updating from MSMS). Need to set this in sendStim.
                    SS.ARD6.ContStimAmp = zeros(length(SS.StimElec),1); %vector of current amp (can be fixed, updating from VRE sensors, updating from MSMS). Need to set this in sendStim.
                else
                    SS.ARD6.StimElec = cellfun(@str2double,SS.StimCell(:,3)); %StimCell: {Region, Receptor, Electrode, MinAmp(uA), MaxAmp(uA), MinFreq, MaxFreq, Dur(ms)}
                    SS.ARD6.StimAmpMin = cellfun(@str2double,SS.StimCell(:,4));
                    SS.ARD6.StimAmpMax = cellfun(@str2double,SS.StimCell(:,5));
                    SS.ARD6.StimFreqMin = cellfun(@str2double,SS.StimCell(:,6));
                    SS.ARD6.StimFreqMax = cellfun(@str2double,SS.StimCell(:,7));
                    SS.ARD6.StimDur = cellfun(@str2double,SS.StimCell(:,8));
                    SS.ARD6.ContStimAmp = zeros(length(SS.StimElec),1);
                    SS.ARD6.ContStimFreq = zeros(length(SS.StimElec),1);
                    %%% Convert the DEKA sensors to Frequency and Amplitude
                    for k=1:length(SS.ARD6.StimElec)
                        [SS.ARD6.ContStimFreq(k), SS.ARD6.ContStimAmp(k)] = DEKA2Stim(SS.ContDEKASensors,SS.PastDEKASensors,SS.DEKASensorLabels,SS.ContDEKAMotors,SS.PastDEKAMotors,SS.DEKAMotorLabels,SS.StimCell(k,:),SS.DEKA.SensorThresholds');
                    end
                    SS.ARD6.ContStimFreq(SS.ARD6.ContStimFreq>SS.ARD6.StimFreqMax') = SS.ARD6.StimFreqMax(SS.ARD6.ContStimFreq>SS.ARD6.StimFreqMax')';
                    SS.ARD6.ContStimFreq(SS.ARD6.ContStimFreq<SS.ARD6.StimFreqMin') = SS.ARD6.StimFreqMin(SS.ARD6.ContStimFreq<SS.ARD6.StimFreqMin')';
                    SS.ARD6.ContStimAmp(SS.ARD6.ContStimAmp>SS.ARD6.StimAmpMax') = SS.ARD6.StimAmpMax(SS.ARD6.ContStimAmp>SS.ARD6.StimAmpMax')';
                    SS.ARD6.ContStimAmp(SS.ARD6.ContStimAmp<SS.ARD6.StimAmpMin') = SS.ARD6.StimAmpMin(SS.ARD6.ContStimAmp<SS.ARD6.StimAmpMin')';
                end
                SS.ARD6.Command = zeros(1,9);
                for k = 1:length(SS.ARD6.StimElec)
                    SS.ARD6.Command(k) = SS.ARD6.ContStimAmp(k);
                    SS.ARD6.Command(k+3) = SS.ARD6.ContStimFreq(k);
                    SS.ARD6.Command(k+6) = SS.ARD6.StimDur(k)*1000; %% LV in ms but StimBox in us
                end
                disp (SS.ARD6.Command)
                StimBox2COM6('stim',SS.ARD6.Command,SS.ARD6.Obj);
                
                
                %                 % Translate DEKA sensor val to stim command
                % %                 SS.ARD6.Command = [floor((SS.ContDEKAPositions(7)-122)/(220-122)*(SS.ARD6.StimMax-SS.ARD6.StimThresh)+SS.ARD6.StimThresh),...
                % %                     floor((24-SS.ContDEKAPositions(5))/(24-15)*(SS.ARD6.StimMax-SS.ARD6.StimThresh)+SS.ARD6.StimThresh),...
                % %                     SS.ARD6.Freq,SS.ARD6.Freq, SS.ARD6.PD,SS.ARD6.PD, 0];
                %
                % %                     SS.ARD6.Command = [floor((SS.ContDEKAPositions(7)-SS.ARD6.ThumbMin)/(SS.ARD6.ThumbMax-SS.ARD6.ThumbMin)*(SS.ARD6.StimMax-SS.ARD6.StimThresh)+SS.ARD6.StimThresh),...
                % %                     floor((SS.ARD6.IndexMax-SS.ContDEKAPositions(5))/(SS.ARD6.IndexMax-SS.ARD6.IndexMin)*(SS.ARD6.StimMax-SS.ARD6.StimThresh)+SS.ARD6.StimThresh),...
                % %                     SS.ARD6.Freq,SS.ARD6.Freq, SS.ARD6.PD,SS.ARD6.PD, 0];
                % %                     SS.ARD6.Command = [(SS.ContDEKASensors(12)*(7)+SS.ARD6.StimThresh),...
                % %                     (SS.ContDEKASensors(1)*(7)+SS.ARD6.StimThresh),...
                % %                     SS.ARD6.Freq,SS.ARD6.Freq, SS.ARD6.PD,SS.ARD6.PD, 0];
                %                 %%% Garrison, these are the correct values to read for the
                %                 %%% DEKA sensors we want...I tested it out before I left
                %                 %%% and added them to the code above.
                % %                 SS.ContDEKASensors(1); % Index distal
                % %                 SS.ContDEKASensors(12); % Thumb distal
                %                 %%% uncomment this to display sensor values - see
                %                 %%% updateDEKA.m for description of each value.
                % %                     disp(SS.ContDEKASensors)
                
            catch
                disp('Could not write to StimBox')
                fclose(SS.ARD6.Obj); delete(SS.ARD6);
            end
            % Add ability to store the stimulation values over time for STIMBOX (amp, frequency, etc... for each channel).
            %         try
            %                saveSTIMBOX(SS,0);
            %         catch
            %             disp('StimBox saving failed')
            %             fclose(SS.STIMBOXID)
            %         end
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sending stim command to xippmex
function SS = sendStim(SS)

if ~isempty(SS.StimChan)
    
    SS.ContStimAmp = zeros(length(SS.StimChan),1);
    SS.ContStimFreq = zeros(length(SS.StimChan),1);
    switch SS.StimMode %Off, Manual, MSMS, VRE, 3DHand, DEKA, Analog(DEKA)
        case 'Manual'
            if SS.ManualStim %if manual stim button pressed on LV side
                if SS.PulseStim
                    switch SS.ManualType
                        case 'Min'
                            SS.ContStimFreq = SS.StimFreqMin;
                            SS.ContStimAmp = SS.StimAmpMin;
                        otherwise
                            SS.ContStimFreq = SS.StimFreqMax;
                            SS.ContStimAmp = SS.StimAmpMax;
                    end
                end
            end
    end
    
    SS.StimSeq = repmat(SS.StimCmd,1,numel(SS.StimChan));
    SS.StimIdx = false(1,numel(SS.StimChan));
    SS.CurrTime = xippmex_1_12('time');
    for k=1:length(SS.StimChan)
        switch SS.StimMode %Off, Manual, MSMS, VRE
            case 'MSMS'
                try
                    if strcmp(SS.VREInfo.HandType,'MPL')
                        SS.ContStimFreq(k) = MSMS2Freq(SS.ContStimMSMS,SS.MSMSContactLabelsMPL,SS.XHat,SS.MSMSMotorLabelsMPL,SS.StimCell(k,:));
                        SS.ContStimAmp(k) = MSMS2Amp(SS.ContStimMSMS,SS.MSMSContactLabelsMPL,SS.XHat,SS.MSMSMotorLabelsMPL,SS.StimCell(k,:));
                    else
                        SS.ContStimFreq(k) = MSMS2Freq(SS.ContStimMSMS,SS.MSMSContactLabelsLuke,SS.XHat,SS.MSMSMotorLabelsLuke,SS.StimCell(k,:));
                        SS.ContStimAmp(k) = MSMS2Amp(SS.ContStimMSMS,SS.MSMSContactLabelsLuke,SS.XHat,SS.MSMSMotorLabelsLuke,SS.StimCell(k,:));
                    end
                catch
                    disp('Dont use MSMS stim mode');
                end
            case 'VRE'
                if SS.VREStatus
                    if strcmp(SS.VREInfo.HandType,'MPL')
                        SS.ContStimFreq(k) = VRESensor2Freq(SS.VREInfo.sensors.contact,SS.VREContactLabelsMPL,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsMPL,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'MPL');
                        SS.ContStimAmp(k) = VRESensor2Amp(SS.VREInfo.sensors.contact,SS.VREContactLabelsMPL,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsMPL,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'MPL');
                    else
                        SS.ContStimFreq(k) = VRESensor2Freq(SS.VREInfo.sensors.contact,SS.VREContactLabelsLuke,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsLuke,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'Luke');
                        SS.ContStimAmp(k) = VRESensor2Amp(SS.VREInfo.sensors.contact,SS.VREContactLabelsLuke,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsLuke,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'Luke');
                        %                             SS.ContStimFreq(k) = VRESensor2Freq_step(SS.VREInfo.sensors.contact,SS.VREContactLabelsLuke,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsLuke,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'Luke');
                        %                             SS.ContStimAmp(k) = VRESensor2Amp_step(SS.VREInfo.sensors.contact,SS.VREContactLabelsLuke,SS.VREInfo.sensors.motor_pos,SS.VREMotorLabelsLuke,SS.VREInfo.robot.motor_limit,SS.StimCell(k,:),'Luke');
                    end
                end
            case '3DHand'
                if SS.ARD3.Ready
                    try
                        SS.ContStimFreq(k) = PHand2Freq(SS.PHandContactVals,SS.PHandContactLabels,SS.PHandMotorVals,SS.PHandMotorLabels,SS.StimCell(k,:));
                        SS.ContStimAmp(k) = PHand2Amp(SS.PHandContactVals,SS.PHandContactLabels,SS.PHandMotorVals,SS.PHandMotorLabels,SS.StimCell(k,:));
                    catch ME
                        disp('Hand Arduino connection failed at send stim...');
                        if isempty(ME.stack)
                            fprintf('message: %s\r\n',ME.message);
                        else
                            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
                        end
                        SS.ARD3.Ready = 0;
                    end
                end
            case 'DEKA'
                [SS.ContStimFreq(k), SS.ContStimAmp(k)] = DEKA2Stim(SS.ContDEKASensors,SS.PastDEKASensors,SS.DEKASensorLabels,SS.ContDEKAMotors,SS.PastDEKAMotors,SS.DEKAMotorLabels,SS.StimCell(k,:),SS.DEKA.SensorThresholds');
            case 'Analog(DEKA)'
                [SS.ContStimFreq(k), SS.ContStimAmp(k)] = analogDEKA2Stim(SS.AnalogSensors,SS.ContDEKAMotors,SS.PastDEKAMotors,SS.DEKAMotorLabels,SS.StimCell(k,:));
        end
        
        % Sending to nip
        StimStepSizeIdx = SS.StimStepSize(floor((SS.StimChan(k)-1)/128)+1); %index into SS.StimStepSizeuA
        if StimStepSizeIdx>=1 && StimStepSizeIdx<=6
            StimSteps = floor(SS.ContStimAmp(k)/SS.StimStepSizeuA(StimStepSizeIdx));
        else
            StimSteps = 0;
        end
        CSF = SS.ContStimFreq(k);
        if SS.Jitter
            CSF = (CSF/2).*randn(length(CSF),1)+CSF; %normally distributed jitter with mean of specified freq and std of half specified frequency
        end
        CSF(CSF<0) = 0;
        CSF(CSF>0 && CSF<5) = 5; %constraint to prevent low frequencies which have a slow ramp up time
        CSF(CSF>500) = 500;
        CSF(CSF==0) = SS.BFreq; %baseline frequency
        StimSteps(StimSteps<0) = 0;
        StimSteps(StimSteps>100) = 100;
        StimSteps(StimSteps==0) = SS.BAmp; %baseline amplitude
        SS.AllContStimAmp(SS.StimElec(k)) = StimSteps; %this gets saved to disk as *.csf filetype
        SS.AllContStimFreq(SS.StimElec(k)) = CSF; %this gets saved to disk as *.csf filetype
        if CSF>0
            NextPulseDiff = max(floor(SS.NextPulse(SS.StimChan(k))-SS.CurrTime),1);%The number of 33.33 us samples between the current time and the current stim pulse that should be executed in this loop on this electrode.
            if NextPulseDiff<floor(SS.BaseLoopTime*30000) %if the current pulse should happen within the current loop, then schedule it.
                SS.StimSeq(k).elec = SS.StimChan(k);
                SS.StimSeq(k).period = floor(30000./CSF); %period is in # of 33 us samples between successive start times of successive pulses. Was set to NextPulseDiff, but changed to frequency.
                SS.StimSeq(k).repeats = ceil(SS.BaseLoopTime*CSF);
                if NextPulseDiff==1 && CSF<(1/SS.BaseLoopTime)
                    %                     fprintf('immed')
                    SS.StimSeq(k).action = 'immed';
                else
                    %                     fprintf('curcyc')
                    SS.StimSeq(k).action = 'curcyc';
                end
                SS.StimSeq(k).seq(1).length = floor(SS.StimDur(k)*30);
                SS.StimSeq(k).seq(1).ampl = StimSteps;
                SS.StimSeq(k).seq(3).length = floor(SS.StimDur(k)*30);
                SS.StimSeq(k).seq(3).ampl = StimSteps;
                SS.NextPulse(SS.StimChan(k)) = SS.CurrTime + NextPulseDiff + floor(30000/CSF); %The NIP time (in number of 33.333 us cycles since boot-up) at which next stim pulse should be delivered (not the current,but the next)
                SS.StimIdx(k) = true;
            end
            
        end
    end
    if any(SS.StimIdx)
        if all(ismember(SS.StimChan, SS.AvailStimList)) % check especially for VTStim
            try
                xippmex_1_12('stimseq',SS.StimSeq(SS.StimIdx));
            catch ME
                if isempty(ME.stack)
                    fprintf('message: %s\r\n',ME.message);
                else
                    fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
                end
            end
        end
    end
    
end

if SS.VTStruct.Ready %buzzer feedback with arduino nano
    try
        CSF = zeros(6,1);
        VTElecs = SS.StimElec(SS.StimElec <= 7) - 1; % into correct indices
        CSF(VTElecs) = SS.ContStimFreq;
        %         if length(SS.ContStimFreq)<6
        %             CSF(1:length(SS.ContStimFreq)) = SS.ContStimFreq;
        %         else
        %             CSF = SS.ContStimFreq(1:6);
        %         end
        SS.VTStruct.Obj.write(CSF);
        %         amp = zeros(6,1);
        %         switch SS.StimMode
        %             case 'VRE'
        %                 if SS.VREStatus
        %                     switch SS.VREInfo.HandType
        %                         case 'MPL'
        %                             amp = VRESensor2ARD(SS.VREInfo.sensors.contact(SS.VTStruct.Idx2ContactMPL),SS.VREInfo.sensors.motor_pos(SS.VTStruct.Idx2MotorMPL),SS.VREInfo.robot.motor_limit(SS.VTStruct.Idx2MotorMPL,:),'MPL');
        %                         otherwise
        %                             amp = VRESensor2ARD(SS.VREInfo.sensors.contact(SS.VTStruct.Idx2ContactLuke),SS.VREInfo.sensors.motor_pos(SS.VTStruct.Idx2MotorLuke),SS.VREInfo.robot.motor_limit(SS.VTStruct.Idx2MotorLuke,:),'Luke');
        %                     end
        %                 end
        %         end
        %         SS.VTStruct.Obj.write = amp;
    catch ME
        disp('VTStim write failed...');
        if isempty(ME.stack)
            fprintf('message: %s\r\n',ME.message);
        else
            fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
        end
        SS.VTStruct.Ready = 0;
    end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Saving task kdf
function SS = saveTask(SS)
fwrite(SS.TaskFID,[SS.XippTS-SS.RecStart;SS.Z;SS.X;SS.T;SS.XHat],'single'); %saving data to fTask file (*.kdf filespec, see readKDF)
if SS.shimmerIMU_Ready
    if ~isempty(SS.shimmerIMUData)
        fwrite(SS.shimmerIMUTaskFID,[SS.XippTS-SS.RecStart,SS.shimmerIMUData],'single');
    end
end





function SS = savePHand(SS)
if isfield(SS,'PHandFID')
    fwrite(SS.PHandFID,[SS.XippTS-SS.RecStart;SS.PHandContactVals;SS.PHandMotorVals],'single'); %saving data to PHand File (*.phf filespec)
end

function SS = saveContStim(SS)
fwrite(SS.ContStimFID,[SS.XippTS-SS.RecStart;SS.AllContStimAmp;SS.AllContStimFreq],'single'); %saving data to ContStim file (*.csf filespec, see readCSF)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Converting Elects to Chans and Kalman indices. This executes every time an event is received from LV.
function SS = updateIdxs(SS)

% Converting BadUEAElects and BadEMGIdxs to BadKalmanIdxs
SS.BadUEAElects(SS.BadUEAElects<1 | SS.BadUEAElects>SS.NumNeuralElects) = [];
SS.BadUEAIdxs = mapRippleUEA(SS.BadUEAElects,'e2i',SS.MapType.Neural);
SS.BadUEAIdxs(isnan(SS.BadUEAIdxs)) = [];
if any(fastSetDiff(SS.BadUEAElectsPrev,SS.BadUEAElects))
    SS.NeuralSurrIdxs = genSurrIdxs(2,SS.BadUEAElects,SS.NumUEAs,SS.MapType.Neural);
    %  SS.NeuralSurrIdxsGPU = gpuArray(SS.NeuralSurrIdxs); %generates a list of neighboring indices for CAR (SS.NumNeuralIdxs x 1 cell array)
    SS.BadUEAElectsPrev = SS.BadUEAElects;
    disp('Updating SS.NeuralSurrIdxs...')
end

% SS.EMGMatrixGPU = gpuArray(SS.EMGMatrix);
if length(SS.AvailEMG)>32
    [SS.EMGMatrix,SS.EMGChanPairs] = genEMGMatrix(SS.BadEMGChans(SS.BadEMGChans>=1 & SS.BadEMGChans<=32)); %BadEMGIdxs = 1 to 528
    SS.BadEMGIdxs = SS.BadEMGChans;
else
    SS.BadEMGChans(SS.BadEMGChans<1 | SS.BadEMGChans>32) = []; %1-32 (single-ended)
    [SS.EMGMatrix,SS.EMGChanPairs,SS.BadEMGIdxs] = genEMGMatrix(SS.BadEMGChans); %BadEMGIdxs = 1 to 528
end
SS.BadKalmanIdxs = [SS.BadUEAIdxs;SS.BadEMGIdxs + SS.NumNeuralIdxs]; %1-720 (1-192 UEA; >192 EMG pairs)

% Converting KalmanElects and KalmanEMG (these are selected electrodes on LV side)
SS.KalmanElects(SS.KalmanElects<1 | SS.KalmanElects>SS.NumNeuralElects) = [];
SS.KalmanEMG(SS.KalmanEMG<(SS.NumNeuralElects+1) | SS.KalmanEMG>(SS.NumNeuralElects+80)) = []; %manual emg selection from LV side (201-280)
SS.KEMGExtra(SS.KEMGExtra<(SS.NumNeuralElects+81) | SS.KEMGExtra>(SS.NumNeuralElects+528)) = []; %281-728 (total 448)
if SS.AllPairs
    SS.KalmanIdxs = [mapRippleUEA(SS.KalmanElects,'e2i',SS.MapType.Neural);(SS.KalmanEMG-SS.NumNeuralElects)' + SS.NumNeuralIdxs;(SS.KEMGExtra-SS.NumNeuralElects)' + SS.NumNeuralIdxs];
else
    SS.KalmanIdxs = [mapRippleUEA(SS.KalmanElects,'e2i',SS.MapType.Neural);(SS.KalmanEMG-SS.NumNeuralElects)' + SS.NumNeuralIdxs];
end
SS.KalmanIdxs(isnan(SS.KalmanIdxs)) = [];
SS.KalmanIdxs(any(bsxfun(@(x,y) x==y,SS.KalmanIdxs,SS.BadKalmanIdxs'),2)) = [];
if isempty(SS.KalmanIdxs)
    SS.KalmanIdxs = 1;
end

% Checking for KalmanMvnts
if isempty(SS.KalmanMvnts)
    SS.KalmanMvnts = 1;
    SS.KalmanGain = [1,1];
    SS.KalmanThresh = [0.2,0.2];
end

% Converting SelElect (if >200, then emg channel was selected)
SS.SelElect(SS.SelElect<1 | SS.SelElect>(SS.NumNeuralElects+80)) = [];
if SS.SelElect<=SS.NumNeuralElects
    SS.SelIdx = mapRippleUEA(SS.SelElect,'e2i',SS.MapType.Neural);
else
    SS.SelIdx = (SS.SelElect-SS.NumNeuralElects)+SS.NumNeuralIdxs;
end
SS.SelIdx(isnan(SS.SelIdx)) = [];
if isempty(SS.SelIdx)
    SS.SelIdx = 1;
end

% Initializing stim variables and converting to channel (all checks are
% done on LV side)
if isempty(SS.StimCell)
    SS.StimElec = []; %vector of electrodes for stim (comes from SS.StimCell)
    SS.StimChan = []; %vector of corresponding nip channels for stim
    SS.StimAmpMin = []; %vector of corresponding amp (uA) for stim
    SS.StimAmpMax = []; %vector of corresponding amp (uA) for stim
    SS.StimFreqMin = []; %vector of corresponding min freq (Hz) for stim
    SS.StimFreqMax = []; %vector of corresponding max freq (Hz) for stim
    SS.StimDur = []; %vector of corresponding dur (ms) for stim
    SS.ContStimFreq = zeros(length(SS.StimElec),1); %vector of current freq (can be fixed, updating from VRE sensors, updating from MSMS). Need to set this in sendStim.
    SS.ContStimAmp = zeros(length(SS.StimElec),1); %vector of current amp (can be fixed, updating from VRE sensors, updating from MSMS). Need to set this in sendStim.
    SS.ContStimMSMS = zeros(6,1); %corresponds with the 6 targets (thumb, index, middle, ring, little, palm) and is continuously updating (see acqCont)
else
    SS.StimElec = cellfun(@str2double,SS.StimCell(:,3)); %StimCell: {Region, Receptor, Electrode, MinAmp(uA), MaxAmp(uA), MinFreq, MaxFreq, Dur(ms)}
    SS.StimChan = mapRippleUEA(SS.StimElec,'e2c',SS.MapType.Neural);
    SS.StimAmpMin = cellfun(@str2double,SS.StimCell(:,4));
    SS.StimAmpMax = cellfun(@str2double,SS.StimCell(:,5));
    SS.StimFreqMin = cellfun(@str2double,SS.StimCell(:,6));
    SS.StimFreqMax = cellfun(@str2double,SS.StimCell(:,7));
    SS.StimDur = cellfun(@str2double,SS.StimCell(:,8));
    
    %removing the section below causes weird stim if both active
    [~,idx] = unique(SS.StimChan); %if a duplicate exists, remove it
    idx = setdiff(1:length(SS.StimChan),idx);
    
    SS.StimElec(idx) = [];
    SS.StimChan(idx) = [];
    SS.StimAmpMin(idx) = [];
    SS.StimAmpMax(idx) = [];
    SS.StimFreqMin(idx) = [];
    SS.StimFreqMax(idx) = [];
    SS.StimDur(idx) = [];
    
    [~,idx] = setdiff(SS.StimChan,SS.AvailStim); %if the channel does not exist on nip, remove it
    
    SS.StimElec(idx) = [];
    SS.StimChan(idx) = [];
    SS.StimAmpMin(idx) = [];
    SS.StimAmpMax(idx) = [];
    SS.StimFreqMin(idx) = [];
    SS.StimFreqMax(idx) = [];
    SS.StimDur(idx) = [];
    
    SS.ContStimAmp = zeros(length(SS.StimElec),1);
    SS.ContStimFreq = zeros(length(SS.StimElec),1);
    SS.ContStimMSMS = zeros(6,1);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initializing buffers
function SS = initBuffers(SS)
SS.SelData = zeros(2,1); %high-pass data for selected channel for current loop iteration (min/max)
SS.SelWfs = nan(48,1); %1st spike waveform for currently selected channel
SS.NeuralRates = zeros(SS.NumNeuralIdxs,1); %current firing rate for all channels in index units
SS.NeuralRatesMA = zeros(SS.NumNeuralIdxs,1); %moving average firing rate for all channels in index units
SS.NeuralElectRatesMA = zeros(SS.NumNeuralElects,1); %moving average firing rate for all channels in electrode units
SS.NeuralRatesBuff = zeros(SS.NumNeuralIdxs,round(SS.KernelWidth/SS.BaseLoopTime)); %buffer of rates (in index units) for all channels to calculate box car average rate
SS.ThreshRMS = nan(SS.NumNeuralIdxs+SS.NumEMGIdxs,1); %threshold values for all channels for counting spikes (index units)
SS.NeuralRMSBuff = zeros(SS.NumNeuralIdxs,round(30/SS.BaseLoopTime/1000)*1000); SS.NeuralRMSBuffIdx = 1:size(SS.NeuralRMSBuff,2); %buffer for running rms to determine spike threshold (~30sec)
SS.EMGDiffBuff = zeros(floor(SS.KernelWidth*SS.FsEMG),size(SS.EMGMatrix,2)); SS.EMGDiffBuffIdx = 1:size(SS.EMGDiffBuff,1); %SS.KernelWidth of continuous data for all diff combinations (~300ms x 528)
SS.EMGPwrMA = zeros(SS.NumEMGIdxs,1); %moving average emg power for all combinations (similar to NeuralRatesMA)

[SS.NeuralRates,SS.WfIdx,SS.NeuralREM,SS.Wf] = findSpikesRealTimeMex(zeros(SS.BaseLoopTime*SS.Fs,SS.NumNeuralIdxs),SS.ThreshRMS(1:SS.NumNeuralIdxs),zeros(SS.NumNeuralIdxs,1),1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Resetting Kalman variables
function SS = resetKalman(SS)
SS.X = zeros(SS.NumDOF,1); %current state (kinematics)
SS.T = zeros(SS.NumDOF,1); %current state (targets)
SS.Z = zeros(SS.NumNeuralIdxs+SS.NumEMGIdxs,1); %current state (features -> spike rate)
SS.XHat = zeros(SS.NumDOF,1); %current xhat for all kinematics (SS.NumDOF)
SS.subX = zeros(length(SS.KalmanMvnts),10); %initial values for kinematics subset during training
SS.subZ = zeros(length(SS.KalmanIdxs),10); %initial values for rates and emg subset during training
SS.subK = zeros(length(SS.KalmanMvnts),10); %initial values for kalman subset during retraining
SS.subT = zeros(length(SS.KalmanMvnts),10); %initial values for targets subset during retraining
SS.GoalNoiseFixed = SS.GoalNoise*randn(1,1) + zeros(size(SS.T(SS.KalmanMvnts)));
switch SS.KalmanType
    case {0,'Standard'} %standard
        SS.TRAIN = kalman_train(SS.subX,SS.subZ); % smw question: why do we retrain here instead of loading training file, this will overwrite TRAIN
        SS.xhat = kalman_test(SS.subZ,SS.TRAIN,[-1,1],1); %initializing persistent variables in kalman_test.m
    case {1,'Mean'} %mean subtracted
        SS.TRAIN = kalman_train_bias(SS.subX,SS.subZ);
        SS.xhat = kalman_test_bias(SS.subZ,SS.TRAIN,[-1,1],1); %initializing persistent variables in kalman_test.m
    case {2,'Refit'} %shenoy mod
        if SS.ReTrain
            SS.TRAIN = kalman_train_vel(SS.subK,SS.subZ,SS.subT,SS.TargRad);
        else
            SS.TRAIN = kalman_train_vel(SS.subX,SS.subZ);
        end
        SS.xhat = kalman_test_vel(SS.subZ,SS.TRAIN,[-1,1],1); % smw: why do we call train and test here as opposed to just setting output to zero, and waiting for the next apply training? td: we call the test function to initialize the persistent variables (last input "1" initializes)
    case {3,'LinSVReg'} % linSVReg
        sameLead =  [197:202, 207:212, 217:222,...
            227:232, 237:242, 247:252, 257:262, 267:272];
        
        %SS.KalmanIdxs = [197:202, 207:212, 217:222,...
        %    227:232, 237:242, 247:252, 257:262, 267:272];
        SS.subZ = zeros(length(sameLead)+1,10);
        %SS.TRAIN = LinSVReg_train(SS.subX,SS.subZ);
        %SS.xhat = LinSVReg_test(SS.subZ(:,1),SS.TRAIN,[-1,1],1);
        SS.TRAIN.w = zeros(2*size(SS.subX,1),size(SS.subZ,1));
        SS.xhat = zeros(size(SS.subX,1),1);
        SS.TRAIN.ZMax = ones(48,1);
        SS.TRAIN.b = 0;
        SS.TRAIN.h = 0;
        SS.TRAIN.negVelScale = 0;
        
    case {4,'NonLinSVReg'} % nonlinSVReg
        %SS.TRAIN = NonLinSVReg_train(SS.subX,SS.subZ);
        %SS.xhat = NonLinSVReg_test(SS.subZ(:,1),SS.TRAIN,[-1,1],1);
        SS.KalmanIdxs = [197:202, 207:212, 217:222,...
            227:232, 237:242, 247:252, 257:262, 267:272];
        SS.subZ = zeros(length(SS.KalmanIdxs)+1,10);
        SS.TRAIN = kalman_train([SS.subX; ones(1,size(SS.subX,2))],SS.subZ);
        SS.xhat = zeros(size(SS.subX,1)+1,1);
        
    case {6, 'DWPRR'} % smw 1/11/17
        %         if isfield(SS, 'TrainParamsFile') % TRAIN should exist but if it doesn't do the standard init
        %             TF = load(SS.TrainParamsFile);
        %             SS.TRAIN = TF.TRAIN;
        %             SS.xhat = kalman_test(SS.subZ,TRAIN,[-1,1],1);%
        %         else
        SS.minZ = zeros(length(SS.KalmanIdxs),1);
        SS.normalizerZ = ones(length(SS.KalmanIdxs),1);
        SS.w = ones(length(SS.KalmanIdxs)+1,length(SS.KalmanMvnts)*2);
        SS.subZ = zeros(length(SS.KalmanMvnts)*2,10);
        SS.TRAIN = kalman_train(SS.subX,SS.subZ);
        SS.xhat = kalman_test(SS.subZ,SS.TRAIN,[-1,1],1); %initializing persistent variables in kalman_test.m
        %         end
    case {7,'AdaptKF'}
        SS.TRAIN = kalman_train(SS.subX,SS.subZ);
        SS.xhat = kalman_test_adaptation(SS.subZ,SS.TRAIN,[-1,1],1, SS.AdaptOnline);
    case {8, 'NN'}
        SS.TRAIN = kalman_train(SS.subX,SS.subZ);
        SS.xhat = kalman_test(SS.subZ,SS.TRAIN,[-1,1],1);
    case {9, 'NN_python'}
        try
            if isfield(SS, 'NN_Python')
                if isfield(SS.NN_Python, 'TRAIN')
                    z_size =  size(SS.subZ);
                    x_size =  size(SS.subX);
                    SS.xhat = test_NN_python(SS.NN_Python.TRAIN.subX(1,:),SS.subX(1,:), SS.NN_Python.TRAIN,1, '//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/config.json', '//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/model.h5',  z_size(1), x_size(1));
                end
            else
                SS.TRAIN = kalman_train(SS.subX,SS.subZ);
                SS.xhat = kalman_test(SS.subZ,SS.TRAIN,[-1,1],1);
            end
        catch
            SS.TRAIN = kalman_train(SS.subX,SS.subZ);
            SS.xhat = kalman_test(SS.subZ,SS.TRAIN,[-1,1],1);
            disp("Error resetting the model, check if the python socket is running")
        end
    case {10,'AdaptKF2'}
        SS.TRAIN = kalman_train(SS.subX,SS.subZ);
        SS.xhat = kalman_test_adaptation2(SS.subZ,SS.TRAIN,[-1,1],1, SS.AdaptOnline);
    case {11,'KF_Short_Goal'}
        SS.NN_classifier_Python_trained = 0;
        SS.TRAIN = kalman_train(SS.subX,SS.subZ);
        SS.xhat = kalman_test_adaptation_limited(SS.subZ,SS.TRAIN,[-1,1],1, SS.AdaptOnline,0, 0);
end
SS.xhatout = zeros(size(SS.xhat));
SS.xhattiming = zeros(size(SS.xhat));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize stim parameters
function SS = initStim(SS)

SS.StimStepSizeuA = [1,2,5,10,20,30]; %use StimStepSize to index into this
SS.StimStepSizeHS = reshape(SS.HSChans,3,[]); %headstage channels that correspond with the StimStepSize index
for k=1:length(SS.AvailStimHS)
    StimIdx = SS.StimStepSize(any(SS.AvailStimHS(k)==SS.StimStepSizeHS));
    if ~isempty(StimIdx)
        if StimIdx>=1 && StimIdx<=6
            xippmex_1_12('stim','enable',0);
            xippmex_1_12('stim','res',SS.AvailStimHS(k),StimIdx)
            xippmex_1_12('stim','enable',1);
            
        end
    end
end

SS.StimCmd.elec = 1;
SS.StimCmd.period = 0; %# nip cycles between pulses
SS.StimCmd.repeats = 0; %# times to repeat pulse. Fixed at 20 since 500Hz only has ~16 pulses in a 33ms loop time. Max frequency should be 500Hz!
SS.StimCmd.action = 'curcyc';
SS.StimCmd.seq(1) = struct('length',6,'ampl',0,'pol',0,'fs',0,'enable',1,'delay',0,'ampSelect',1); %first phase of biphasic pulse
SS.StimCmd.seq(2) = struct('length',3,'ampl',0,'pol',0,'fs',0,'enable',0,'delay',0,'ampSelect',1); %interphase interval
SS.StimCmd.seq(3) = struct('length',6,'ampl',0,'pol',1,'fs',0,'enable',1,'delay',0,'ampSelect',1); %second phase of biphasic pulse

SS.NextPulse = zeros(SS.NumNeuralChans,1); %holds next pulse time for each stim channel
SS.CurrTime = xippmex_1_12('time');

SS.proprioceptVsCut = 'both';%default to both proprioceptive and cutaneous percepts
SS.cutaneousAlgorithm = 'curveFit';%default algorithm
SS.proprioceptiveAlgorithm = 'curveFit';%default algorithm
SS.SA1Thresholds = 0.2;%default of 0.2 will be applied to all contact sensors. This is overwritten for the luke hand during the encode function
SS.RA1Thresholds = 0.2;%default of 0.2 will be applied to all contact sensors. This is overwritten for the luke hand during the encode function
SS.RA2Thresholds = 0;%CURRENTLY NOT IMPLEMENTED
SS.MS1Thresholds = 1;%default of 1 will be applied to all joint velocity sensors, This is overwritten for the luke hand during the encode function
SS.MS2Thresholds = 0.1;%default of 0.1 will be applied to all joint angle sensors. This is overwritten for the luke hand during the encode function
SS.encodeScaling = [60,20,1,1];%default scaling parameters for Max joint velocity, max contact force, max contact velocity, and max contact acceleration, respectively. This is overwritten for the luke hand during the encode function

SS.AllContStimAmp = zeros(200,1);
SS.AllContStimFreq = zeros(200,1);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = initDEKA(SS)
% SS.DEKASensorLabels = {'IndLat';'IntTip';'MidTip';'RinTip';...
%     'PinkyTip';'PalmDist';'PalmProx';'HandEdge';'HandDorsal';...
%     'ThuUlnar';'ThuRadial';'ThuTip';'ThuDorsal'};
%
% SS.DEKAMotorLabels = {'WriRot';'WriPitch';'IndFlex';'MRPFlex';...
%     'ThuRawPitch';'ThuRawYaw';'ThuYaw';'ThuPitch'};

SS.DEKASensorLabels = {'index_medial';'index_distal';'middle_distal';'ring_distal';...
    'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
    'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};

SS.DEKAMotorLabels = {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
    'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD'};

SS.ContDEKASensors = zeros(length(SS.DEKASensorLabels),1);
SS.ContDEKAMotors = zeros(length(SS.DEKAMotorLabels),1);
SS.DEKA.BLSensors = zeros(length(SS.DEKASensorLabels),2);
SS.DEKA.RAW.sensors = zeros(22,1);
SS.DEKA.RAW.motors = zeros(8,1);

%temp fix (10/4/17 -jag) - DEKA calibration hardcode
SS.DEKA.BLSensors = [1.50000000000000,1.90000000000000;0,0;0.900000000000000,7.40000000000000;1.90000000000000,4;2,3.50000000000000;0,0;0,0;0,0;0,0;0.500000000000000,1.30000000000000;1.20000000000000,2;1.10000000000000,1.70000000000000;0.300000000000000,0.900000000000000];
%end temp fix

% temporarily adding DEKA neutral. Goes to default in MSMS2DEKA_wristp (dk 3/21/2018)
SS.DEKA.Neutral = [];
%

SS.PastDEKASensors = zeros(length(SS.DEKASensorLabels),5);
SS.PastDEKAMotors = zeros(length(SS.DEKAMotorLabels),5);
lkmex('stop'); %if communcation open, shut it down
clear lkmex; %clear all communication
lkmex('start'); %starting deka communication (must run before hand is turned on)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% dk 2018-01-26
function SS = initTASKA(SS)
% while 1
%     connPrompt = input('Connect Taska? (Y/N): ', 's');
%
%     if length(connPrompt) == 1 && any(connPrompt == 'YyNn10')
%         if any(connPrompt == 'Yy1')
%             attemptConnection = 1;
%         else
%             attemptConnection = 0;
%         end
%         break
%     end
% end

SS.TASKAMotorLabels = {'index_MCP';'middle_MCP';'ring_MCP';'little_MCP';'thumb_MCP';'thumb_ABD'};
SS.TASKAMotors = zeros(length(SS.TASKAMotorLabels),1);
SS.PastTASKAMotors = zeros(length(SS.TASKAMotorLabels),5);
SS.TASKA.RestPositions = zeros(length(SS.TASKAMotorLabels),1);
SS.TASKA.reconnectFlag = 1;
% TASKA connection (dk 1/31/18)
if SS.StartTaska
    try
        if isfield(SS,'TASKA')
            if isfield(SS.TASKA,'Obj')
                if isobject(SS.TASKA.Obj)
                    delete(SS.TASKA.Obj);
                end
            end
        end
        [SS.TASKA.Obj, SS.TASKA.Ready] = openTASKA();
        if SS.TASKA.Ready == 1
            updateTASKA(SS.TASKA.Obj,zeros(1,6));
            disp('TASKA connected')
        else
            disp('TASKA failed to connect. Make sure Bluetooth dongle is unobstructed')
            fclose(SS.TASKA.Obj);
            delete(SS.TASKA.Obj);
        end
    catch
        if isfield(SS,'TASKA')
            if isfield(SS.TASKA,'Obj')
                if isobject(SS.TASKA.Obj)
                    fclose(SS.TASKA.Obj);
                    delete(SS.TASKA.Obj);
                end
            end
        end
        SS.TASKA.Ready = 0;
        disp('TASKA initialization failed.')
    end
    SS.TASKA.Count = 0;
    SS.TASKA.CountMax = 5; % orig value was 2 here; updated on 10/20/20 to increase TASKA comm time before crashing
else % do not attempt connection
    SS.TASKA.Ready = 0;
end

function SS = initTASKASensors(SS)
% while 1
%     connPrompt = input('Connect Taska Sensors? (Y/N): ', 's');
%
%     if length(connPrompt) == 1 && any(connPrompt == 'YyNn10')
%         if any(connPrompt == 'Yy1')
%             attemptConnection = 1;
%         else
%             attemptConnection = 0;
%         end
%         break
%     end
% end

SS.TASKASensors.IR = zeros(4,1);
SS.TASKASensors.baro = zeros(4,1);
SS.TASKASensors.BL.IR = [0;0;0;0];%[8499;9411;5788;6687];
SS.TASKASensors.BL.baro = [0;0;0;0];%[2151;2155;2161;0];
SS.TASKASensors.window = 10; %actual window length is window + 1
SS.TASKASensors.IRraw = zeros(4,SS.TASKASensors.window);
SS.TASKASensors.baroraw = zeros(4,SS.TASKASensors.window);
SS.TASKASensors.SharedControl.Ready = 0;
SS.TASKASensors.SharedControl.Beta = 0;
SS.TASKASensors.SharedControl.ComputerGoal = 'Close';
SS.TASKASensors.SharedControl.BetaMode = 'Fixed';
SS.TASKASensors.SharedControl.Increment = 0.01;

if SS.StartTaskaSens
    try
        load('C:\Users\Administrator\Code\Tasks\FeedbackDecode\resources\TaskaSharedControlLinearFits.mat');
        SS.TASKASensors.SharedControl.Fit = fits;
        SS.TASKASensors.ActiveSensors = [3,2,1,5]; %ring, middle, index, thumb (mapping)
        SS.TASKASensors.SharedEnabled = [0,0,0,0,1,0]; %index, middle, ring, pinky, thumb, thumbint
        if isfield(SS,'TASKASensors')
            if isfield(SS.TASKASensors,'Obj')
                if isobject(SS.TASKASensors.Obj)
                    delete(SS.TASKASensors.Obj);
                end
            end
        end
        [SS.TASKASensors.Obj, SS.TASKASensors.Count, SS.TASKASensors.Ready] = openTASKASensors_simple();
        if SS.TASKASensors.Ready == 1
            [SS.TASKASensors.IRraw(:,end), SS.TASKASensors.baroraw(:,end)] = readTASKASensors_simple(SS.TASKASensors.Obj,SS.TASKASensors.Count);
            disp('TASKA Sensors connected')
        else
            disp('TASKA Sensors failed to connect. Check arduino connection')
            fclose(SS.TASKASensors.Obj);
            delete(SS.TASKASensors.Obj);
        end
    catch
        if isfield(SS,'TASKASensors')
            if isfield(SS.TASKASensors,'Obj')
                if isobject(SS.TASKASensors.Obj)
                    delete(SS.TASKASensors.Obj);
                end
            end
        end
        SS.TASKASensors.Ready = 0;
        disp('TASKA Sensors initialization failed.')
    end
else % do not attempt connection
    SS.TASKASensors.Ready = 0;
end

function SS = initAnalogSensors(SS)
% SS.analogSensors =
% {'Thumb(t)';'Thumb(t-1)';'Thumb(t-2)';'Thumb(t-3)';'Thumb(t-4)';
%  'Index(t)';'Index(t-1)';'Index(t-2)';'Index(t-3)';'Index(t-4)';
%  'Middle(t)';'Middle(t-1)';'Middle(t-2)';'Middle(t-3)';'Middle(t-4)';
%  'Pinky(t)';'Pinky(t-1)';'Pinky(t-2)';'Pinky(t-3)';'Pinky(t-4)';}

SS.AnalogSensors = zeros(4,6);

function SS = cogLoad(SS) % MDP 20200125
% Write Digital Events to CogLoad file
if ~isempty(SS.DigIO_TS)
    for i=1:length(SS.DigIO_TS)
        cogLoadEventType = EEGEvent2EventType(SS.DigEvents(i));
        switch cogLoadEventType % modified 20200317 - would include SS.TargRad for size but doesn't update correctly...
            case 'BuzzOn'
                fprintf(SS.CogLoadFID,'BuzzOn,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'BuzzOff'
                fprintf(SS.CogLoadFID,'BuzzOff,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'TargOn'
                fprintf(SS.CogLoadFID,'TargOn,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'TargOff'
                fprintf(SS.CogLoadFID,'TargOff,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'ButtonPressEEGTrigger'
                fprintf(SS.CogLoadFID,'ButtonPressEEGTrigger,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'ButtonReleaseEEGTrigger'
                fprintf(SS.CogLoadFID,'ButtonReleaseEEGTrigger,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
            case 'ButtonPressRawNIP'
                if SS.CogLoadStimOn
                    SS.CogLoadButtonPress = 1;
                end
                fprintf(SS.CogLoadFID,'ButtonPressRawNIP,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
                xippmex_1_12('digout',[1, 5],[0, targ2EEGEvent(SS.TargRad, SS.T, 'ButtonPress')]);
            case 'ButtonReleaseRawNIP'
                fprintf(SS.CogLoadFID,'ButtonReleaseRawNIP,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
                xippmex_1_12('digout',[1, 5],[0, targ2EEGEvent(SS.TargRad, SS.T, 'ButtonRelease')]);
            case 'Unknown'
                fprintf(SS.CogLoadFID,'UnknownEvent,NIPTime=%0.0f,TargRad=%0.2f,ParallelID=%0.0f\r\n', ...
                    [SS.DigIO_TS(i) - SS.RecStart, SS.TargRad, double(SS.DigEvents(i).parallel)]);
        end
    end 
end

% Secondary Task
if SS.TargOn % if there is an active target
    if SS.SecondaryTask % if secondary task button pressed in LV
        if ~SS.CogLoadStimOn % if not buzzing
            if SS.CurrTS > SS.CogLoadNextStimTS
                % start next stimulus
                SS.CogLoadStimOn = 1;
                xippmex_1_12('digout',[1, 5],[1, targ2EEGEvent(SS.TargRad, SS.T, 'BuzzOn')]);
                SS.CogLoadNextStimOffTS = SS.CurrTS + SS.SecondaryTaskStimDur*30; % *30 for NIPTime
                SS.CogLoadNextStimTS = SS.CurrTS + ...
                    30*(SS.SecondaryTaskMinBetweenStim + rand*SS.SecondaryTaskVarBetweenStim);
            end
        else % when buzzing
            if ((SS.CurrTS > SS.CogLoadNextStimOffTS) || ... % turn off buzz if longer than stim duration
                    (SS.CogLoadButtonPress == 1)) % or if button was pressed
                % turn off stimulus
                SS.CogLoadButtonPress = 0;
                SS.CogLoadStimOn = 0;
                xippmex_1_12('digout',[1,5],[0,targ2EEGEvent(SS.TargRad, SS.T, 'BuzzOff')]);
            end
        end
    end
elseif SS.CogLoadStimOn % if target not on but buzzer is
    if ((SS.CurrTS > SS.CogLoadNextStimOffTS) || ... % turn off buzz if longer than stim duration
            (SS.CogLoadButtonPress == 1)) % or if button was pressed
        % turn off stimulus
        SS.CogLoadButtonPress = 0;
        SS.CogLoadStimOn = 0;
        xippmex_1_12('digout',[1,5],[0,targ2EEGEvent(SS.TargRad, SS.T, 'BuzzOff')]);
    end
end



% end CogLoad()


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = startDEKA(SS)
SS.DateStr = datestr(clock,'HHMMSS');
SS.DEKAFile = fullfile(SS.FullDataFolder,['\DEKAData_',SS.DataFolder,'_',SS.DateStr,'.deka']);
SS.DEKAFID = fopen(SS.DEKAFile,'w+');
saveDEKA(SS,1); %writing header
SS.DEKA.Ready = 0;
SS.DEKA.SensorThresholds = zeros(1,13);
if strcmp(SS.Prosthesis(end-4:end),'Right')
    SS.DEKA.RightHand = 1;
else
    SS.DEKA.RightHand = 0;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% dk 2018-01-26
function SS = startTASKA(SS)
SS.DateStr = datestr(clock,'HHMMSS');
SS.TASKAFile = fullfile(SS.FullDataFolder,['\TASKAData_',SS.DataFolder,'_',SS.DateStr,'.taska']);
SS.TASKAFID = fopen(SS.TASKAFile,'w+');
saveTASKA(SS,1); %writing header
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function saveDEKA(SS,mode)
if mode %writing header
    DEKAHeader = [
        size(SS.XippTS-SS.RecStart)
        size(SS.ContDEKASensors)
        size(SS.ContDEKAMotors)
        size(SS.DEKA.BLSensors)
        size(SS.DEKA.RAW.sensors)
        size(SS.DEKA.RAW.motors)
        ];
    
    fwrite(SS.DEKAFID,[numel(DEKAHeader);DEKAHeader(:)],'single'); %saving data to VRE data file (see readVREData)
end

DEKAData = [
    SS.XippTS-SS.RecStart
    SS.ContDEKASensors(:)
    SS.ContDEKAMotors(:)
    SS.DEKA.BLSensors(:)
    SS.DEKA.RAW.sensors(:)
    SS.DEKA.RAW.motors(:)
    ];

fwrite(SS.DEKAFID,DEKAData,'single');

% dk 2018-01-26
function saveTASKA(SS,mode)
if mode %writing header
    TASKAHeader = [
        size(SS.XippTS-SS.RecStart)
        size(SS.TASKA.Ready)
        size(SS.TASKAMotors)
        size(SS.TASKASensors.IR)
        size(SS.TASKASensors.baro)
        size(SS.TASKASensors.IRraw)
        size(SS.TASKASensors.baroraw)
        size(SS.TASKASensors.SharedControl.Ready)
        size(SS.TASKASensors.SharedControl.Beta)
        ];
    
    fwrite(SS.TASKAFID,[numel(TASKAHeader);TASKAHeader(:)],'single'); %saving data to TASKA data file (see readTASKAData)
end

TASKAData = [
    SS.XippTS-SS.RecStart
    SS.TASKA.Ready
    SS.TASKAMotors(:)
    SS.TASKASensors.IR(:)
    SS.TASKASensors.baro(:)
    SS.TASKASensors.IRraw(:)
    SS.TASKASensors.baroraw(:)
    SS.TASKASensors.SharedControl.Ready
    SS.TASKASensors.SharedControl.Beta
    ];

fwrite(SS.TASKAFID,TASKAData,'single');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function SS = initVRE(SS)

SS.VREContactLabelsMPL = {'palm_thumb';'palm_pinky';'palm_side';'palm_back';...
    'thumb_proximal';'thumb_medial';'thumb_distal';...
    'index_proximal';'index_medial';'index_distal';...
    'middle_proximal';'middle_medial';'middle_distal';...
    'ring_proximal';'ring_medial';'ring_distal';...
    'pinky_proximal';'pinky_medial';'pinky_distal'};

SS.VREMotorLabelsMPL = {'wrist_PRO';'wrist_UDEV';'wrist_FLEX';...
    'thumb_ABD';'thumb_MCP';'thumb_PIP';'thumb_DIP';...
    'index_ABD';'index_MCP';...
    'middle_MCP';...
    'ring_MCP';...
    'pinky_ABD';'pinky_MCP'};

SS.MSMSContactLabelsMPL = SS.VREContactLabelsMPL([7,10,13,16,19,2]);
SS.MSMSMotorLabelsMPL = repmat({''},12,1);
SS.MSMSMotorLabelsMPL([1:7,9:12]) = SS.VREMotorLabelsMPL([5,9,10,11,13,4,8,12,3,2,1]);

%DP uncommented these July 6
SS.PHandContactLabelsMPL = SS.VREContactLabelsMPL([7,2,10,13]);
SS.PHandMotorLabelsMPL = repmat({''},12,1);
SS.PHandMotorLabelsMPL(1:5) = SS.VREMotorLabelsMPL([5,9,10,11,13]);

SS.VREContactLabelsLuke = {'palm_thumb';'palm_pinky';'palm_back';'palm_side';...
    'thumb_distal';'thumb_medial';'index_distal';...
    'index_medial';'middle_distal';'ring_distal';...
    'pinky_distal'};

SS.VREMotorLabelsLuke = {'wrist_PRO';'wrist_FLEX';'thumb_ABD';'thumb_MCP';...
    'index_MCP';'middle_MCP'};

SS.MSMSContactLabelsLuke = SS.VREContactLabelsLuke([5,7,9,10,11,1]);
SS.MSMSMotorLabelsLuke = repmat({''},12,1);
SS.MSMSMotorLabelsLuke([1,12,10,6,2,3]) = SS.VREMotorLabelsLuke([3,1,2,4,5,6]);

%DP uncommented July 6
SS.PHandContactLabelsLuke = SS.VREContactLabelsLuke([5,1,7,9]);
SS.PHandMotorLabelsLuke = repmat({''},12,1);
SS.PHandMotorLabelsLuke(1:3) = SS.VREMotorLabelsLuke([4,5,6]);

SS.VREIDLabels = {'Luke','Bakeoff11',[12,11,0,30,30];... %[motor_count, contact_sensor_count, nmocap, nq, nv] %smw: this should be in init system not init stim
    'Luke','Bakeoff21',[nan,nan,nan,nan,nan];...
    %     'Luke','Bakeoff31',[6,11,10,85,75];... %smw bakeoff3.1 orig
    %     'Luke','Bakeoff31',[6,11,10,94,84];... % smw (updates to 3.1 ID based on dk Bakeoff_Task31_Modded_XYRestrict_left.xml 7/5/16)
    %     'Luke','Bakeoff31',[6,11,10,85,75];... % smw (updates to 3.1 ID based on dk Bakeoff_Task31_Modded_left.xml 7/5/16)
    %     'Luke','Bakeoff31',[6,11,10,31,30];... % td (updates to 3.1 ID based on ReallyFinal code 7/18/16)
    'Luke','Bakeoff31',[6,11,10,29,28];... % DK (update for MuJoCo v1.50; 9/6/2017)
    %     'Luke','Bakeoff32',[6,11,6,94,83];...
    'Luke','Bakeoff32',[6,11,6,92,81];... % DK (update for MuJoCo v1.50; 9/6/2017)
    %     'Luke','LukeEmpty',[6,11,1,22,21];...
    'Luke','LukeEmpty',[6,11,1,20,19];... % DK (update for MuJoCo v1.50; 9/6/2017)
    'MPL','MPLEmpty',[13,19,1,29,28];...
    'MPL','MPL?',[13,19,1,57,52];...
    'MPL','MPLBasic',[13,19,1,50,46];...
    'MPL','MPLTarg',[nan,nan,nan,nan,nan];...
    %     'Luke','LukeBasic',[6,11,1,43,39];...
    'Luke','LukeBasic',[6,11,1,41,37];... % DK (update for MuJoCo v1.50; 9/6/2017)
    %     'Luke','FragileBlock',[6,11,1,36,33];...
    'Luke','FragileBlock',[6,11,1,34,31];... % DK (update for MuJoCo v1.50; 9/6/2017)
    'Luke','mBBT',[6,11,1,132,115]; % DK (added mBBT; 11/29/2017)
    };


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = startVRE(SS)
try
    if ~mj_connected
        mj_connect;
    end
    mj_reset;
    
    % gather info from VRE
    SS.VREInfo.robot = hx_robot_info;
    SS.VREInfo.mocap = mj_get_mocap;
    SS.VREInfo.state = mj_get_state;
    SS.VRECommand = struct('ref_pos', zeros(SS.VREInfo.robot.motor_count,1), 'ref_vel', zeros(SS.VREInfo.robot.motor_count,1), ...
        'gain_pos', zeros(SS.VREInfo.robot.motor_count,1), 'gain_vel', zeros(SS.VREInfo.robot.motor_count,1), ...
        'ref_pos_enabled', 1, 'ref_vel_enabled', 0, ...
        'gain_pos_enabled', 0, 'gain_vel_enabled', 0);
    SS.VREInfo.sensors = hx_update(SS.VRECommand);
    SS = findVREID(SS);
    
    
    if strcmp(SS.VREInfo.IDLabel,'MPLTarg')
        SS.VRETargetIdx = [mj_name2id('geom','S_thumb_target') mj_name2id('geom','S_index_target') ...
            mj_name2id('geom','S_middle_target') mj_name2id('geom','S_ring_target') ...
            mj_name2id('geom','S_pinky_target') mj_name2id('geom','S_palm_target') ...
            mj_name2id('geom','M_thumb_target') mj_name2id('geom','M_index_target') ...
            mj_name2id('geom','M_middle_target') mj_name2id('geom','M_ring_target') ...
            mj_name2id('geom','M_pinky_target') mj_name2id('geom','M_palm_target') ...
            mj_name2id('geom','L_thumb_target') mj_name2id('geom','L_index_target') ...
            mj_name2id('geom','L_middle_target') mj_name2id('geom','L_ring_target') ...
            mj_name2id('geom','L_pinky_target') mj_name2id('geom','L_palm_target')];
        if SS.TargRad <= 0.15
            SS.TargSize = 'S';
            SS.CurVRETargetIdx = SS.VRETargetIdx(1:6);
            SS.HiddenVRETargetIdx = SS.VRETargetIdx(7:18);
        elseif SS.TargRad > 0.15 && SS.TargRad <= 0.18
            SS.TargSize = 'M';
            SS.CurVRETargetIdx = SS.VRETargetIdx(7:12);
            SS.HiddenVRETargetIdx = SS.VRETargetIdx(1:6,13:18);
        else
            SS.TargSize = 'L';
            SS.CurVRETargetIdx = SS.VRETargetIdx(13:18);
            SS.HiddenVRETargetIdx = SS.VRETargetIdx(1:12);
        end
        if any(SS.VRETargetIdx>=0)
            SS.VRETargetsEnabled = 1;
            for k = 1:length(SS.HiddenVRETargetIdx) % set targs to transparent
                mj_set_rgba('geom',SS.HiddenVRETargetIdx(k),[0 0 0 0]);
            end
            for k = 1:length(SS.CurVRETargetIdx)
                mj_set_rgba('geom',SS.CurVRETargetIdx(k),[0 1 0 0.5]);
            end
        else
            SS.VRETargetsEnabled = 0;
        end
    end
    SS.VREStatus = true;
    
    if isfield(SS,'VREFID')
        try
            fclose(SS.VREFID);
        catch
        end
    end
    SS.DateStr = datestr(clock,'HHMMSS');
    if isempty(SS.VREInfo.IDLabel)
        SS.VREFile = fullfile(SS.FullDataFolder,['\VREData_',SS.DataFolder,'_',SS.DateStr,'.vre']);
    else
        SS.VREFile = fullfile(SS.FullDataFolder,['\VREData_',SS.VREInfo.IDLabel,'_',SS.DataFolder,'_',SS.DateStr,'.vre']);
    end
    SS.VREFID = fopen(SS.VREFile,'w+');
    saveVRE(SS,1); %writing header
    
catch ME
    if isempty(ME.stack)
        fprintf('message: %s\r\n',ME.message);
    else
        fprintf('message: %s; name: %s; line: %0.0f\r\n',ME.message,ME.stack(1).name,ME.stack(1).line);
    end
    mj_close;
    SS.VREStatus = false;
    SS.VREInfo.IDIdx = 0;
    SS.VREInfo.IDLabel = '';
    SS.VREInfo.HandType = '';
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function saveVRE(SS,mode)

if mode %writing header
    VREHeader = [
        size(SS.XippTS-SS.RecStart)
        size(SS.VREInfo.sensors.time_stamp)
        size(SS.VREInfo.sensors.motor_pos)
        size(SS.VREInfo.sensors.motor_vel)
        size(SS.VREInfo.sensors.motor_torque)
        size(SS.VREInfo.sensors.joint_pos)
        size(SS.VREInfo.sensors.joint_vel)
        size(SS.VREInfo.sensors.contact)
        size(SS.VREInfo.sensors.imu_linear_acc)
        size(SS.VREInfo.sensors.imu_angular_vel)
        size(SS.VREInfo.sensors.imu_orientation)
        
        size(SS.VREInfo.state.nq)
        size(SS.VREInfo.state.nv)
        size(SS.VREInfo.state.na)
        size(SS.VREInfo.state.time)
        size(SS.VREInfo.state.qpos)
        size(SS.VREInfo.state.qvel)
        size(SS.VREInfo.state.act)
        
        size(SS.VREInfo.mocap.nmocap)
        size(SS.VREInfo.mocap.time)
        size(SS.VREInfo.mocap.pos)
        size(SS.VREInfo.mocap.quat)
        
        ];
    
    fwrite(SS.VREFID,[numel(VREHeader);VREHeader(:)],'single'); %saving data to VRE data file (see readVREData)
end

VREData = [
    SS.XippTS-SS.RecStart
    SS.VREInfo.sensors.time_stamp(:)
    SS.VREInfo.sensors.motor_pos(:)
    SS.VREInfo.sensors.motor_vel(:)
    SS.VREInfo.sensors.motor_torque(:)
    SS.VREInfo.sensors.joint_pos(:)
    SS.VREInfo.sensors.joint_vel(:)
    %     SS.VREInfo.sensors.contact(:)
    reshape(VRESensorBuffer(SS.VREInfo.sensors.contact),[],1)
    SS.VREInfo.sensors.imu_linear_acc(:)
    SS.VREInfo.sensors.imu_angular_vel(:)
    SS.VREInfo.sensors.imu_orientation(:)
    
    SS.VREInfo.state.nq(:)
    SS.VREInfo.state.nv(:)
    SS.VREInfo.state.na(:)
    SS.VREInfo.state.time(:)
    SS.VREInfo.state.qpos(:)
    SS.VREInfo.state.qvel(:)
    SS.VREInfo.state.act(:)
    
    SS.VREInfo.mocap.nmocap(:)
    SS.VREInfo.mocap.time(:)
    SS.VREInfo.mocap.pos(:)
    SS.VREInfo.mocap.quat(:)
    
    ];

fwrite(SS.VREFID,VREData,'single');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SS = findVREID(SS)

SS.VREInfo.ID = [SS.VREInfo.robot.motor_count,SS.VREInfo.robot.contact_sensor_count,SS.VREInfo.mocap.nmocap,SS.VREInfo.state.nq,SS.VREInfo.state.nv]; %unique identifier of loaded environment
SS.VREInfo.IDIdx = find(all(bsxfun(@(x,y)all(x==y,2),SS.VREInfo.ID,cat(1,SS.VREIDLabels{:,3})),2),1,'first');
SS.VREInfo.HandType = SS.VREIDLabels{SS.VREInfo.IDIdx,1};
SS.VREInfo.IDLabel = SS.VREIDLabels{SS.VREInfo.IDIdx,2}; %finding label that matches numeric identifier

%%%%%%%%%%%%%%%%%%%%% Hack for Bakeoff32 %%%%%%%%%%%%%%%%%%%%%%%%
% if strcmp(SS.VREInfo.IDLabel,'Bakeoff32')
%     if regexp(SS.TestType,'Bakeoff32')
%         SS.VREInfo.IDLabel = SS.TestType;
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function SS = conARD(SS)
% SS.ARD1.Ready = ctrlRBArduino(zeros(1,5));

function SS = connectLEAP(SS)
% Connect to LEAP
try
    % initializing LEAP Motion tracking
    SS.LEAP.Ready = initLeapMotion();
    SS.LEAP.Kinematics = zeros(12,1);
    SS.LEAP.Connected = false;
    SS.LEAP.IsRight = false;
    SS.LEAP.Kinematics2 = zeros(12,1);
    SS.LEAP.Connected2 = false;
    SS.LEAP.IsRight2 = false;
    if(SS.LEAP.Ready)
        disp('Leap Motion Connected')
    else
        disp('Leap Motion Failed to Connect')
    end
catch
    SS.LEAP.Ready = 0;
    SS.LEAP.Kinematics = zeros(12,1);
    SS.LEAP.Connected = false;
    SS.LEAP.IsRight = false;
    SS.LEAP.Kinematics2 = zeros(12,1);
    SS.LEAP.Connected2 = false;
    SS.LEAP.IsRight2 = false;
    disp('Leap Motion Failed to Connect')
end
return

function SS = connectARD(SS)
% check if user desires to connect arduinos first
% while 1
%     connPrompt = input('Connect arduinos/stimboxes? (Y/N): ', 's');
%
%     if length(connPrompt) == 1 && any(connPrompt == 'YyNn10')
%         if any(connPrompt == 'Yy1')
%             attemptConnection = 1;
%         else
%             attemptConnection = 0;
%         end
%         break
%     end
% end

if SS.StartARD
    % rock band connect
    %     try % smw
    %         SS.ARD1.Ready = ctrlRBArduino(zeros(1,5));
    %         if SS.ARD1.Ready
    %             disp('Arduino1 Rock Band connected...')
    %         else
    %             disp('Arduino1: Rock Band failed to connect')
    %         end
    %     catch
    %         SS.ARD1.Ready = 0;
    %         disp('Arduino1: Rock Band failed to connect')
    %     end
    
    SS.ARD1.Ready = 0;
    
    %buzzer feedback with arduino nano
    try
        SS.VTStruct.Amp = [0;0;0;0;0;0]; %not used
        SS.VTStruct.Pin = [3;5;6;9;10;11]; %not used
        SS.VTStruct.Labels = {'thumb_distal';'index_distal';'middle_distal';'ring_distal';'pinky_distal';'palm_side'};
        SS.VTStruct.Idx2ContactMPL = [7;10;13;16;19];
        SS.VTStruct.Idx2ContactLuke = [5;7;9;10;11];
        SS.VTStruct.Idx2MotorMPL = 9;
        SS.VTStruct.Idx2MotorLuke = 5;
        
        SS.VTStruct.Obj = VTStim;
        SS.VTStruct.Ready = 1;
        disp('VTStim hand buzzers connected')
    catch
        SS.VTStruct.Ready = 0;
        disp('VTStim hand buzzers failed to connect')
    end
    
    %open bionics hand
    %     try
    %         SS.PHandContactLabels = {'thumb_distal','palm_pinky','index_distal','middle_distal'};
    %         SS.PHandMotorLabels = {'thumb_MCP','index_MCP','middle_MCP','ring_MCP','pinky_MCP','wrist_FLEX','wrist_PRO','','','','',''};
    %         SS.ARD3.Obj = initiateOB();
    %         [SS.PHandMotorVals,SS.PHandContactVals] = updateOB(SS.ARD3.Obj,zeros(1,7));
    %         SS.ARD3.Ready = 1;
    %         disp('Arduino3 3DHand connected')
    %     catch
    %         if isfield(SS,'ARD3')
    %             if isfield(SS.ARD3,'Obj')
    %                 if isobject(SS.ARD3.Obj)
    %                     fclose(SS.ARD3.Obj);
    %                     delete(SS.ARD3.Obj);
    %                 end
    %             end
    %         end
    %         SS.ARD3.Ready = 0;
    %         disp('Arduino3 3DHand failed to connect')
    %     end
    SS.ARD3.Ready = 0;
    
    %HANDi hand connection (jake added on 10/5/17)
    %     try
    %         SS.HANDiHandContactLabels = {'thumb_distal','palm_pinky','index_distal','middle_distal','pinky_distal'};
    %         SS.HANDiHandPositionLabels = {'','','','','','','','',''};
    %         SS.HANDiHandMotorLabels = {'thumb_ABD','thumb_MCP','index_MCP','middle_MCP','ring_MCP','pinky_MCP'};
    %         SS.ARD4.Obj = initiateHH();
    %         [SS.HANDiHandMotorVals,SS.HANDiHandMotorPos,SS.HANDiHandContactVals] = updateHH(SS.ARD4.Obj,zeros(1,6)); %??
    %         SS.ARD4.Ready = 1;
    %         disp('Arduino4 HANDiHand connected')
    %     catch
    %         if isfield(SS,'ARD4')
    %             if isfield(SS.ARD4,'Obj')
    %                 if isobject(SS.ARD4.Obj)
    %                     fclose(SS.ARD4.Obj);
    %                     delete(SS.ARD4.Obj);
    %                 end
    %             end
    %         end
    %         SS.ARD4.Ready = 0;
    %         disp('Arduino4 HANDi Hand failed to connect')
    %     end
    SS.ARD4.Ready = 0;
    
    
    
    %     try % StimBoxSetup
    %     %     SS.ARD6.Ready = 0; %%% Don't set here....set higher up so it happens once
    %         %%%% Case so that init only happens during setup using the
    %         %%%% SS.ARD6.Ready
    %         if SS.ARD6.Ready == 1
    %         else
    %         [SS.ARD6.Obj, SS.ARD6.Ready] = StimBox2COM6('init');
    %         end
    %         SS.ARD6.StimRange = 7; % range of 7mA
    %     %     SS.ARD6.StimThresh = 1.55; %% set per person (once at start)
    %     %      SS.ARD6.StimMax = SS.ARD6.StimThresh+7; %% 7mA higher than thresh
    %     %     %%% Garrison you will need to choose the right max and min for the new
    %     %     %%% sensors once the DEKA hand is back. Tyler said he can help you
    %     %     %%% thursday. It would be nice to make it so that the same stimulation
    %     %     %%% is delivered for the same force on both index and thumb...but that
    %     %     %%% might be tricky. Try to do it by hand though. I suggest.
    %     %     SS.ARD6.ThumbMax = 180; %% 220 hard max
    %     %     SS.ARD6.ThumbMin = 122;
    %     %     SS.ARD6.IndexMax = 23;
    %     %     SS.ARD6.IndexMin = 15;
    %     %     SS.ARD6.PD = 100; % usec
    %     %     SS.ARD6.Freq = 50;
    %         SS.ARD6.Command = zeros(1,9); %[0,0,SS.ARD6.Freq,SS.ARD6.Freq,SS.ARD6.PD,SS.ARD6.PD,0];
    %         if SS.ARD6.Ready == 0
    %             if isfield(SS.ARD6,'Obj')
    %                 if isobject(SS.ARD6.Obj)
    %                     fclose(SS.ARD6.Obj);
    %                     delete(SS.ARD6.Obj);
    %                 end
    %             end
    %             disp('Arduino6 StimBox failed to connect')
    %         end
    %     catch
    %         if isfield(SS, 'ARD6')
    %             if isfield(SS.ARD6,'Obj')
    %                 if isobject(SS.ARD6.Obj)
    %                     fclose(SS.ARD6.Obj);
    %                     delete(SS.ARD6.Obj);
    %                 end
    %             end
    %         end
    %         disp('Arduino6 StimBox failed to connect')
    %     end
    SS.ARD6.Ready = 0;
    
else % attemptConnect == 0
    SS.ARD1.Ready = 0;
    SS.ARD3.Ready = 0;
    SS.ARD4.Ready = 0;
    SS.ARD6.Ready = 0;
    SS.VTStruct.Ready = 0;
end

function SS = sendDecode2NIP(SS)

SS.DecodeParamsStr = genDecodeParamsStr(SS.KalmanIdxs,SS.KalmanMvnts,SS.TRAIN,SS.KalmanGain,SS.KalmanThresh,SS.BaseLoopTime,SS.CtrlSpeed,SS.CtrlMode);
SS.DecodeParamsCell = regexp(SS.DecodeParamsStr,'];','split')';
for k=1:length(SS.DecodeParamsCell)-1
    tmpstr = [SS.DecodeParamsCell{k},'];'];
    cnt = floor(length(tmpstr)/1440);
    chnk = reshape(tmpstr(1:1440*cnt),1440,cnt);
    chnkrem = tmpstr(1440*cnt+1:end);
    for m=1:cnt+1
        if m<cnt+1
            fwrite(SS.UDPNIP,chnk(:,m));
        else
            fwrite(SS.UDPNIP,chnkrem);
        end
    end
end


function SS = initNIP(SS)

while 1
    try
        if xippmex_1_12('tcp')  %% MB 20200302 original is just xippmex_1_12 for UDP
        else
            xippmex_1_12('close'); clear('xippmex_1_12');
            disp('Unable to initialize TCP xippmex');
            xippmex_1_12();
            disp('using UDP mode');
        end
        %             SS.XippOpers = xippmex_1_12('opers'); pause(0.1);
        SS.AvailChanList = xippmex_1_12('elec','all'); pause(0.1);
        SS.AvailStimList = xippmex_1_12('elec','stim'); pause(0.1);
        SS.HSChans = [1,33,65,129,161,193,257,289,321]; %1st channel of each 32ch headstage
        SS.AvailNeural = SS.AvailChanList(SS.AvailChanList<=224); SS.AvailNeuralHS = intersect(SS.HSChans,SS.AvailNeural);
        %             SS.AvailEMG = SS.AvailChanList(SS.AvailChanList>=257 & SS.AvailChanList<=288); SS.AvailEMGHS = intersect(SS.HSChans,SS.AvailEMG);
        SS.AvailEMG = SS.AvailChanList(SS.AvailChanList>=257 & SS.AvailChanList<=384); SS.AvailEMGHS = intersect(SS.HSChans,SS.AvailEMG);
        SS.AvailAnalog = SS.AvailChanList(SS.AvailChanList==10241); %10241 to 10270 (1st 4 are SMA)
        SS.AvailStim = intersect(SS.AvailNeural,SS.AvailStimList); SS.AvailStimHS = intersect(SS.HSChans,SS.AvailStim);
        SS.DisableEMG = SS.AvailChanList(SS.AvailChanList>=289 & SS.AvailChanList<=384); SS.DisableEMGHS = intersect(SS.HSChans,SS.DisableEMG);
        break;
    catch
        disp('Unable to initialize xippmex');
        xippmex_1_12('close'); clear('xippmex_1_12');
    end
    
    %     try
    %         if xippmex_1_12  %% UDP
    % %             SS.XippOpers = xippmex_1_12('opers'); pause(0.1);
    %             SS.AvailChanList = xippmex_1_12('elec','all'); pause(0.1);
    %             SS.AvailStimList = xippmex_1_12('elec','stim'); pause(0.1);
    %             SS.HSChans = [1,33,65,129,161,193,257,289,321]; %1st channel of each 32ch headstage
    %             SS.AvailNeural = SS.AvailChanList(SS.AvailChanList<=224); SS.AvailNeuralHS = intersect(SS.HSChans,SS.AvailNeural);
    % %             SS.AvailEMG = SS.AvailChanList(SS.AvailChanList>=257 & SS.AvailChanList<=288); SS.AvailEMGHS = intersect(SS.HSChans,SS.AvailEMG);
    %             SS.AvailEMG = SS.AvailChanList(SS.AvailChanList>=257 & SS.AvailChanList<=384); SS.AvailEMGHS = intersect(SS.HSChans,SS.AvailEMG);
    %             SS.AvailAnalog = SS.AvailChanList(SS.AvailChanList==10241); %10241 to 10270 (1st 4 are SMA)
    %             SS.AvailStim = intersect(SS.AvailNeural,SS.AvailStimList); SS.AvailStimHS = intersect(SS.HSChans,SS.AvailStim);
    %             SS.DisableEMG = SS.AvailChanList(SS.AvailChanList>=289 & SS.AvailChanList<=384); SS.DisableEMGHS = intersect(SS.HSChans,SS.DisableEMG);
    %             break;
    %         end
    %     catch
    %         disp('Unable to initialize UDP xippmex');
    %         xippmex_1_12('close'); clear('xippmex_1_12');
    %     end
    %
    %     end
end

% Enabling appropriate neural channels
if ~isempty(SS.AvailNeural)
    xippmex_1_12('signal',SS.AvailNeuralHS,'raw',ones(length(SS.AvailNeuralHS),1)); pause(0.1); %only 1st headstage channels need to be sent
    xippmex_1_12('signal',SS.AvailNeuralHS,'lfp',zeros(length(SS.AvailNeuralHS),1)); pause(0.1);
    xippmex_1_12('signal',SS.AvailNeural,'spk',ones(length(SS.AvailNeural),1)); pause(0.1); %all available channels need to be sent to xippmex
    for k=1:length(SS.AvailNeuralHS)
        xippmex_1_12('filter','set',SS.AvailNeuralHS(k),'spike',3); pause(0.1);
        xippmex_1_12('fastsettle','stim',SS.AvailNeuralHS(k),3,1); %set to same front port
    end
end

% Enabling appropriate emg channels
if ~isempty(SS.AvailEMG)
    xippmex_1_12('signal',SS.AvailEMGHS,'raw',ones(length(SS.AvailEMGHS),1)); pause(0.1);
    xippmex_1_12('signal',SS.AvailEMGHS,'lfp',ones(length(SS.AvailEMGHS),1)); pause(0.1);
    xippmex_1_12('signal',SS.AvailEMG,'spk',zeros(length(SS.AvailEMG),1)); pause(0.1);
    for k=1:length(SS.AvailEMGHS)
        xippmex_1_12('filter','set',SS.AvailEMGHS(k),'lfp',4); pause(0.1); %bandpass "EMG" 15-350 to start
        xippmex_1_12('filter','set',SS.AvailEMGHS(k),'lfp notch',3); pause(0.1); %notch to start
    end
end

% Enabling appropriate stim channels
if ~isempty(SS.AvailStim)
    xippmex_1_12('signal',SS.AvailStim,'stim',ones(length(SS.AvailStim),1)); pause(0.1);
end

% Enabling appropriate analog channels
if ~isempty(SS.AvailAnalog)
    xippmex_1_12('signal',SS.AvailAnalog,'1ksps',ones(length(SS.AvailAnalog),1)); pause(0.1);
    xippmex_1_12('signal',SS.AvailAnalog,'30ksps',zeros(length(SS.AvailAnalog),1)); pause(0.1);
end

% Disabling unwanted emg channels
% if ~isempty(SS.DisableEMG)
%     xippmex_1_12('signal',SS.DisableEMGHS,'raw',zeros(length(SS.DisableEMGHS),1)); pause(0.1);
%     xippmex_1_12('signal',SS.DisableEMGHS,'lfp',zeros(length(SS.DisableEMGHS),1)); pause(0.1);
%     xippmex_1_12('signal',SS.DisableEMG,'spk',zeros(length(SS.DisableEMG),1)); pause(0.1);
% end

SS.SfTable = [0.125,0.25,0.5]; %uV/bit returned from xippmex call: output = xippmex_1_12('adc2phys', 1);
SS.SfNeural = 0.25;
if ~isempty(SS.AvailNeuralHS)
    SS.SfNeural = SS.SfTable(xippmex_1_12('adc2phys',SS.AvailNeuralHS));
    if all(SS.SfNeural(1)==SS.SfNeural)
        SS.SfNeural = SS.SfNeural(1);
    end
end
SS.SfEMG = 0.25;
if ~isempty(SS.AvailEMGHS)
    SS.SfEMG = SS.SfTable(xippmex_1_12('adc2phys',SS.AvailEMGHS));
    if all(SS.SfEMG(1)==SS.SfEMG)
        SS.SfEMG = SS.SfEMG(1);
    end
end











