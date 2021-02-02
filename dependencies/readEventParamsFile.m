function [TrialStruct,EventStruct] = readEventParamsFile(EParamsFile)
% reads EventParams_*.txt from p201601
% smw, TD  3/2017

fid = fopen(EParamsFile);
EParamsCell = textscan(fid,'%s','delimiter','\n\r'); EParamsCell = EParamsCell{:};
fclose(fid);

TParamsCellIdx = ~cellfun(@isempty,regexp(EParamsCell,'^TrialParameters|^TargOn|^InTarg|^OutTarg|^Success|^Failure'));
TParamsCell = EParamsCell(TParamsCellIdx);
EParamsCell(TParamsCellIdx) = [];

TrialParamsIdx = find(~cellfun(@isempty,regexp(TParamsCell,'^TrialParameters')));
TrialParamsIdxMat = [[1;TrialParamsIdx(1:end-1)+1],TrialParamsIdx-1];
TrialParams = TParamsCell(TrialParamsIdx);
TrialParams = regexp(TrialParams,'TrialParameters:','split');
eval(TrialParams{1}{2});
TrialStruct = [];
FieldNames = sort(fieldnames(SS));
for k = 1:length(FieldNames)
    TrialStruct.(FieldNames{k}) = [];
end

TSNames = {'TrialTS';'TargOnTS';'InTargTS';'OutTargTS';'SuccessTS';'FailureTS'};
TrialStruct = repmat(cell2struct([repmat({[]},size(FieldNames,1)+size(TSNames,1),1);{false}],[FieldNames;TSNames;{'TrainingOn'}]),size(TrialParams,1),1);
for k=1:length(TrialStruct)
    clear('SS')
    eval(TrialParams{k}{2});
    SS = orderfields(SS);
    SS.TrialTS = [];
    SS.TargOnTS = [];
    SS.InTargTS = [];
    SS.OutTargTS = [];
    SS.SuccessTS = [];
    SS.FailureTS = [];
    SS.TrainingOn = false;
    TrialStruct(k) = SS;
end

% DData = regexp(char(NEV.Data.SerialDigitalIO.UnparsedData),'*','split'); DData = DData(2:end);
% DDataTS = NEV.Data.SerialDigitalIO.TimeStamp(regexp(char(NEV.Data.SerialDigitalIO.UnparsedData),'*'));
% DDataTS = DDataTS(cellfun(@isempty,regexp(DData,'^\d+')))';
% DData = DData(cellfun(@isempty,regexp(DData,'^\d+')))';

for k = 1:size(TrialParamsIdxMat,1)
    TrialMarkers = TParamsCell(TrialParamsIdxMat(k,1):TrialParamsIdxMat(k,2));
    TrialStruct(k).TrialTS = TrialStruct(k).NIPTime;
    TM = regexp(TrialMarkers(~cellfun(@isempty,regexp(TrialMarkers,'^TargOn'))),':','split');
    if ~isempty(TM); clear('SS'); eval(TM{1}{2}); TrialStruct(k).TargOnTS = SS.NIPTime; end 
    TM = regexp(TrialMarkers(~cellfun(@isempty,regexp(TrialMarkers,'^InTarg'))),':','split'); 
    for m = 1:length(TM)  % smw
         if ~isempty(TM{m}); clear('SS'); eval(TM{m}{2}); TrialStruct(k).InTargTS{m} = SS.NIPTime; end
    end
%     if ~isempty(TM); clear('SS'); eval(TM{1}{2}); TrialStruct(k).InTargTS = SS.NIPTime; end
    TM = regexp(TrialMarkers(~cellfun(@isempty,regexp(TrialMarkers,'^OutTarg'))),':','split'); 
    for m = 1:length(TM) % smw
         if ~isempty(TM{m}); clear('SS'); eval(TM{m}{2}); TrialStruct(k).OutTargTS{m} = SS.NIPTime; end
    end
%     if ~isempty(TM); clear('SS'); eval(TM{1}{2}); TrialStruct(k).OutTargTS = SS.NIPTime; end
    TM = regexp(TrialMarkers(~cellfun(@isempty,regexp(TrialMarkers,'^Success'))),':','split');
    if ~isempty(TM); clear('SS'); eval(TM{1}{2}); TrialStruct(k).SuccessTS = SS.NIPTime; end
    TM = regexp(TrialMarkers(~cellfun(@isempty,regexp(TrialMarkers,'^Failure'))),':','split');
    if ~isempty(TM); clear('SS'); eval(TM{1}{2}); TrialStruct(k).FailureTS = SS.NIPTime; end
    if strcmp(TrialStruct(k).KinematicSrc,'Training')
        TrialStruct(k).TrainingOn = true;
    end
end

EventParams = regexp(EParamsCell,':','split'); EventParams = cat(1,EventParams{:});
[uEventParams,~,uEventIdxs] = unique(EventParams(:,1));
EventStruct = [];
for k=1:length(uEventParams)
    EventStruct.(uEventParams{k}) = [];    
    EP = EventParams(uEventIdxs==k,2);
    for m=1:length(EP)
        clear('SS');
        eval(EP{m})
        EventStruct.(uEventParams{k}) = [EventStruct.(uEventParams{k});SS];
    end    
end









% fid = fopen(fname);
% events = regexp(fscanf(fid,'%c'),'\r\n','split')';
% 
% eventStruct = repmat(struct('EventType',[], 'EventSS', []), 1, length(events)-1);
% % parse trial info
% for k = 1:length(events)-1
%     a = regexp(events{k},':','split')';
%    eventStruct(k).EventType =  a{1};
%    eval(a{2});
%    eventStruct(k).EventSS = SS;
% end
% 
% % parse out trial info
% 
% for k = 1:length(eventStruct)
% end
% varargout = TrialStruct;
% 
% % TrialStruct = repmat(struct('NIPTime', [], 'TrainingTF',[],'TargOnTS',[],'TrialTS',[],'MvntMat',[], 'SuccessTF', []),1,size(TrialParams,1));
% % for k=1:length(TrialParams)
% %     SS = struct('TargOnTS',[],'TrialTS',[],'MvntMat',[]);
% %     eval(TrialParams{k});
% %     TrialStruct(k) = SS;
% %     
% %     KINSource
% % end
% % idx = cellfun(@isempty,{TrialStruct.TargOnTS}) | cellfun(@isempty,{TrialStruct.TrialTS}) | cellfun(@isempty,{TrialStruct.MvntMat});
% % TrialStruct(idx) = [];
% 
% fclose(fid)
% 
