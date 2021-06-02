function [shimmers, SensorMacros, ready] = imuconnect(varargin)
%% Varargin{1} sets number of IMUs to connect
if length(varargin)==1
    numIMUs = varargin{1};
else
    numIMUs = 1;
end

%% Which COM ports to try
compName = getenv('computername');
switch compName
    case 'PNIMATLAB'
         comPorts = {'13', '19','21'}; % 22: B0A3, 20: C7C1, 12: 6C61, 18: 49C6 (most reliable)
%        ecgPorts = {'18'}; % 22: B0A3, 21: C7C1, 12: 6C61, 18: 49C6 (most reliable)
    case 'BIOEN-LAPTOP'
        comPorts = {'10'}; % 10: 6C61, need to pair 49C6 and add COM port
    % case ~~new lab laptop~~
    otherwise
        fprintf('IMU COM Port not set for this computer')
end %switch

%% Attempt to connect
comPortIdx = 1;
connectedCOMs = {};
imuConnected = 0;
shimmers = {};
while imuConnected < numIMUs && (comPortIdx <= length(comPorts))
    attempts = 10;
    thisCOM = 0;
    while attempts && ~thisCOM
        fprintf('%d attempt(s) remaining on COM %s\n', attempts, comPorts{comPortIdx})
        shimmer3 = ShimmerHandleClass_changeDirectory(comPorts{comPortIdx}); % setting shimmer3 to ComPort X. Change for whichever Comport is being used by shimmer device
        if shimmer3.connect % initiating shimmer connection. 0 = unable to connected. 1 = connected     
            connectedCOMs = [connectedCOMs comPorts{comPortIdx}];
            thisCOM = 1;
            imuConnected = imuConnected + 1;
            shimmers = [shimmers shimmer3];
            
        end
        attempts = attempts - 1;
    end
    
    comPortIdx = comPortIdx + 1;
    
end

% while ~imuConnected && (comPortIdx <= length(comPorts))
%     attempts = 10;
%     while attempts && ~imuConnected
%         fprintf('%d attempt(s) remaining on COM %s\n', attempts, comPorts{comPortIdx})
%         shimmer3 = ShimmerHandleClass_changeDirectory(comPorts{comPortIdx});                       % setting shimmer3 to ComPort 14. Change for whichever Comport is being used by shimmer device
%         imuConnected = shimmer3.connect; % initiating shimmer connection. 0 = unable to connected. 1 = connected     
%         attempts = attempts - 1;
%     end
%     if ~imuConnected
%         comPortIdx = comPortIdx + 1;
%     end
% end

%% Set parameters
if imuConnected% TRUE if the shimmer connects
    ready = 1;
    for i=1:imuConnected
        % define settings for shimmer
        SensorMacros = SetEnabledSensorsMacrosClass;                               % enabling sensors
        fs = 256;                                                                  % sample rate in [Hz]  
        shimmers(i).setsamplingrate(fs);                                          % set the shimmer sampling rate
        shimmers(i).setinternalboard('9DOF');                                      % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
        shimmers(i).disableallsensors;                                            % Disable other sensors
        shimmers(i).setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
        SensorMacros.ACCEL,1);
        shimmers(i).setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
        shimmers(i).setgyroinusecalibration(1);

        fprintf('Shimmer IMU connected via bluetooth to %s on COM port %d\n', compName, str2double(connectedCOMs{i}));
    end
        
%                 % define settings for shimmer
%         SensorMacros = SetEnabledSensorsMacrosClass;                               % enabling sensors
%         fs = 33;                                                                  % sample rate in [Hz]  
%         shimmer3.setsamplingrate(fs);                                          % set the shimmer sampling rate
%         shimmer3.setinternalboard('9DOF');                                      % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
%         shimmer3.disableallsensors;                                            % Disable other sensors
%         shimmer3.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
%         SensorMacros.ACCEL,1);
%         shimmer3.setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
%         shimmer3.setgyroinusecalibration(1);
% 
%         fprintf('Shimmer IMU connected via bluetooth to %s on COM port %d\n', compName, str2double(comPorts{comPortIdx}));
% 

else 
    fprintf('Shimmer unable to connect via bluetooth to %s via COM port(s) ', compName);
    fprintf('%s ',comPorts{:})
    fprintf('\n\n')
    if strcmp('PNIMATLAB',compName)
        fprintf('Make sure "TechKey" bluetooth dongle is connected to second USB port from top on front of PNIMATLAB\n\n');
    end
    shimmers = 0;
    SensorMacros = 0;
    ready = 0;
end 

