VT = VTStim;
%%
tic
for ind=1:6
    for pwm= 0:5:255
        tic
        cmd = zeros(6,1);
        cmd(ind) = pwm;
        VT.write(cmd);
%         pause(0.02)
        toc
    end
end