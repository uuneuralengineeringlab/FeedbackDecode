function [cutaneousMap,proprioceptionMap,amplitudeMap, durationMap, frequencyMap1, frequencyMap2, frequencyMap3, varargout] = calibrateEncode_FD(SRF)
% calibrateContact - creates the required maps to call the encode function in realtime.
%
% Syntax:  [output1,output2,output3,varargout] = calibrateEncode(input1)
%
% Inputs:
%    input1 - SRF file
%
% Outputs:
%    output1 - hashmap that gives the channel number corresponding to a cutaneous receptor type in a specific contact sensor location
%    output2 - hashmap that gives the channel number corresponding to a proprioception receptor type in a specific proprioception sensor location
%    output3 - simple map structure to access amplitude used on each channel
%    output4 - simple map structure to access pulse duration used on each channel
%    output5 - simple map structure to access the fit coefficients used to calculate frequency
%    output6 - (optional) SRF file after calibration
%
% Example:
%    [cutaneousMap, proprioceptionMap,channelAmplitudeMap,newSRF] = calibrateEncode(mySRF);  
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 21-July-2015

%------------- BEGIN CODE ---------------
%% Initialization:
    fprintf('Starting calibration:\n')
    fprintf('\tAuto-assigning receptor types.......')
    assigned = 0;
    try
        assigned = SRF.info.receptors;
    catch
    end
    if(assigned)
        fprintf('already assigned!\n')
    else
        try
            SRF = assignReceptors_FD(SRF);
            fprintf('success!\n')
        catch
            fprintf('failed!\n')    
        end
    end
%% Calibration:
    fprintf('\tGenerating proprioception map.......');
    try
        [proprioceptionMap, SRF] = calibrateProprioception(SRF);
        fprintf('success!\n')
    catch
        fprintf('failed!\n')
    end
    fprintf('\tGenerating cutaneous map............');
    try
        [cutaneousMap, SRF] = calibrateCutaneous(SRF);
        fprintf('success!\n')
    catch
        fprintf('failed!\n')
    end
    fprintf('\tGenerating channel map..............')
    try
        channelMap = calibrateChannels(SRF);
        amplitudeMap = channelMap(1,:);
        durationMap = channelMap(2,:);
        frequencyMap1 = channelMap(3,:);
        frequencyMap2 = channelMap(4,:);
        frequencyMap3 = channelMap(5,:);
        fprintf('success!\n')
    catch
        fprintf('failed!\n')
    end
    varargout{1} = SRF;
    fprintf('Calibration complete!\n')
%% ------------- END OF CODE ------------
end

function [channelMap] = calibrateChannels(SRF)
% calibrateChannels - creates an array that can be used to quickly retrieve the required amplitude for any channel
%
% Syntax:  [output1] = calibrateChannels(input1)
%
% Inputs:
%    input1 - SRF file
%
% Outputs:
%    output1 - arraylist of channel amplitudes, where amplitudes(200) would give the amplitude on channel 200
%
% Example:
%    amplitudeMap = calibrateChannels(mySRF);  
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 29-June-2015

%------------- BEGIN CODE ---------------
    try %get num channels
        channelCount = SRF.info.numberOfChannels_d;
    catch
        channelCount = 200;
    end
    channelMap = zeros(5,channelCount);
    for jj = 1:channelCount
        channelSRF = getSRF_FD(SRF,'electrodes_d',jj,'onlyinvolves');
        qualities = {channelSRF.output.quality_s};
        qmask = cellfun(@(x)~isempty(x),qualities);
        channelSRF.output = channelSRF.output(qmask);
        channelSRF.input = channelSRF.input(qmask);
        if(~isempty(channelSRF.output))
            amps = [channelSRF.input.amplitudes_uA_d];
            channelMap(1,jj) = mean(amps);
            dur = [channelSRF.input.pulseDurations_ms_d];
            channelMap(2,jj) = mean(dur);
            %% CREATE STIMULUS-RESPONSE CURVES
            len = length(channelSRF.output);    %number of points used on that same channel
            %Determine receptor type
            receptor = channelSRF.output(1).receptorType_s;
            if ( (len >= 5) && (~isempty(receptor)) )                       %at least 5 points to calculate a fit
                %allcate space:
                freq = zeros(1,len);
                intensity = freq;
                %get frequency and intensity for each trial
                for kk = 1:len
                        val = channelSRF.input(kk).frequencyPatterns_Hz_a;      %frequency array for that trial
                        if(iscell(val))
                            val = val{1};       %cell2double
                        end
                        freq(kk) = mean(val);                           %average frequency for that trial
                        val = channelSRF.output(kk).Intensity_distance_d;
                        % CHECK IF POSITION / VELOCITY VALUES NEED NEGATED
                        if( strcmp(receptor,'MS1') || strcmp(receptor,'MS2') || strcmp(receptor,'SA2') )
                            marker = channelSRF.output(kk).markerType_s;
                            sensor = channelSRF.output(kk).proprioceptionSensor_s;
                            if( strcmp(marker,'UpArrow') )
                                val = -val;
                            else
                                leftIndex = strcmp(marker,'LeftArrow') & any(strcmp(sensor,'index_ABD'));
                                rightPinky = strcmp(marker,'RightArrow') & any(strcmp(sensor,'pinky_ABD'));
                                mask = leftIndex | rightPinky;
                                if ( any(mask) )
                                    val = -val;
                                end
                            end
                        end
                        intensity(kk) = mean(val);  
                end
                %shift and scale intensities for fit:
                minval = min(intensity);
                intensity = intensity - minval;     %make values positive and lowest value always 0
                intensity = intensity ./ max(intensity);     %make max value 1
                intensity = intensity .* 10;               %multiply by 1000 to avoid trucation errors
                %determine fit type based on receptor type:
                %defined start positions
                s1 = 0.120611613297162;
                s2 = 0.589507484695059;
                s3 = 0.226187679752676;
                if (minval < 0)     %Set to negative to allow fit to converge
                    s2 = -s2;
                end
                switch receptor
                    %NOTE: All functions have been inversed
                    case {'MS1','MS2','SA2'}    % Linear Fit
                        ft = fittype( '(R - a)./b', 'independent', 'R', 'dependent', 'S' );
                        opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
                        opts.Display = 'Off';
                        opts.StartPoint = [s1 , s2];
                    case {'RA1','RA2'}          % Logrithmic Fit
                        ft = fittype( 'exp( (R - a)./b )', 'independent', 'R', 'dependent', 'S' );
                        opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
                        opts.Display = 'Off';                       
                        opts.StartPoint = [-s1, s2];
                    case 'SA1'                  % Shifted Logrithmic Fit
                        ft = fittype( 'exp( (R - a)./b ) + c', 'independent', 'R', 'dependent', 'S' );
                        opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
                        opts.Display = 'Off';
                        opts.StartPoint = [-s1, s2, s3];
                    otherwise
                        fprintf('Receptor of type %s not found\n',receptor);
                end
                %fit the data
                yData = freq';
                xData = intensity';
                fitresult = fit( xData, yData, ft, opts );
                %store coeffs
                coeffvals = coeffvalues(fitresult);
                numCoef = length(coeffvals);
                channelMap((3:(2+numCoef)),jj) = coeffvals;
            end
            % -----------------------------------------
        end
    end
