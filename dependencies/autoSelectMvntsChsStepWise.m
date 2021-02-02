function [ Movements, Channels ] = autoSelectMvntsChsStepWise(Data, Kinematics, KDFTimes, TrialStruct, varargin)
% function which will automatically downselect the channels and movements to be used in the decode
% based on their correlation to the desired kinematic movements and other criteria.
% inputs:
%   Data - nSamples x nChannels of data describing the neural and/or EMG output
%   Kinematics - nSamples x nDOF, describing the training data for all
%       movements.  **Note Data and Kinematics are assumed to be sampled at the
%       same time/rate and Synched. ** Note: DOF order: 
%       1 - thumb flex, extend
%       2 - index flex, extend
%       3 - middle flex, extend
%       4 - ring flex, extend
%       5 - little flex, extend
%       6 - thumb abduction
%       7 - index abduction
%       8 - ring abduction
%       9 - little abduction
%       10 - wrist flex, extend
%       11 - wrist ulnar, radial deviation
%       12 - wrist pronate, supinate
%   KDFTimes - nsamples x 1 double, vector of times associated with Data
%        and Kinematics.  Time is in NIP samples (30 KHz rate)
%   TrialStruct - a numTrials x 1 structure containing the time stamps of the movement
%       trials.  TrialStructure will have the following fields related to
%       training trials
%           .MovementMat - 12 x 2 logical array (numDOF x 2) of movement trained on. 
%               The first column represents flexion and the second array represents extension.  e.g.
%               movement trained on: thumb flex,
%               TrialStruct(k).Movementmat = [1,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0]
%           .TrialStart - int, NIP sample number of the START of the trial
%           .TrialEnd - int, NIP sample number of the END of the trial 
%           .TrainingOn - logical.  TrainingOn ==1 for training data (to be
%               used as a check)
%   Threshold (optional) - minimum correlation criteria.  Default 0.4
%   NumChannels (optional) - maximum number of channels per movment.  Default 10
% Outputs:
%   Movements - 12 x 2 logical array (numDOF x 2) of movements that meet selection criteria.  
%       The first column represents flexion and the second array represents extension.  e.g.
%       the following movements meet the selection criteria: thumb flex,
%       index flex, wrist extend.  The Movements matrix should read: 
%       Movements = [1,0;1,0;0,0;0,0;0,0;0,0;0,0;0,0;0,1;0,0;0,0]
%   Channels - numSelectedCh x 1, integer list of selected channels that meet
%       selection criteria
% 
% example call:  [ Movements, Channels ] = autoSelectMvntsChsStepWise(subZ', subX',KDFTimes, TrialStruct);
% DJW 20150617, modified by SMW, TD 20150618


%% Magic Numbers
DEBUGFlag = false;
ThresholdMinDefault = 0.4;
NumChannelsMaxDefault = 10;
nDirections = 2; % flexion and extension
penterDefault = 0.01; % The maximum p value for a term to be added in the stepwise regression, small values reduce number of channels
premoveDefault = 0.20; % The minimum p value for a term to be removed in the stepwise regression, not of much value but large values reduce number of channels

%% Assure output
Movements = []; %#ok<NASGU>
Channels = []; %#ok<NASGU>

%%Checking of inputs
if( DEBUGFlag )
    % Turn on stepwisefit output
    displayFlag = 'on';
    % Extensive checking of inputs
    pInput = inputParser();
    pInput.addRequired( 'Data', ...
        @(x)( ismatrix( x ) && isfloat( x ) && isreal( x ) ) );
    pInput.addRequired( 'Kinematics', ...
        @(x)( ismatrix( x ) && isfloat( x ) && isreal( x ) ) );
    pInput.addRequired( 'KDFTimes', ...
        @(x)( ismatrix( x ) && isfloat( x ) && isreal( x ) ) );
    pInput.addRequired( 'TrialStruct', ...
        @(x)( isstruct( x ) && isfield( x, 'MovementMat' ) && ...
        isfield( x, 'TrialStart' ) && isfield( x, 'TrialEnd' ) && ...
        isfield( x, 'TrainingOn' ) ) );
    pInput.addOptional( 'Threshold', ThresholdMinDefault, ...
        @(x)( iscalar( x ) && isfloat( x )  && isreal( x ) && ( x > 0 ) ) );
    pInput.addOptional( 'NumChannels', NumChannelsMaxDefault, ...
        @(x)( iscalar( x ) && isfloat( x )  && isreal( x ) && ...
        ( rem( x, 1.0 ) == 0 ) && ( x > 0 ) ) );
    try
        pInput.parse( Data, Kinematics, KDFTimes, TrialStruct, varargin{:} );
    catch mExp
        error( 'AutoSelectMvntsAndChs:invalidInputParameter', ...
            'Error: %s', mExp.message );
    end%% Extensive error checking
    Data = pInput.Results.Data;
    Kinematics = pInput.Results.Kinematics;
    KDFTimes = pInput.Results.KDFTimes;
    TrialStruct = pInput.Results.TrialStruct(:);
    ThresholdMin = pInput.Results.Threshold;
    NumChannelsMax = pInput.Results.NumChannels;
    clear pInput
    % Extracted Magic Numbers
    nSamples = size( Data, 1 );
    nChannels = size( Data , 2 );
    nDOF = size( Kinematics, 2 );
    nTrials = numel( TrialStruct );
    if(  size( Kinematics, 1 ) ~= nSamples )
        error( 'AutoSelectMvntsAndChs:inconsistantSizeDataAndKinematics', ...
            'Number of sample not equal for Data (%d) and Kinematics (%d)', ...
        size( Data, 1 ), size( Kinematics, 1 ) );
    end
