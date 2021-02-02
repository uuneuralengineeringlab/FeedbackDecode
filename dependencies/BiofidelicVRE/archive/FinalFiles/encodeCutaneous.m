function [chan, freq, amps, dur] = encodeCutaneous(contact,channelTypes,channelAmps,channelDur,varargin)
% encodeCutaneous - determines the required stimuli based on contact sensor values (uses the UChicago frequency modulation)
%
% Syntax:  [output1,output2,output3,output4] = encodeCutaneous(input1,input2,input3,input4)
%
% Inputs:
%    input1 - contact values at the current time
%    input2 - map structure that can convert a sensor region and nerve receptor type into a channel
%    input3 - list of all the amplitudes for all the channels
%    input4 - list of all the durations for all the channels
%    input5 - (optional) maximum contact force (for scaling purposed)  -- SHOULD BE REMOVED WHEN SKIN MECHANICS ARE ADDED
%
% Outputs:
%    output1 - list of all the channels that should be stimulated to produce the responses for the given contact values
%    output2 - list of all the mean frequencies that the above channels should be stimulated at
%    output3 - list of all the mean amplitudes that the above channels should be stimulated at
%    output4 - list of all the mean durations that the above channels should be stimulated at
%               
% Notes:
%    input1(index) corresponds to output1(index) and output2(index)
%
% Example:
%    [channel, frequency, amplitude, duration] = encodeCutaneous(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap);
%
% Other m-files required: 
%       UChicago Dependencies: Afferent.m, AfferentStream.m, MN_parameters.m, MN_neuron_stream.mexw64, MN_neuron_stream_wrapper.mexw64
%       Hashmap Data Type Dependencies: MapN.m, memoize.m
% Subfunctions: none
% MAT-files required: none
%
% See also: calibrateEncode.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 27-July-2015

%------------- BEGIN CODE ---------------
%% Step 0: Initialization
    persistent SA1;
    if (isempty(SA1))
        sa1 = AfferentStream('SA1','idx',1);
        sa2 = AfferentStream('SA1','idx',1);
        sa3 = AfferentStream('SA1','idx',1);
        sa4 = AfferentStream('SA1','idx',1);
        sa5 = AfferentStream('SA1','idx',1);
        sa6 = AfferentStream('SA1','idx',1);
        sa7 = AfferentStream('SA1','idx',1);
        sa8 = AfferentStream('SA1','idx',1);
        sa9 = AfferentStream('SA1','idx',1);
        sa10 = AfferentStream('SA1','idx',1);
        sa11 = AfferentStream('SA1','idx',1);
        sa12 = AfferentStream('SA1','idx',1);
        sa13 = AfferentStream('SA1','idx',1);
        sa14 = AfferentStream('SA1','idx',1);
        sa15 = AfferentStream('SA1','idx',1);
        sa16 = AfferentStream('SA1','idx',1);
        sa17 = AfferentStream('SA1','idx',1);
        sa18 = AfferentStream('SA1','idx',1);
        sa19 = AfferentStream('SA1','idx',1);
        SA1 = [sa1 sa2 sa3 sa4 sa5 sa6 sa7 sa8 sa9 sa10 sa11 sa12 sa13 sa14 sa15 sa16 sa17 sa18 sa19];
    end
    persistent RA1;
    if (isempty(RA1))
        ra1 = AfferentStream('RA','idx',1);
        ra2 = AfferentStream('RA','idx',1);
        ra3 = AfferentStream('RA','idx',1);
        ra4 = AfferentStream('RA','idx',1);
        ra5 = AfferentStream('RA','idx',1);
        ra6 = AfferentStream('RA','idx',1);
        ra7 = AfferentStream('RA','idx',1);
        ra8 = AfferentStream('RA','idx',1);
        ra9 = AfferentStream('RA','idx',1);
        ra10 = AfferentStream('RA','idx',1);
        ra11 = AfferentStream('RA','idx',1);
        ra12 = AfferentStream('RA','idx',1);
        ra13 = AfferentStream('RA','idx',1);
        ra14 = AfferentStream('RA','idx',1);
        ra15 = AfferentStream('RA','idx',1);
        ra16 = AfferentStream('RA','idx',1);
        ra17 = AfferentStream('RA','idx',1);
        ra18 = AfferentStream('RA','idx',1);
        ra19 = AfferentStream('RA','idx',1);
        RA1 = [ra1 ra2 ra3 ra4 ra5 ra6 ra7 ra8 ra9 ra10 ra11 ra12 ra13 ra14 ra15 ra16 ra17 ra18 ra19];
    end
    persistent RA2;
    if (isempty(RA2))
        pc1 = AfferentStream('PC','idx',1);
        pc2 = AfferentStream('PC','idx',1);
        pc3 = AfferentStream('PC','idx',1);
        pc4 = AfferentStream('PC','idx',1);
        pc5 = AfferentStream('PC','idx',1);
        pc6 = AfferentStream('PC','idx',1);
        pc7 = AfferentStream('PC','idx',1);
        pc8 = AfferentStream('PC','idx',1);
        pc9 = AfferentStream('PC','idx',1);
        pc10 = AfferentStream('PC','idx',1);
        pc11 = AfferentStream('PC','idx',1);
        pc12 = AfferentStream('PC','idx',1);
        pc13 = AfferentStream('PC','idx',1);
        pc14 = AfferentStream('PC','idx',1);
        pc15 = AfferentStream('PC','idx',1);
        pc16 = AfferentStream('PC','idx',1);
        pc17 = AfferentStream('PC','idx',1);
        pc18 = AfferentStream('PC','idx',1);
        pc19 = AfferentStream('PC','idx',1);
        RA2 = [pc1 pc2 pc3 pc4 pc5 pc6 pc7 pc8 pc9 pc10 pc11 pc12 pc13 pc14 pc15 pc16 pc17 pc18 pc19];
    end
