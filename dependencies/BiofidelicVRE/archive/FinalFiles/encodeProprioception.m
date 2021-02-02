function [chan, freq, amps, dur] = encodeProprioception(position,velocity,channelTypes,channelAmps,channelDur,channelFreq,varargin)
% encodeProprioception - determines the required stimuli based on joint angle and joint velocity sensor values.
%
% Syntax:  [output1,output2,output3] = encodeProprioception(input1,input2,input3,input4,input5,input6,input7,input8)
%
% Inputs:
%    input1 - motor position values at the current time
%    input2 - motor velocity values at the current time
%    input3 - map structure that can convert a sensor region and nerve receptor type into a channel
%    input4 - list of all the amplitudes for all the channels
%    input5 - list of all the durations for all the channels
%    input6 - list of all the frequency fit parameters for all the channels
%    input7 - (optional) MS1 threshold
%    input8 - (optional) MS2 threshold
%    input9 - (optional) max joint velocity (for scaling)
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
%    frequencyMap = [calibration.frequencyMap1;calibration.frequencyMap2;calibration.frequencyMap3];
%    [channel, frequency, amplitude, duration] = encodeProprioception(motorpos,motorvel,calibration.proprioceptionMap,calibration.amplitudeMap,calibration.durationMap,frequencyMap);
%
% Other m-files required:
%       Hashmap Data Type Dependencies: MapN.m, memoize.m
% Subfunctions: getReceptorType(), getFrequency()
% MAT-files required: none
%
% See also: calibrateEncode.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 27-July-2015

%------------- BEGIN CODE ---------------
%% Step 0: Set Default Parameters and adjust based on optional inputs
    try     %set MS1 threshold
        MS1Threshold = varargin{1};
    catch
        MS1Threshold = .1;
    end
    try     %set MS2 threshold
    	MS2Threshold = varargin{2};
    catch
    	MS2Threshold = 1;
    end
    try     %set max joint velocity
    	jointVelMax = varargin{3};
    catch
    	jointVelMax = 20;
    end
%% Step 1: Determine the receptor type to innverate (MS1 or MS2/SA2)
    receptor = getReceptorType(position,velocity,MS1Threshold,MS2Threshold);
%% Step 2: Determine the channel for each receptor
    firing = receptor > 0;
    minNum = length(receptor(receptor > 0));
    [numSens, numRecp] = size(receptor);
    chan = zeros(1,minNum*5);        % Allocating plenty of extra space.  Up to 5 receptors per field.  This can be changed to allocate more space.
    receptorRegion = chan;
    receptorType = cell(size(chan));
    nxt = 0;
    for ii = 1:numSens
        for jj = 1:numRecp
            if(firing(ii,jj))
                switch jj
                    case 1
                        recpt = 'MS1';
                    case 2
                        recpt = 'MS2';
                    case 3
                        recpt = 'SA2';
                end
                try
                    tempChan = channelTypes(ii,recpt);
                    for kk = 1:length(tempChan)
                        nxt = nxt + 1;
                        chan(nxt) = tempChan(kk);
                        receptorType{nxt} = recpt;
                        receptorRegion(nxt) = ii;
                    end
                catch
                end
            end 
        end
    end
%% Step 3: Simplify channels
    receptorType = receptorType(chan ~= 0);
    receptorRegion = receptorRegion(chan ~= 0);
    chan = chan(chan ~= 0);
    [chan, m] = unique(chan);
    receptorType = receptorType(m);
    receptorRegion = receptorRegion(m);
%% Step 4: Determine the amplitude for that channel (Known value, should be constant per channel)
    amps = chan;
    dur = amps;
    for ii = 1:length(chan)
        amps(ii) = channelAmps(chan(ii));
        dur(ii) = channelDur(chan(ii));
    end
