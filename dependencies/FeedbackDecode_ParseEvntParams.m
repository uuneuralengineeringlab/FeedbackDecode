function TrialStruct = FeedbackDecode_ParseEvntParams(EvntFile)

% Version Date: 20170901
% Author: Tyler Davis

if exist(EvntFile,'file')
    fid = fopen(EvntFile);
    EvntData = fread(fid,[1,Inf],'*char');
    fclose(fid);
    
    StructFields = regexp(EvntData,'SS\.([A-Za-z\.\d]+)=','tokens'); StructFields = unique([StructFields{:}]);
    clear TS
    TS.ID = [];
    for k=1:length(StructFields)
        SF = regexp(StructFields{k},'\.','split');
        if length(SF)==1
            TS.(SF{1}) = [];
        else
            TS.(SF{1}).(SF{2}) = [];
        end
    end
    
    EvntData = regexp(EvntData,'\r\n','split')'; EvntData(end) = [];
    TrialStruct = repmat(TS,length(EvntData),1);
    for k=1:length(EvntData)
        evntdata = regexp(EvntData{k},':','split','once');
        clear SS
        SS = TS;
        SS.ID = evntdata{1};
        eval(evntdata{2})   
        %(NIPTime(2)-NIPTime(1))/100 = milliseconds (maybe)
%         if isfield(SS,'NIPTime')
%             SS.NIPTime = typecast(uint64(SS.NIPTime),'double'); %converting to datenum (use datevec to see full date and time)            
%         end
        TrialStruct(k) = SS;
    end
end