end

function [types,varargout] = calibrateProprioception(SRF)
% calibrateProprioception - creates a datastructure that can be used to quickly convert contact values to stimulations
%
% Syntax:  [output1,varargout] = calibrateProprioception(input1)
%
% Inputs:
%    input1 - SRF file
%
% Outputs:
%    output1 - hashmap that gives the channel number corresponding to a given sensor and receptor type
%    output2 - (optional) SRF file after calibration
%
% Example:
%    movementKey = calibrateProprioception(mySRF);  
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 29-June-2015

%------------- BEGIN CODE ---------------
    try
        sensorLabels = SRF.info.proprioceptionLabels;
    catch
        SRF = assignProprioceptionSensor_FD(SRF);
        sensorLabels = SRF.info.proprioceptionLabels;
    end
    try %get num channels
        channelCount = SRF.info.numberOfChannels_d;
    catch
        channelCount = 200;
    end
    sensorNames = fieldnames(sensorLabels);
    numSensor = length(sensorNames);
    types = MapN('UniformValues',false);
    for ii = 1:numSensor
        sensorName = sensorNames{ii};
        sensorSRF = getSRF_FD(SRF,'proprioceptionSensor_s',sensorName,'onlyinvolves');
        if(~isempty(sensorSRF.output))
            for jj = 1:channelCount
                channelSRF = getSRF_FD(sensorSRF,'electrodes_d',jj,'onlyinvolves');
                if(~isempty(channelSRF.output))
                    r = channelSRF.output(1).receptorType_s;
                    % possibly merge SA2 and MS2 for calibration key
                    if(~isempty(r))
                        if(isKey(types,ii,r))
                            temp = types(ii,r);
                            temp = [temp jj];
                            types(ii,r) = temp;
                        else
                            types(ii,r) = jj;
                        end
                    end
                end
            end
        end
    end
    varargout{1} = SRF;
%% ------------- END OF CODE ------------
end

function [types,varargout] = calibrateCutaneous(SRF)
% calibrateCutaneous - creates a datastructure that can be used to quickly convert contact values to stimulations
%
% Syntax:  [output1,varargout] = calibrateCutaneous(input1)
%
% Inputs:
%    input1 - SRF file
%
% Outputs:
%    output1 - hashmap that gives the channel number corresponding to a given sensor and receptor type
%    output2 - (optional) SRF file after calibration
%
% Example:
%    contactKey = calibrateCutaneous(mySRF);  
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 29-June-2015

%------------- BEGIN CODE ---------------
    try %get labels
        sensorLabels = SRF.info.contactLabels;
    catch
        SRF = assignContactSensor_FD(SRF);
        sensorLabels = SRF.info.contactLabels;
    end
    try %get num channels
        channelCount = SRF.info.numberOfChannels_d;
    catch
        channelCount = 200;
    end  
    sensorNames = fieldnames(sensorLabels);
    numSensor = length(sensorNames);
    types = MapN('UniformValues',false);
    for ii = 1:numSensor %create map
        sensorName = sensorNames{ii};
        sensorSRF = getSRF_FD(SRF,'contactSensor_s',sensorName,'onlyinvolves');
        if(~isempty(sensorSRF.output))
            for jj = 1:channelCount
                channelSRF = getSRF_FD(sensorSRF,'electrodes_d',jj,'onlyinvolves');
                if(~isempty(channelSRF.output))
                    r = channelSRF.output(1).receptorType_s;
                    if(~isempty(r))
                        if(isKey(types,ii,r))
                            temp = types(ii,r);
                            temp = [temp jj];
                            types(ii,r) = temp;
                        else
                            types(ii,r) = jj;
                        end
                    end
                end
            end
        end
    end
    varargout{1} = SRF;
%% ------------- END OF CODE ------------
end