%% Step 5: Determine the frequency for that channel (Steven's Law)
    freq = getFrequency(position,velocity,receptorType,receptorRegion,chan,channelFreq,jointVelMax);
%% ------------ END OF CODE --------------
end

function [type] = getReceptorType(position, velocity, velocityThreshold, restingPosThreshold, varargin)
% getReceptorType - determines the receptor type based on finite difference
%
% Syntax:  [output1] = getReceptorType(input1,input2,varargin)
%
% Inputs:
%    input1 - sensor position
%    input2 - sensor velcoity
%    input4 - threshold value for determining rest position -- default is shown below
%    input5 - threshold value for determining velocity firing -- default is .5 for all motors
%
% Outputs:
%    output1 - receptor type for all contact values, given as a 2 bit mask, [MS1, MS2/SA2], where 1 = true.
%
% Example:
%    receptor = getReceptorType(position, velocity);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also:

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 28-July-2015

%------------- BEGIN CODE ---------------
    %Threshold error check
    if( length(restingPosThreshold) ~= length(position) )
        restingPosThreshold = restingPosThreshold(1);
    end
    if( length(velocityThreshold) ~= length(velocity) )
        velocityThreshold = velocityThreshold(1);
    end
    %Set default parameters
    restingPos = [ ...  % neutral positions
        -1.07;...       % 1 wrist_PRO (pronate)
        -0.08;...       % 2 wrist_UDEV (ulnar deviation)
        0;...           % 3 wrist_FLEX (flexion)
        1.5;...         % 4 thumb_ABD (abduction)
        0.5;...         % 5 thumb_MCP (metacarpal)
        0.5;...         % 6 thumb_PIP (proximal interphlangeal)
        0.2;...         % 7 thumb_DIP (distal interphlangeal)
        0.15;...        % 8 index_ABD (abduction)
        0.4;...         % 9 index_MCP (metacarpal)
        0.4;...         % 10 middle_MCP (metacarpal)
        0.4;...         % 11 ring_MCP (metacarpal)
        0.15;...        % 12 pinky_ABD (abduction)
        0.4     ];      % 13 pinky_MCP (metacarpal)
    %Preallocate
    len = length(position);
    type = zeros(len,3);   %Binary masks for: MS1 and MS2/SA2.  All initially set to off - no firing
    %set SA2/MS2
    Posmask = ( ( position > ( restingPos + restingPosThreshold ) ) | ( position < ( restingPos - restingPosThreshold ) ) );
    type(Posmask,2:3) = 1;         %set MS2/SA2's on if needed
    %set MS1
    MS1mask = ( abs(velocity) > velocityThreshold );
    type(MS1mask,1) = 1;        %set MS1 to true
%------------- END OF CODE --------------
end

function [freq] = getFrequency(position,velocity,receptor,regions,channel,channelFreq,jointVelMax,varargin)
% getFrequency - determines the frequency the receptor should fire at based on a curve fit model
%
% Syntax:  [output1] = getFrequency(input1,input2,input3,input4,input5,input6,input7)
%
% Inputs:
%    input1 - joint positions
%    input2 - joint velocities
%    input3 - receptor type
%    input4 - region of receptor
%    input5 - channel associated with the region
%    input6 - frequency parameter map
%    input7 - maximum joint velocity (for scaling)
%
% Outputs:
%    output1 - frequency for each channel
%
% Example:
%    freq = getFrequency(position,velocity,receptorType,receptorRegion,chan,channelFreq);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also:

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 15-June-2015

%------------- BEGIN CODE ---------------
    numChan = length(channel);
    freq = zeros(1,numChan);
    for ii = 1:numChan
        % Get receptor, region, position and velocity
        recpt = receptor{ii};
        region = regions(ii);
        % Determine response (position or velocity)
        switch recpt
            case 'MS1'
                vel = abs(velocity(region));
                % Normalize Velocity
                vel = vel / jointVelMax;      %user specified normalization since velocity range is not known.
                if (vel > 1)
                    vel = 1;
                end
                R = vel * 10;        %multiply by 10 since fit coefficients are based on a max intensity scaled up to 10
            case {'MS2','SA2'}
                pos = position(region);
                % Normalize Position
                switch region
                    case 4          %thumb_abd
                        pos = pos / 2.1;
                    case 5          %thumb_mcp
                        pos = pos / 1;
                    case {8,12}      %index_adb, pinky_abd
                        pos = pos / .34 ;
                    case {9,10,11,13}  %index_mcp, middle_mcp, ring_mcp, pinky_mcp
                        pos = pos / 1.6;
                    case 3          %wrist_flex
                        pos = pos + 1;
                        pos = pos / 2;
                end
                R = pos * 10;       %multiply by 10 since fit coefficients are based on a max intensity scaled up to 10
        end
        % Linear fit
        a = channelFreq(1,channel(ii));
        b = channelFreq(2,channel(ii));
        S = (R - a)./b;
        freq(1,ii) = S;
    end
%------------- END OF CODE --------------
end