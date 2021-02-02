function [shimmer3 SensorMacros] = ecgconnect()

compName = getenv('computername');
switch compName
    case 'PNIMATLAB'
        ecgport = {'12','18'}; % 12 18: 
    case 'BIOEN-LAPTOP'
        ecgport = '10';
    otherwise
        warning('ECG COM Port not set for this computer')
end %switch

ecgStartRecordTS = ecgstart(shimmerECG);

shimmer3 = ShimmerHandleClass_changeDirectory(port);                       % setting shimmer3 to ComPort 14. Change for whichever Comport is being used by shimmer device
SensorMacros = SetEnabledSensorsMacrosClass;                               % enabling sensors 
fs = 512;                                                                  % sample rate in [Hz]  

isConnected = shimmer3.connect;                                            % initiating shimmer connection. 0 = unable to connected. 1 = connected     

if isConnected                                                      % TRUE if the shimmer connects
    
    % define settings for shimmer
    shimmer3.setsamplingrate(fs);                                          % set the shimmer sampling rate
    shimmer3.setinternalboard('ECG');                                      % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
    shimmer3.disableallsensors;                                            % Disable other sensors
    shimmer3.setenabledsensors(SensorMacros.ECG,1)    

    disp('Shimmer Connected via Bluetooth')

else 
    
    warning('Shimmer Unable to Connect')
    shimmer3 = 0;
    SensorMacros = 0;
    
end 