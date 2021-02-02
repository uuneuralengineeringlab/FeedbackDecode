function [chan, freq, amps, dur] = encodeCutaneous2(currentContact,channelTypes,channelAmps,channelDur,channelFreq,varargin)
% encodeCutaneous2 - determines the required stimuli based on contact sensor values (uses curvefit frequency modulation)
%
% Syntax:  [output1,output2,output3,output4] = encodeCutaneous(input1,input2,input3,input4,input5,input6,input7)
%
% Inputs:
%    input1 - contact values at the current time
%    input2 - map structure that can convert a sensor region and nerve receptor type into a channel
%    input3 - list of all the amplitudes for all the channels
%    input4 - list of all the durations for all the channels
%    input5 - list of all the frequency fit parameters for all the channels
%    input6 - (optional) SA1 threshold -- Default value is .2
%    input7 - (optional) RA1 threshold -- Default value is .2
%    input8 - (optional) max contact force (for scaling)
%    input9 - (optional) max contact velocity (for scaling)
%    input10 - (optional) max contact acceration (for scaling)
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
%    [channel, frequency, amplitude, duration] = encodeCutaneous2(contact,calibration.cutaneousMap,calibration.amplitudeMap,calibration.durationMap);
%
% Other m-files required:
%       Hashmap Data Type Dependencies: MapN.m, memoize.m
% Subfunctions: getReceptorType(),
% MAT-files required: none
%
% See also: calibrateEncode.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 22-July-2015

%------------- BEGIN CODE ---------------
%% Step 0: Initialization
%Define persistent variables and assign them values on the first two calls to the function
    persistent pastContact1;
    if (isempty(pastContact1))
        pastContact1 = currentContact;
        chan = []; freq = []; amps = []; dur = [];
        return;
    end
    persistent pastContact2;
    if (isempty(pastContact2))
        pastContact2 = pastContact1;
        pastContact1 = currentContact;
        chan = []; freq = []; amps = []; dur = [];
        return;
    end
%Setup default parameters and adjust based on optional inputs
    try     %Set SA1 Threshold
        SA1Threshold = varargin{1};
    catch
        SA1Threshold = .2;
    end
    try     %Set RA1 Threshold
        RA1Threshold = varargin{2};
    catch
        RA1Threshold = .2;
    end
    try     %Set max contact force (for scaling)
    	maxforce = varargin{3};
    catch
    	maxforce = 20;
    end
    try     %Set max contact velocity (for scaling)
    	maxvel = varargin{4};
    catch
    	maxvel = 20;
    end
    try     %Set max contact acceration (for scaling)
    	maxacc = varargin{5};
    catch
    	maxacc = 5;
    end
%% Step 1: Determine the receptor type to innverate (SAI, RAI, RAII)
    [receptor, velocity, acceleration] = getReceptorType(currentContact,pastContact1,pastContact2,SA1Threshold,RA1Threshold);
%% Step 2: Determine which channels correspond to that receptor type (1 - 200) and are in the right region
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
                        recpt = 'SA1';
                    case 2
                        recpt = 'RA1';
                    case 3
                        recpt = 'RA2';
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
%% Step 3: Simplify channels and frequencies
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
    freq = getFrequency(currentContact,velocity,acceleration,receptorType,receptorRegion,chan,channelFreq,maxforce,maxvel,maxacc);
%% Step 6: Update Contact Values for next iteration
    pastContact2 = pastContact1;
    pastContact1 = currentContact;
%% ------------ END OF CODE --------------
end

function [type,d1,d2] = getReceptorType(current, past1, past2, SA1threshold, RA1threshold, varargin)
% getReceptorType - determines the receptor type based on finite difference
%
% Syntax:  [output1] = getReceptorType(input1,input2,input3, varargin)
%
% Inputs:
%    input1 - current sensor values
%    input2 - sensor values one iteration ago
%    input3 - sensor values two iterations ago
%    input4 - threshold value for determining SA1
%    input5 - threshold value for determining RA1
%
% Outputs:
%    output1 - receptor type for all contact values, given as a 3 bit mask, [SA1, RA1, RA2], where 1 = true.
%
% Example:
%    receptor = getReceptorType(currentvalues, oldvalues1, oldvalues2, 10);
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
% July 2015; Last revision: 22-July-2015

