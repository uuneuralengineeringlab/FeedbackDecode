%%
SS.BaseLoopTime = 0.033;
SS.StimChan = [1;2];
SS.ContStimAmp = [10;20]; %amplitude in uA
SS.ContStimFreq = [100;100]; %frequency in Hz
SS.StimDur = [0.2;0.2];

SS.StimCmd.elec = 1;
SS.StimCmd.period = 0; %# nip cycles between pulses
SS.StimCmd.repeats = 0; %# times to repeat pulse. Fixed at 20 since 500Hz only has ~16 pulses in a 33ms loop time. Max frequency should be 500Hz!
SS.StimCmd.action = 'curcyc';
SS.StimCmd.seq(1) = struct('length',6,'ampl',0,'pol',0,'fs',0,'enable',1,'delay',0,'ampSelect',1); %first phase of biphasic pulse
SS.StimCmd.seq(2) = struct('length',3,'ampl',0,'pol',0,'fs',0,'enable',0,'delay',0,'ampSelect',1); %interphase interval
SS.StimCmd.seq(3) = struct('length',6,'ampl',0,'pol',1,'fs',0,'enable',1,'delay',0,'ampSelect',1); %second phase of biphasic pulse

SS.NextPulse = zeros(100,1); %holds next pulse time for each stim channel
SS.CurrTime = xippmex_20170220('time');
SS.CalcTime = zeros(300,1);

%%
for m=1:300 %go for 10sec
    t = tic;
    SS.StimSeq = repmat(SS.StimCmd,1,numel(SS.StimChan));
    SS.StimIdx = false(1,numel(SS.StimChan));
    SS.CurrTime = xippmex_20170220('time');
    for k=1:length(SS.StimChan)
        StimSteps = floor(SS.ContStimAmp(k)); %number of stim steps based on stepsize of 1uA
        CSF = SS.ContStimFreq(k);
        CSF(CSF<0) = 0;
        CSF(CSF>0 && CSF<5) = 5; %constraint to prevent low frequencies which have a slow ramp up time
        CSF(CSF>500) = 500;
        StimSteps(StimSteps<0) = 0;
        StimSteps(StimSteps>100) = 100;
        if  CSF>0
            NextPulseDiff = max(floor(SS.NextPulse(SS.StimChan(k))-SS.CurrTime),1);%The number of 33.33 us samples between the current time and the current stim pulse that should be executed in this loop on this electrode.
            if NextPulseDiff<floor(SS.BaseLoopTime*30000) %if the current pulse should happen within the current loop, then schedule it.
                SS.StimSeq(k).elec = SS.StimChan(k);
                SS.StimSeq(k).period = floor(30000./CSF); %period is in # of 33 us samples between successive start times of successive pulses. Was set to NextPulseDiff, but changed to frequency.
                SS.StimSeq(k).repeats = ceil(SS.BaseLoopTime*CSF);
                if NextPulseDiff==1 && CSF<(1/SS.BaseLoopTime)
                    SS.StimSeq(k).action = 'immed';
                else
                    SS.StimSeq(k).action = 'curcyc';
                end
                SS.StimSeq(k).seq(1).length = floor(SS.StimDur(k)*30);
                SS.StimSeq(k).seq(1).ampl = StimSteps;
                SS.StimSeq(k).seq(3).length = floor(SS.StimDur(k)*30);
                SS.StimSeq(k).seq(3).ampl = StimSteps;
                SS.NextPulse(SS.StimChan(k)) = SS.CurrTime + NextPulseDiff + floor(30000/CSF); %The NIP time (in number of 33.333 us cycles since boot-up) at which next stim pulse should be delivered (not the current,but the next)
                SS.StimIdx(k) = true;
            end
        end
    end %end for 
    if any(SS.StimIdx)
        xippmex_20170220('stimseq',SS.StimSeq(SS.StimIdx));
    end  
    SS.CalcTime(m) = toc(t);
    pause(SS.BaseLoopTime);
end %end while

%%
xippmex_20170220('close'); 
clear('xippmex_20170220');

figure;
plot(SS.CalcTime)
ylim([0,0.01])