%% Step 0.5: Scale contact values -- Temporary Fix until skin mechanics are added.
    try
    	contactMax = varargin{1};
    catch
    	contactMax = 20;
    end
    contact = (contact / contactMax);
%% Step 1: Determine frequency response:  U Chicago Model
    len = length(contact);
    SA1frequency = zeros(len,1);
    RA1frequency = SA1frequency;
    RA2frequency = SA1frequency;
    for ii = 1:len
        val = contact(ii);
        if(isnan(val))
            val = 0;
        end
        SA1frequency(ii) = SA1(ii).response(val,30);
        RA1frequency(ii) = RA1(ii).response(val,30);
        RA2frequency(ii) = RA2(ii).response(val,30);
    end
    frequency = [SA1frequency, RA1frequency, RA2frequency];
%% Step 2: Determine which channels correspond to that receptor type (1 - 200) and are in the right region
    firing = frequency > 0;
    minNum = length(frequency(frequency > 0));
    [numSens, numRecp] = size(frequency);
    chan = zeros(1,minNum*5);       % Allocating plenty of extra space.  Up to 5 receptors per field.  This can be changed to allocate more space.
    freq = chan;
    nxt = 0;
    for ii = 1:numSens
        for jj = 1:numRecp
            if(firing(ii,jj))
                switch jj
                    case 1
                        recpt = 'SA1';
                    case 2
                        recpt = 'RA1';
                    case 3
                        recpt = 'RA2';
                end
                try
                    tempChan = channelTypes(ii,recpt);
                   	tempFreq = frequency(ii,jj);
                    for kk = 1:length(tempChan)
                        nxt = nxt + 1;
                        chan(nxt) = tempChan(kk);
                        freq(nxt) = tempFreq;
                    end
                catch
                end
            end 
        end
    end
%% Step 3: Simplify channels and frequencies
    freq = freq(chan ~= 0);
    chan = chan(chan ~= 0);
    [chan, m] = unique(chan);
    freq = freq(m);
%% Step 4: Determine the amplitude for that channel (Known value, should be constant per channel)
    amps = chan;
    dur = amps;
    for ii = 1:length(chan)
        amps(ii) = channelAmps(chan(ii));
        dur(ii) = channelDur(chan(ii));
    end
%% ------------ END OF CODE --------------
end