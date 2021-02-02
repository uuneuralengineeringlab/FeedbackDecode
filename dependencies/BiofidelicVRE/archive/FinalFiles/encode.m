function [channel,frequency,amplitude,duration] = encode(contact,motorpos,motorvel,calibration,varargin)
% encode - determines the required stimulation parameters based on all sensor values
%
% Syntax:  [output1,output2,output3,output4] = encode(input1,input2,input3,input4,input5,input6,input7,input8,input9,input10)
%
% Inputs:
%    input1 - contact values at the current time
%    input2 - position values at the current time
%    input3 - velocity values at the current time
%    input4 - struct containing all of the calibration parameters
%    input5 - (optional) string to choose encoding sensations: 'cutaneous','proprioception','both'
%    input6 - (optional) string to choose model type: 'UChicago','curveFit'
%    input7 - (optional) SA1 threshold (vector of 19 values, if the size is not 19x1, then the first value of the vector is used as a scalar)
%    input8 - (optional) RA1 threshold (vector of 19 values, if the size is not 19x1, then the first value of the vector is used as a scalar)
%    input9 - (optional) MS1 threshold (vector of 13 values, if the size is not 13x1, then the first value of the vector is used as a scalar)
%    input10 - (optional) MS2 threshold (vector of 13 values, if the size is not 13x1, then the first value of the vector is used as a scalar)
%    input11 - (optional) max contact value (single scalar value)
%    input12 - (optional) max contact velocity (single scalar value)
%    input13 - (optional) max contact acceleration (single scalar value)
%    input14 - (optional) max joint velocity (single scalar value)
%
% Outputs:
%    output1 - list of all the channels that should be stimulated to produce the responses for the given contact values
%    output2 - list of all the mean amplitudes that the above channels should be stimulated at
%    output3 - list of all the mean durations that the above channels should be stimulated for
%    output4 - list of all the mean frequencies that the above channels should be stimulated at
%               
% Notes:
%    none
%
% Example:
%    none
%
% Other m-files required: none
% Subfunctions: encodeProprioception.m, encodeCutaneous.m, encodeCutaneous2.m
% MAT-files required: none
%
% See also: calibrateEncode.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 27-July-2015

%% ------------- BEGIN CODE --------------
% Step 0: Default parameters and optional overrides
    CorP = 'both';
    freqFitType = 'UChicago';
    SA1threshold = .2;
    RA1threshold = .2;
    MS1threshold = 1;
    MS2threshold = .1;
    contactForceMax = 20;
    contactVelMax = 20;
    contactAccMax = 5;
    jointVelMax = 50;
    try     % Option 1: Cutaneous or Proprioceptive
        CorP = varargin{1};
    catch
    end  
    try     % Option 2: UChicago model, or fit parameters?
        freqFitType = varargin{2};
    catch  
    end
    try     % Option 3: SA1 threshold
        SA1threshold = varargin{3};
    catch
    end
    try     % Option 4: RA1 threshold
        RA1threshold = varargin{4};
    catch
    end
    try     % Option 5: MS1 threshold
        MS1threshold = varargin{5};
    catch
    end
    try     % Option 6: MS2 threshold
        MS2threshold = varargin{6};
    catch
    end
    try     % Option 7: Max contact force
        contactForceMax = varargin{7};
    catch
    end
    try     % Option 8: Max contact velocity
        contactVelMax = varargin{8};
    catch
    end
    try     % Option 9: Max contact accerlation
        contactAccMax = varargin{9};
    catch
    end
    try     % Option 10: Max joint velocity
        jointVelMax = varargin{10};
    catch
    end
    %create frequency map:
    frequencyMap = [calibration.frequencyMap1;calibration.frequencyMap2;calibration.frequencyMap3];
% Step 1: Get all channels for cutaneous response and channels for proprioceptive response
    switch CorP
        case 'cutaneous'
            switch freqFitType
                case 'curveFit'
                    [channel, frequency, amplitude, duration] = encodeCutaneous2(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap,frequencyMap,SA1threshold,RA1threshold,contactForceMax,contactVelMax,contactAccMax);
                otherwise
                	[channel, frequency, amplitude, duration] = encodeCutaneous(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap,contactForceMax); 
            end
        case 'proprioception'
            [channel, frequency, amplitude, duration] = encodeProprioception(motorpos,motorvel,calibration.proprioceptionMap,calibration.amplitudeMap,calibration.durationMap,frequencyMap,MS1threshold,MS2threshold,jointVelMax);
        otherwise
            switch freqFitType
                case 'curveFit'
                    [cutaneousChannel, cutaneousFrequency, cutaneousAmplitude, cutaneousDuration] = encodeCutaneous2(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap,frequencyMap,SA1threshold,RA1threshold,contactForceMax,contactVelMax,contactAccMax);
                otherwise
                	[cutaneousChannel, cutaneousFrequency, cutaneousAmplitude, cutaneousDuration] = encodeCutaneous(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap,contactForceMax); 
            end
            [proprioChannel, proprioFrequency, proprioAmplitude, proprioDuration] = encodeProprioception(motorpos,motorvel,calibration.proprioceptionMap,calibration.amplitudeMap,calibration.durationMap,frequencyMap,MS1threshold,MS2threshold,jointVelMax);
            proprioChannel
            proprioFrequency
            proprioAmplitude
            proprioDuration
            channel = [cutaneousChannel proprioChannel];
            frequency = [cutaneousFrequency proprioFrequency];
            amplitude = [cutaneousAmplitude proprioAmplitude];
            duration = [cutaneousDuration proprioDuration];
            [channel,mask] = unique(channel);
            frequency = frequency(mask);
            amplitude = amplitude(mask);
            duration = duration(mask);
    end    
% ------------ END OF CODE ---------------
end