else
    % Turn off stepwisefit output
    displayFlag = 'off';
    if( nargin < 4 )
        error( 'AutoSelectMvntsAndChs:inadquateNumberInputArguments', ...
            'At least 4 input arguments required' );
    end
    if( nargin > 4)
        ThresholdMin = varargin{1};
    else
        ThresholdMin = ThresholdMinDefault;
    end
    if( nargin > 5 )
        NumChannelsMax = varargin{2};
    else
        NumChannelsMax = NumChannelsMaxDefault;
    end
    % Extracted Magic Numbers
    nSamples = size( Data, 1 );
    nChannels = size( Data , 2 );
    nDOF = size( Kinematics, 2 );
    nTrials = numel( TrialStruct );
    if(  size( Kinematics, 1 ) ~= nSamples )
        error( 'AutoSelectMvntsAndChs:inconsistantSizeDataAndKinematics', ...
            'Number of sample not equal for Data (%d) and Kinematics (%d)', ...
        size( Data, 1 ), size( Kinematics, 1 ) );
    end
end

% Organize the data
% MovementMat = [ TrialStruct(:).MovementMat ];
MovementMat =  false( nDOF, nDirections, nTrials ); % movement list of all trials
Movements = zeros( nDOF, nDirections  ); % condensed output matrix
for n = 1:nTrials
    MovementMat(:,:,n) = TrialStruct(n).MovementMat;
    Movements = Movements | TrialStruct(n).MovementMat;
end;clear n
% combine directions
MovementMat = squeeze( any( MovementMat, 2 ) );
TrialStart = [ TrialStruct(:).TrialStart ];
TrialEnd = [ TrialStruct(:).TrialEnd ];
TrainingOn = [ TrialStruct(:).TrainingOn ];

% Save new outputs
% Movements = false( nDOF, nDirections  );
ChannelsLogical = false( nChannels, 1  );

% % normalize the data prior to linear regression
% a = max(abs(Data));
% b = repmat(a, size(Data, 1), 1);
% normData = (Data - repmat(mean(Data,1), size(Data,1),1))./b;
% Data = normData; clear a; clear b;

% for each DOF
for n = 1:nDOF
    indexMovementTrials = find( MovementMat( n, : )  );
%     if( isempty( indexMovementTrials ) )
%         Movements( n, : ) = false;
%     else
%         Movements( n, : ) = true;
%     end
    DataTrain = [];
    KinematicsTrain = [];
    disp(['Regressing on DoF ' num2str(n)]);
    for m = 1:length( indexMovementTrials )
        idx = find(KDFTimes >= TrialStart(indexMovementTrials(m)) & KDFTimes <= TrialEnd(indexMovementTrials(m)));
        %         DataTrain = [ DataTrain; Data( TrialStart(indexMovementTrials(m)):TrialEnd(indexMovementTrials(m)), : ) ]; %#ok<AGROW>
        DataTrain = [ DataTrain; Data(idx, : ) ]; %#ok<AGROW>
        %         KinematicsTrain = [ KinematicsTrain; Kinematics( TrialStart(indexMovementTrials(m)):TrialEnd(indexMovementTrials(m)), n ) ]; %#ok<AGROW>
        KinematicsTrain = [ KinematicsTrain; Kinematics( idx, n ) ]; %#ok<AGROW>
    end;
    if ~isempty(DataTrain)
        [ b,~,~,inmodel] = stepwisefit( DataTrain, KinematicsTrain, ...
            'display', displayFlag, ...
            'penter', penterDefault, ...
            'premove', premoveDefault );
        if( DEBUGFlag )
            fprintf( 'keep\n' );
            disp( find( inmodel ) );
        end
        
        % take only numChannels of best regressors
        %         [~, bRankIdx] = sort(b);
        %         keepChIdx = intersect(bRankIdx(1:min(NumChannelsMax, length(b))), find(inmodel));
        keepChIdx = find(inmodel);
        ChannelsLogical(keepChIdx(1:min(NumChannelsMax, length(b)))) = true;
        
        %         ChannelsLogical = ChannelsLogical | inmodel(:);
        if( DEBUGFlag )
            fprintf( 'keep\n' );
            disp( find( ChannelsLogical ) );
        end
        clear inmodel 
    end
%     end;clear m
end

Channels = find( ChannelsLogical );

return




