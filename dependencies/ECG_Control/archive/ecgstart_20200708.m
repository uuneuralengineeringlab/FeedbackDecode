function realTime_1 = ecgstart(shimmer3)

format long

% isStarted = shimmer3.startdatalogandstream;                                % starting SD Log and Stream of ECG data
isStarted = shimmer3.startloggingonly;                                % starting SD Log and Stream of ECG data

if isStarted == 1
    
    realTime_1 = posixtime(datetime('now', 'TimeZone', 'local'));              % taking current time stamp
    disp('Shimmer Recording Started')  
    
else
    
    warning('Shimmer Unable to Start Recording') 
    
end 

