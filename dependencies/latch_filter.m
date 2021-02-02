function [xhat_out,neutral] = latch_filter(xhat,neutral,LF_C,velIdxs)
change = (xhat-neutral);
change = LF_C*(change).^2;
change(change>1) = 1;

xhat_out = neutral+change.*(xhat-neutral);%temp.*xhat+(1-temp).*neutral;
xhat_out(velIdxs) = xhat(velIdxs); % overwrite the LF for velIdxs ('Latching' in Labveiw)
xhat_out(xhat_out>1) = 1;
xhat_out(xhat_out<-1) = -1;
neutral = xhat_out;
end