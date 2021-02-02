function load2nomad(varargin)
%%% load2nomad will open a uigetfile prompt to select the SS .mat and
%%% Training .mat files. The cell arrays within the SS structure (incompatible with coder)
%%% will be extracted along with any other structure fields required by the
%%% runKalman_test.m file. These will be saved into a temporary folder which
%%% runKalman_test.m will automatically load. Some record should also be
%%% kept of which files were loaded onto the Nomad.


if nargin == 1
    TRFname = varargin{1};
    TR = load(TRFname);
    %clear contents or make a temporary folder (in current directory...)
%     splitTRF = strsplit(TRFname,'\');
%     tempFolder = fullfile(splitTRF{1},splitTRF{2},'COBTempFiles'); %% Will make a temp folder in the C:\FeedbackDecode or D:\FeedbackDecode
else
    %uigetfile for ExportTrain struct
    [Fname, Pname, ~] = uigetfile(fullfile('\\PNILABVIEW','PNILabview_R6','*.mat'), 'Select the ExportTrain .mat file');
    TRFname = fullfile(Pname,Fname);
%     tempFolder = 'C:\COBTempFiles';
end
tempFolder = 'C:\FeedbackDecode\COBTempFiles';
if exist(tempFolder)==7
    %clear
    delete(fullfile(tempFolder,'*.mat'))
    disp (strcat('Cleared temporary folder->', tempFolder))
else
     %create
     mkdir(tempFolder)
     disp (strcat('Created temporary folder->', tempFolder))
end

TempTRFname = fullfile(tempFolder,'TempExportTrain.mat');

try
    removeThese = {'CtrlMode','LinkedDOF'};
    vars = rmfield(TR,removeThese);
    save(TempTRFname,'-struct','vars');
    
    % Extract CtrlMode and save as a numerical array: 1 = pos; 2 = vel; 3 = latching; 4 = leaky;
    CtrlMode = TR.CtrlMode;
    Posidx = strcmp(CtrlMode,'Position');
    Velidx = strcmp(CtrlMode,'Velocity');
    Latidx = strcmp(CtrlMode,'Latching');
    Leakidx = strcmp(CtrlMode,'Leaky');
    CtrlModeArray(Posidx) = 1;
%     CtrlModeArray(Velidx) = 3;
    CtrlModeArray(Latidx) = 2;
    CtrlModeArray(Leakidx) = 4;
    
    % Extract LinkedDOF and save each cell as its own field in a struct DOF
    LinkedDOF = TR.LinkedDOF;
    for i = 1:size(LinkedDOF,1)
        FieldDOF = ['FieldDOF',int2str(i)];
        DOF.(FieldDOF) = LinkedDOF{i};
    end
    if ~exist('DOF')
        DOF = struct([]);
    end
    
    % Add numerical representation of CtrlMode and LinkedDOF struct to .mat file
    save(TempTRFname,'CtrlModeArray','DOF','-append');
    disp('Saved .mat required for COB build')
catch
    disp('Failed to save .mat for COB build')
    disp('Stop')
    return
end
end