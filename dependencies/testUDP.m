%%
SS.LabviewIP = '155.100.90.215';
SS.MatlabIP = '155.100.91.231';
SS.UDPEvnt = udp(SS.LabviewIP,9002,'localhost',SS.MatlabIP,'localport',9002);
SS.UDPEvnt.InputBufferSize = 65535; SS.UDPEvnt.InputDatagramPacketSize = 13107; SS.UDPEvnt.OutputBufferSize = 65535; SS.UDPEvnt.OutputDatagramPacketSize = 13107;
fopen(SS.UDPEvnt);
disp('opened')

%%
a = repmat('a',1,10000);
fwrite(SS.UDPEvnt,a);
disp(['write ' num2str(length(a))])

%%
a = fscanf(SS.UDPEvnt);
disp(length(a))

%%
fclose(SS.UDPEvnt);
disp('closed')