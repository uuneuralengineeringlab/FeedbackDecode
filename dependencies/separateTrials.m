function [TrainMask, TestMask] = separateTrials(Features,Kinematics,TrialStruct,NIPTime,varargin)
    %% [TrainMask, TestMask] = separateTrials(Features,Kinematics,TrialStruct,NIPTime)
    % This function splits the features and kinematics in half so that it
    % can be used for 
    % Inputs:
    %   Features (emg / neural data)
    %   Kinematics (true position of hand)
    %   Trial Struct (containing movements used)
    %   NIP Time (during the entire training process)
    % Variable Inputs:
    %   TrainComboFlag (0 or 1) - include combos for training or not?
    %   TestComboFlag (0 or 1) - include combos for testing or not?
    %   TrainingPercent (0 to 1) - what fraction of data to use for training
    %   TrainingType - 'first', 'last' or 'shuffle'
    % Outputs: Two masks, specifying which indexes are used for testing and
    % which are used for training.
    %% Begin Code
    %% Variable Inputs
    try
        trainComboFlag = varargin{1};
    catch
        trainComboFlag = 0; %default trains and tests on combos
    end
    try
        testComboFlag = varargin{2};
    catch
        testComboFlag = 1;  %default test on combos
    end
    try
        trainPercent = varargin{3};
    catch
        trainPercent = .5;  %default uses half of the data to train
    end
    try
        trainingType = varargin{4};
        switch trainingType
            case 'first'
                fprintf('Using first %d%% of trials for training\n',trainPercent*100);
            case 'last'
                fprintf('Using last %d%% of trials for training\n',trainPercent*100);
            case 'shuffle'
                fprintf('Using a random %d%% subset of trials for training\n',trainPercent*100);
            otherwise
                fprintf('Invalid training type. Options are: "first","last" or "shuffle"\nProceeding with defaults instead\n');
        end
    catch
        trainingType = 'first'; %uses first portion of data as training
    end 
    %% Define Variables
    %timings
    startTimes = [TrialStruct.TargOnTS];
    endTimes = [TrialStruct.TrialTS];
    %features & kinematics
    [numClasses, ~] = size(Kinematics); %num DOFs
    [numFeatures, ~] = size(Features);    %num features
    %training movements
    movements = cat(3,TrialStruct.MvntMat);
    [~,~,numTotalTrials] = size(movements);

    %% Determine Movement Types & Number of Movements per Type
    movementType = cell(numTotalTrials,1);  %all movement types
    types ={};  %types that exist
    numTrials = []; %num trials for each type
    trialLocations = {}; %trial indicies for each type of movement
    comboLocations =[];
    count = 0;
    for ii = 1:numTotalTrials
        tempIdxs = find(movements(:,1,ii)); %determines index of movement (1 = thumb, 2 = index, etc.)
        movementType{ii} = sign(movements(tempIdxs,1,ii)).*tempIdxs;    %positive flex, negative extend
        mvmtLoc = alreadyExists(types,movementType{ii});
        if (    ii > 1      &&   mvmtLoc > 0       ) %same as previous movement?
            numTrials(mvmtLoc) = numTrials(mvmtLoc) + 1;    %increment count
            trialLocations{mvmtLoc} = [trialLocations{mvmtLoc} ii];
        else    %new movement, start new count
            count = count + 1;
            numTrials(count) = 1;
            types{count} = movementType{ii};
            if (length(movementType{ii}) > 1)   %combo movement
                comboLocations(count) = 1;
            else
                comboLocations(count) = 0;
            end
            trialLocations{count} = [ii];
        end
    end
    %% Go through all movements and split each into testing or training
    numMovements = length(numTrials);
    testingIndexs = cell(numMovements,1);
    trainingIndexs = cell(numMovements,1);
    for ii = 1:numMovements     %go through each movement
        locations = trialLocations{ii};
        switch trainingType
            case 'shuffle'
                locations = locations(randperm(length(locations))); %shuffle data
        end
        nTrial = numTrials(ii);
        nTrain = floor(nTrial*trainPercent);
        trainSubIdx = cell(nTrial,1);
        testSubIdx = cell(nTrial,1);
        for jj=1:nTrial     %go through each trial on this DOF
            tempIdx = locations(jj);    %which movement in the overall dataset (out of numTotalTrials)
            if(tempIdx > 1) %not first movement, use ending of previous movement
                startT = endTimes(tempIdx - 1);
            else            %first movement ever, use start of file
                startT = 0;
            end
            endT = endTimes(tempIdx);
            useMoveForTraining = (trainComboFlag || ~comboLocations(ii));  %only do combos if combo flag (or not a combo movement)
            useMoveForTesting = (testComboFlag || ~comboLocations(ii));
            switch trainingType
                case 'first'
                    useAsTraining = (jj <= nTrain);
                case 'last'
                    useAsTraining = (jj > (nTrial-nTrain));
                otherwise
                    useAsTraining = (jj <= nTrain);
            end
            if (useAsTraining && useMoveForTraining)            %use for training Data
                trainSubIdx{jj} = find(  (NIPTime>=startT) & (NIPTime<=endT)   );
            else
                if (useMoveForTesting)                          %use for testing Data
                    testSubIdx{jj} = find(  (NIPTime>=startT) & (NIPTime<=endT)   );
                end
            end
        end
        trainingIndexs{ii} = [trainSubIdx{:}];
        testingIndexs{ii} = [testSubIdx{:}];
    end
    trainingMask = [trainingIndexs{:}];
    testingMask = [testingIndexs{:}];
    idx = zeros(1,length(Kinematics));
    idx(testingMask) = 1;
    TestMask = logical(idx);
    idx = zeros(1,length(Kinematics));
    idx(trainingMask) = 1;
    TrainMask = logical(idx);
end

function [locationOfMovement] = alreadyExists(types,entry)
    locationOfMovement = 0;
    for jj = length(types):-1:1     %start last element since likely to be same
        if( isequal(types{jj},entry) )
            locationOfMovement = jj;
            return;
        end
    end
end