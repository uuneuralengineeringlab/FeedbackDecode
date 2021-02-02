function TASKAInfo = readTASKAData(fname)
% use this to read DEKA sensor and motor values

% SS.DEKASensorLabels = {'index_medial';'index_distal';'middle_distal';'ring_distal';...
%     'pinky_distal';'palm_pinky';'palm_thumb';'palm_side';'palm_back';...
%     'thumb_ulnar';'thumb_medial';'thumb_distal';'thumbdorsal'};
% 
% SS.DEKAMotorLabels = {'wrist_PRO';'wrist_FLEX';'index_MCP';'middle_MCP';...
%     'thumbraw_ABD';'thumbraw_MCP';'thumb_MCP';'thumb_ABD'}; % Remove raw? dk


fid = fopen(fname);
HeaderLength = fread(fid,1,'single');
Header = fread(fid,[HeaderLength/2,2],'single');
Data = fread(fid,[sum(prod(Header,2)),Inf],'single');
fclose(fid);

TASKAInfo.NIPTime = [];
TASKAInfo.Ready = [];
TASKAInfo.Motors = [];
TASKAInfo.IR = [];
TASKAInfo.Baro = [];
TASKAInfo.IRraw = [];
TASKAInfo.Baroraw = [];
TASKAInfo.ShareReady = [];
TASKAInfo.Beta = [];
TASKAInfo = repmat(TASKAInfo,1,size(Data,2));

cs = cumsum(prod(Header,2));
idx = [[1;cs(1:end-1)+1],cs];
dl = size(Data,1);
for k=1:size(Data,2)
    if ~rem(k,10)
        clc; disp(num2str(k/size(Data,2)*100,'%0.0f'));
    end
    TASKAInfo(k).NIPTime = reshape(Data((idx(1,1):idx(1,2))+(k-1)*dl),Header(1,:));
    TASKAInfo(k).Ready = reshape(Data((idx(2,1):idx(2,2))+(k-1)*dl),Header(2,:));
    TASKAInfo(k).Motors = reshape(Data((idx(3,1):idx(3,2))+(k-1)*dl),Header(3,:));
    TASKAInfo(k).IR = reshape(Data((idx(4,1):idx(4,2))+(k-1)*dl),Header(4,:));
    TASKAInfo(k).Baro = reshape(Data((idx(5,1):idx(5,2))+(k-1)*dl),Header(5,:));
    TASKAInfo(k).IRraw = reshape(Data((idx(6,1):idx(6,2))+(k-1)*dl),Header(6,:));
    TASKAInfo(k).Baroraw = reshape(Data((idx(7,1):idx(7,2))+(k-1)*dl),Header(7,:));
    TASKAInfo(k).ShareReady = reshape(Data((idx(8,1):idx(8,2))+(k-1)*dl),Header(8,:));
    TASKAInfo(k).Beta = reshape(Data((idx(9,1):idx(9,2))+(k-1)*dl),Header(9,:));
end
b = 0;
