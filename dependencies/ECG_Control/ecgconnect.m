function [shimmer3, SensorMacros] = ecgconnect()

compName = getenv('computername');
switch compName
    case 'PNIMATLAB'
        ecgPorts = {'18','12'}; % 18: 49C6 (most reliable), 12: 6C61
    case 'BIOEN-LAPTOP'
        ecgPorts = {'10'}; % 10: 6C61, need to pair 49C6 and add COM port
    case 'PNILABVIEW'
        ecgPorts = {'3'}; % 3: 49C6 (most reliable)
    % case ~~new lab laptop~~
    otherwise
        fprintf('ECG COM Port not set for this computer')
end %switch


ecgPortIdx = 1;
ecgConnected = 0;
while ~ecgConnected && (ecgPortIdx <= length(ecgPorts))
    attempts = 10;
    while attempts && ~ecgConnected
        fprintf('%d attempt(s) remaining on COM %s\n', attempts, ecgPorts{ecgPortIdx})
        shimmer3 = ShimmerHandleClass_changeDirectory(ecgPorts{ecgPortIdx});                       % setting shimmer3 to ComPort 14. Change for whichever Comport is being used by shimmer device
        ecgConnected = shimmer3.connect; % initiating shimmer connection. 0 = unable to connected. 1 = connected     
        attempts = attempts - 1;
    end
    if ~ecgConnected
        ecgPortIdx = ecgPortIdx + 1;
    end
end

if ecgConnected                                                      % TRUE if the shimmer connects
    % define settings for shimmer
    SensorMacros = SetEnabledSensorsMacrosClass;                               % enabling sensors
    fs = 512;                                                                  % sample rate in [Hz]  
    shimmer3.setsamplingrate(fs);                                          % set the shimmer sampling rate
    shimmer3.setinternalboard('ECG');                                      % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
    shimmer3.disableallsensors;                                            % Disable other sensors
    shimmer3.setenabledsensors(SensorMacros.ECG,1);    

    fprintf('Shimmer ECG connected via bluetooth to %s on COM port %d\n', compName, str2double(ecgPorts{ecgPortIdx}));

else 
    fprintf('Shimmer unable to connect via bluetooth to %s via COM port(s) ', compName);
    fprintf('%s ',ecgPorts{:})
    fprintf('\n\n')
    if strcmp('PNIMATLAB',compName)
        fprintf('Make sure "TechKey" bluetooth dongle is connected to second USB port from top on front of PNIMATLAB\n\n');
    end
    shimmer3 = 0;
    SensorMacros = 0;
end 

