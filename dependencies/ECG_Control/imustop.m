function shimmerunix_ms = imustop(shimmer3)

isStopped = 0;
attempts = 10;
while ~isStopped && attempts
    pause(0.0005)
    isStopped = shimmer3.stop;
    shimmerunix_ms = shimmerUnixTimeConversion_ms();
    attempts = attempts - 1;
end

if isStopped == 1
    disp('Shimmer IMU Recording Stopped')  
else
    disp('Shimmer IMU recording not stopped correctly')
end 

