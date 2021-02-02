function realTime_2 = ecgstop(shimmer3)

isStopped = shimmer3.stoploggingonly;                                 % stopping SD Log and Stream

if isStopped == 1
    
    realTime_2 = posixtime(datetime('now', 'TimeZone', 'local'));              % taking current time stamp 
    disp('Shimmer Recording Stopped')  
    
end 

