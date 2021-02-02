function weightsMatrix = createCARWeightsMatrix(inputData)

%Preprocessing data for noise reduction
%For HAPTIX Virtual Referencing
%Input channel order raw data AT LEAST 450000 long
%weightsMatrix (the function output) is a 96x96 (or 192x192) matrix of
%channel weights

%Multiply weightsMatrix by the 96 x N sample array data to reduce noise

%Zack Kagan
%June 12, 2015
% modified by SMW 7/2015

if size(inputData,1) > 100 %How many arrays were used? (ie 96 or 192 channels)
    numArrays = 2;
else numArrays = 1;
end

dSize = min(450000, size(inputData,2));
% electrodeZeroBased = arrayWiringConversion( (1:96),'TDT1', 'ConnectorChannel', 'Electrode' ) - 1;
%needed for converting from channel order to electrode order
electrodeZeroBased = mapRippleUEA(1:96, 'c2e');

Array1CalibrationPreData = inputData(1:96,1:dSize); %uses first 15 seconds of data

for i = 1:length(electrodeZeroBased) %puts data into electrode order
    A1CalibrationData(electrodeZeroBased(i),:) = Array1CalibrationPreData(i,:);
end

A1Data = detrend(double(A1CalibrationData),'constant');

rms1 = rms(A1CalibrationData'); clear A1CalibrationData;
exclude1 = [find(rms1 > mean(rms1)+std(rms1)) find(rms1 < mean(rms1)-std(rms1)) 10 80 90];
%make list of channels to exclude from algorithm

tstart = tic;

w1 = zeros(96);

for center = setdiff(1:size(A1Data,1),exclude1) %for each electrode
    
    %    observed = trainData(center,:);
    %    testObserved = testData(center,:);
    
    selectedElectrodes1 = setdiff(getElectrodesInRadius(3.2,center),exclude1); %radius 3.2 electrodes
    %which electrodes will be used in the regression
    
    o1 = A1Data(center,1:end); %observed data
    p1 = A1Data(setdiff(selectedElectrodes1,center),1:end); %predictor data
    
    wOrig = p1'\o1'; %regression weights
    w = wOrig;
    
    for i = 1:length(w) %put weights into matrix
        w1(electrodeZeroBased == center,electrodeZeroBased == selectedElectrodes1(i)) = w(i);
    end
    
end

clear A1Data; % quick fix for memory hog issue

if numArrays > 1 %do the same for another array if data is present
    
    Array2CalibrationPreData = inputData(97:192,1:dSize);
    
    for i = 1:length(electrodeZeroBased)
        A2CalibrationData(electrodeZeroBased(i),:) = Array2CalibrationPreData(i,:);
    end
    
    A2Data = detrend(double(A2CalibrationData),'constant');
    
    rms2 = rms(A2CalibrationData'); clear A2CalibrationData;
    exclude2 = [find(rms2 > mean(rms2)+std(rms2)) find(rms2 < mean(rms2)-std(rms2)) 10 80 90];
    
    w2 = zeros(96);
    
    for center = setdiff(1:size(A2Data,1),exclude2)
      
        selectedElectrodes2 = setdiff(getElectrodesInRadius(3.2,center),exclude2); %radius 3.2 electrodes
        
        o2 = A2Data(center,1:end);
        p2 = A2Data(setdiff(selectedElectrodes2,center),1:end);
        
        wOrig = p2'\o2';
        w = wOrig;
        
        for i = 1:length(w)
            w2(electrodeZeroBased == center,electrodeZeroBased == selectedElectrodes2(i)) = w(i);
        end

    end
    clear A2Data inputData;
    weights = eye(192) - [w1 zeros(96); zeros(96) w2]; 
    %new data = old data - estimated data
    %i.e. ones on the diagonal - predictor weights
    %so the future multiplication produces the correct results
    
else weights = eye(96) - w1;
    
end

weightsMatrix = weights;

end

% redo this function.  Use genSurrIdxs to find surrounding elecs, then find
% weights in using '\'

