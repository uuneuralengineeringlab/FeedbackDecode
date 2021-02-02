function [shimmer3, SensorMacros] = imuconnect()

compName = getenv('computername');
switch compName
    case 'PNIMATLAB'
         comPorts = {'20', '20' '18','12'}; % 22: B0A3, 20: C7C1, 12: 6C61, 18: 49C6 (most reliable)
%        ecgPorts = {'18'}; % 22: B0A3, 21: C7C1, 12: 6C61, 18: 49C6 (most reliable)
    case 'BIOEN-LAPTOP'
        comPorts = {'10'}; % 10: 6C61, need to pair 49C6 and add COM port
    % case ~~new lab laptop~~
    otherwise
        fprintf('IMU COM Port not set for this computer')
end %switch


comPortIdx = 1;
imuConnected = 0;
while ~imuConnected && (comPortIdx <= length(comPorts))
    attempts = 10;
    while attempts && ~imuConnected
        fprintf('%d attempt(s) remaining on COM %s\n', attempts, comPorts{comPortIdx})
        shimmer3 = ShimmerHandleClass_changeDirectory(comPorts{comPortIdx});                       % setting shimmer3 to ComPort 14. Change for whichever Comport is being used by shimmer device
        imuConnected = shimmer3.connect; % initiating shimmer connection. 0 = unable to connected. 1 = connected     
        attempts = attempts - 1;
    end
    if ~imuConnected
        comPortIdx = comPortIdx + 1;
    end
end

if imuConnected                                                      % TRUE if the shimmer connects
    % define settings for shimmer
    SensorMacros = SetEnabledSensorsMacrosClass;                               % enabling sensors
    fs = 33;                                                                  % sample rate in [Hz]  
    shimmer3.setsamplingrate(fs);                                          % set the shimmer sampling rate
    shimmer3.setinternalboard('9DOF');                                      % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
    shimmer3.disableallsensors;                                            % Disable other sensors
    shimmer3.setenabledsensors(SensorMacros.GYRO,1,SensorMacros.MAG,1,...   % Enable the gyroscope, magnetometer and accelerometer.
    SensorMacros.ACCEL,1);
    shimmer3.setaccelrange(0);                                              % Set the accelerometer range to 0 (+/- 1.5g for Shimmer2/2r, +/- 2.0g for Shimmer3)
    shimmer3.setgyroinusecalibration(1);

    fprintf('Shimmer IMU connected via bluetooth to %s on COM port %d\n', compName, str2double(comPorts{comPortIdx}));

else 
    fprintf('Shimmer unable to connect via bluetooth to %s via COM port(s) ', compName);
    fprintf('%s ',comPorts{:})
    fprintf('\n\n')
    if strcmp('PNIMATLAB',compName)
        fprintf('Make sure "TechKey" bluetooth dongle is connected to second USB port from top on front of PNIMATLAB\n\n');
    end
    shimmer3 = 0;
    SensorMacros = 0;
end 

