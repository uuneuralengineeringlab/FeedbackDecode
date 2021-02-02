function [VREInfo,VRECommand] = readVREData(fname)
% use this to read VRE command log from pre 4/2016

fid = fopen(fname);
HeaderLength = fread(fid,1,'single');
Header = fread(fid,[HeaderLength/2,2],'single');
Data = fread(fid,[sum(prod(Header,2)),Inf],'single');
fclose(fid);

VREInfo.sensors = struct('time_stamp',[],'motor_pos',[],'motor_vel',[],'motor_torque',[],'joint_pos',[],'joint_vel',[],'contact',[],'imu_linear_acc',[],'imu_angular_vel',[],'imu_orientation',[]);
VREInfo.state = struct('nq',[],'nv',[],'na',[],'time',[],'qpos',[],'qvel',[],'act',[]);
VREInfo = repmat(VREInfo,1,size(Data,2));
VRECommand = repmat(struct('nu',[],'time',[],'ctrl',[]),1,size(Data,2));

cs = cumsum(prod(Header,2));
idx = [[1;cs(1:end-1)+1],cs];
dl = size(Data,1);
for k=1:size(Data,2)
    if ~rem(k,10)
        clc; disp(num2str(k/size(Data,2)*100,'%0.0f'));
    end
    VREInfo(k).sensors.time_stamp = reshape(Data((idx(1,1):idx(1,2))+(k-1)*dl),Header(1,:));
    VREInfo(k).sensors.motor_pos = reshape(Data((idx(2,1):idx(2,2))+(k-1)*dl),Header(2,:));
    VREInfo(k).sensors.motor_vel = reshape(Data((idx(3,1):idx(3,2))+(k-1)*dl),Header(3,:));
    VREInfo(k).sensors.motor_torque = reshape(Data((idx(4,1):idx(4,2))+(k-1)*dl),Header(4,:));
    VREInfo(k).sensors.joint_pos = reshape(Data((idx(5,1):idx(5,2))+(k-1)*dl),Header(5,:));
    VREInfo(k).sensors.joint_vel = reshape(Data((idx(6,1):idx(6,2))+(k-1)*dl),Header(6,:));
    VREInfo(k).sensors.contact = reshape(Data((idx(7,1):idx(7,2))+(k-1)*dl),Header(7,:));
    VREInfo(k).sensors.imu_linear_acc = reshape(Data((idx(8,1):idx(8,2))+(k-1)*dl),Header(8,:));
    VREInfo(k).sensors.imu_angular_vel = reshape(Data((idx(9,1):idx(9,2))+(k-1)*dl),Header(9,:));
    VREInfo(k).sensors.imu_orientation = reshape(Data((idx(10,1):idx(10,2))+(k-1)*dl),Header(10,:));
    
    VREInfo(k).state.nq = reshape(Data((idx(11,1):idx(11,2))+(k-1)*dl),Header(11,:));
    VREInfo(k).state.nv = reshape(Data((idx(12,1):idx(12,2))+(k-1)*dl),Header(12,:));
    VREInfo(k).state.na = reshape(Data((idx(13,1):idx(13,2))+(k-1)*dl),Header(13,:));
    VREInfo(k).state.time = reshape(Data((idx(14,1):idx(14,2))+(k-1)*dl),Header(14,:));
    VREInfo(k).state.qpos = reshape(Data((idx(15,1):idx(15,2))+(k-1)*dl),Header(15,:));
    VREInfo(k).state.qvel = reshape(Data((idx(16,1):idx(16,2))+(k-1)*dl),Header(16,:));
    VREInfo(k).state.act = reshape(Data((idx(17,1):idx(17,2))+(k-1)*dl),Header(17,:));
    
    VREInfo(k).mocap.nmocap = reshape(Data((idx(18,1):idx(18,2))+(k-1)*dl),Header(18,:));
    VREInfo(k).mocap.time = reshape(Data((idx(19,1):idx(19,2))+(k-1)*dl),Header(19,:));
    VREInfo(k).mocap.pos = reshape(Data((idx(20,1):idx(20,2))+(k-1)*dl),Header(20,:));
    VREInfo(k).mocap.quat = reshape(Data((idx(21,1):idx(21,2))+(k-1)*dl),Header(21,:));
    
    VRECommand(k).nu = reshape(Data((idx(22,1):idx(22,2))+(k-1)*dl),Header(22,:));
    VRECommand(k).time = reshape(Data((idx(23,1):idx(23,2))+(k-1)*dl),Header(23,:));
    VRECommand(k).ctrl = reshape(Data((idx(24,1):idx(24,2))+(k-1)*dl),Header(24,:));    
    
end

