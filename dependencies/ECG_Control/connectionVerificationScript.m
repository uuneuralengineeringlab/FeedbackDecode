[shimmer3, SensorMacros] = ecgconnect();
shimmerunix_ms = ecgstart(shimmer3);
shimmerunix_ms = ecgstop(shimmer3);
pause(0.1)
[isDisconnected] = ecgdisconnect(shimmer3);