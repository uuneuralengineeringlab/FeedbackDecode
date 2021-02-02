function shimmerunix_ms = ecgstart(shimmer3)

isStarted = 0;
attempts = 10;
while ~isStarted && attempts
    pause(0.0005)
    isStarted = shimmer3.startloggingonly;
    shimmerunix_ms = shimmerUnixTimeConversion_ms();
    attempts = attempts - 1;
end

if isStarted
    disp('Shimmer Recording Started')  
else
    warning('Shimmer Unable to Start Recording') 
end 
