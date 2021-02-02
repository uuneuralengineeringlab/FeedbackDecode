path = '\\pnilabview\PNILabview_R6\Data\P201601\20160817-105205\VREData_Bakeoff11_20160817-105205_110048.vre';
%
data = readVRE(path);
sensors = [data.sensors];
times = [sensors.nip_time];
contactvalues = [sensors.contact];
index = contactvalues([7 9 10 11],:);
times_s = times / 30e3;
plot(times_s,index,'LineWidth',1);
xlabel('Time (seconds)');
ylabel('Force (newtons)');
set(findall(gcf,'-property','FontSize'),'FontSize',24)