function shimmerunix_ms = ecgstop(shimmer3)

isStopped = 0;
attempts = 10;
while ~isStopped && attempts
    pause(0.0005)
    isStopped = shimmer3.stoploggingonly;
    shimmerunix_ms = shimmerUnixTimeConversion_ms();
    attempts = attempts - 1;
end

if isStopped == 1
    disp('Shimmer Recording Stopped')  
else
    disp('Shimmer recording not stopped correctly')
end 

