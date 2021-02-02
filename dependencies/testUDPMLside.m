%%
MLIP = '155.100.91.231';
LVIP = '155.100.90.215';

udpObj = udp(LVIP,9002,'localhost',MLIP,'localport',9002);

%%
fopen(udpObj);


%%
fscanf(udpObj,'hello');