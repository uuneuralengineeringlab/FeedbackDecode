% use this script when matlab fails to receive or execute LV shutdown command
% first, kill running FeedbackDecoe.m, then run this script so LV can shut down properly. 
% be sure to kill any FeedbackDecodeAux from the task manager
% smw 12/2016
SS.LabviewIP = '155.100.90.215';

[~,netstr] = system('powershell ipconfig');
stroffset = regexp(netstr,'Matlab_Network');
SS.LocalIP = regexp(netstr(stroffset:end),'\d+\.\d+\.\d+\.\d+','match'); SS.LocalIP = SS.LocalIP{1};

SS.UDPEvnt = udp(SS.LabviewIP,9002,'localhost',SS.LocalIP,'localport',9002); %Sending/receiving string commands
SS.UDPEvnt.InputBufferSize = 65535; SS.UDPEvnt.InputDatagramPacketSize = 13107; SS.UDPEvnt.OutputBufferSize = 65535; SS.UDPEvnt.OutputDatagramPacketSize = 13107;

SS.UDPCont = udp(SS.LabviewIP,9005,'localhost',SS.LocalIP,'localport',9005); %Sending/receiving continuous
SS.UDPCont.InputBufferSize = 65535; SS.UDPCont.InputDatagramPacketSize = 13107; SS.UDPCont.OutputBufferSize = 65535; SS.UDPCont.OutputDatagramPacketSize = 13107;

fopen(SS.UDPEvnt);
fopen(SS.UDPCont);
fwrite(SS.UDPEvnt,'MatlabReady'); %Tell LV that matlab has shut down

fclose(SS.UDPEvnt);
fclose(SS.UDPCont); 
delete(SS.UDPEvnt); 
delete(SS.UDPCont);

delete(instrfindall); delete(timerfindall);

clear all; close all; fclose all;