%------------- BEGIN CODE ---------------
    %threshold error checking
    if( length(SA1threshold) ~= length(current) )
        SA1threshold = SA1threshold(1);
    end
    if( length(RA1threshold) ~= length(past1) )
        RA1threshold = RA1threshold(1);
    end
    %Preallocate
    len = length(current);
    type = zeros(len,3);   %Binary masks for: SA1, RA1, RA2.  All initially set to off
    values = [past2, past1, current]; 
    d1 = diff(values,1,2);  %d/dx
    d1 = d1(:,2);           %only derivative for current value
    d2 = diff(values,2,2);  %d2/dx2
    %set SA1
    SAmask = ((current >= SA1threshold) & (d1 >= -RA1threshold));
    type(SAmask,1) = 1;         %set SA1 to true
    %set RA1
    RA1mask = (abs(d1) >= RA1threshold);
    type(RA1mask,2) = 1;        %set RA1 to true
    %set RA2
    on = (current >= SA1threshold) & (past1 < SA1threshold) & (past2 < SA1threshold);
    off = (current < SA1threshold) & (past1 >= SA1threshold) & (past2 >= SA1threshold);
    RA2mask = on | off;
    type(RA2mask,3) = 1;        %set RA2 to true
%------------- END OF CODE --------------
end

function [freq] = getFrequency(contactforce,velocity,acceleration,receptor,regions,channel,channelFreq,maxforce,maxvel,maxacc,varargin)
% getFrequency - determines the frequency the receptor should fire at based on a curve fit model
%
% Syntax:  [output1] = getFrequency(input1,input2,input3,input4,input5,input6)
%
% Inputs:
%    input1 - current contact values
%    input2 - velocity of contacts
%    input3 - acceleration of contacts
%    input4 - receptor type
%    input5 - region of receptor
%    input6 - channel associated with the region
%    input7 - frequency parameter map
%    input8 - max contact force (for scaling)
%    input9 - max contact velocity (for scaling)
%    input10 - max contact acceleration (for scaling)
%
% Outputs:
%    output1 - frequency for each channel
%
% Example:
%    freq = getFrequency(position,velocity,acceration,receptorType,receptorRegion,chan,channelFreq);
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
% June 2015; Last revision: 27-July-2015

%------------- BEGIN CODE ---------------
    numChan = length(channel);
    freq = zeros(1,numChan);
    for ii = 1:numChan
        % Get receptor, region, position and velocity
        recpt = receptor{ii};
        region = regions(ii);
        % Determine response (position or velocity or acceleration)
        switch recpt
            case 'RA1'
                vel = abs(velocity(region));
                % Normalize Velocity
                vel = vel / maxvel;      %abitrary normalization since velocity range is not known.
                if (vel > 1)
                    vel = 1;
                end
                R = vel * 10;        %multiply by 10 since fit coefficients are based on a max intensity scaled up to 10
            case 'SA1'
                force = contactforce(region);
                % Normalize contact force
                force = force / maxforce;      %abitrary normalization since contact force range is not known.
                if (force > 1)
                    force = 1;
                end
                R = force * 10;        %multiply by 10 since fit coefficients are based on a max intensity scaled up to 10
            case 'RA2'
                acc = acceleration(region);
                % Normalize Acceleration
                acc = acc / maxacc;      %abitrary normalization since acceleration range is not known.
                if (acc > 1)
                    acc = 1;
                end
                R = acc * 10;        %multiply by 10 since fit coefficients are based on a max intensity scaled up to 10
        end
        a = channelFreq(1,channel(ii));
        b = channelFreq(2,channel(ii));
        switch recpt
            case 'SA1'
            	% Shifted logrithmic fit
                S = exp( (R - a)./b );
            case{'RA1','RA2'}
                % Logrithmic fit
                c = channelFreq(3,channel(ii));
                S = exp( (R - a)./b ) + c;
        end
        freq(1,ii) = S;
    end
%------------- END OF CODE --------------
end