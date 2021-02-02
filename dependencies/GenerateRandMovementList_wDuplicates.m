function [outfile, MovementStruct]  = GenerateRandMovementList_wDuplicates(outfile, NumTrials, DOF, FlexFlag, ComboList, EndptList, DelayList,  VelocityList, HoldTimeList)
% flexFlag: 0 = ext only, 1= flex only, 2 = flex and extend

%%
if FlexFlag == 1 || FlexFlag == 0
    TrialMult = 1;
elseif FlexFlag ==2;
    TrialMult = 2;
end
%%
% init base movmenet struct
count = 0;
for j = 1:length(DOF)
    switch DOF(j)
        case 1
            mvtname = 'ThumbFE';
        case 2
            mvtname = 'IndexFE';
        case 3
            mvtname = 'MiddleFE';
        case 4
            mvtname = 'RingFE';
        case 5
            mvtname = 'LittleFE';
        case 6
            mvtname = 'ThumbInt';
        case 7
            mvtname = 'IndexInt';
        case 8
            mvtname = 'RingInt';
        case 9
            mvtname = 'LittleInt';
        case 10
            mvtname = 'WristFE';
        case 11
            mvtname = 'WristDev';
        case 12
            mvtname = 'WristPS';
    end
    
    for k = 1:NumTrials*TrialMult
        count = count + 1;
        B{count}.mvtname = mvtname;
        B{count}.tracking = TrackingFlag;
        B{count}.mvtmat = zeros(12, 4);
        switch FlexFlag
            
            case 0 % extension only
                B{count}.mvtmat(DOF(j),:) = [-1*(Endpt+RandomizeEndpt*rand(1)),...
                    (mDelay + RandomizeDelay*RandomizeSpan*rand(1)), ...
                    (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                    (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))];
            case 1 % flexion only
                B{count}.mvtmat(DOF(j),:) = [(Endpt+RandomizeEndpt*rand(1)),...
                    (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                    (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                    (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))];
            case 2 % both flex and extend
                if mod(count, 2) % if count is odd, make extension trial, otherwise make flex trial
                    B{count}.mvtmat(DOF(j),:) = [-1*(Endpt+RandomizeEndpt*rand(1)),...
                        (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                        (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                        (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))];
                else
                    B{count}.mvtmat(DOF(j),:) = [(Endpt+RandomizeEndpt*rand(1)),...
                        (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                        (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                        (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))];
                end
                
        end
        
    end
end
%%
for k = 1:length(ComboList) % not done yet
    % grasp
    for j = 1:NumTrials*TrialMult
        count = count+1;
        B{count}.tracking = TrackingFlag;
        switch ComboList(k)
            case 1
                B{count}.mvtname = 'Grasp';
                curDOF = [1,2,3,4,5];
                switch FlexFlag
                    case 0 % extension only
                        B{count}.mvtmat = zeros(12, 4);
                        B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
                            (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                            (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                            (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                    case 1 % flexion only
                        B{count}.mvtmat = zeros(12, 4);
                        B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
                            (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                            (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                            (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                    case 2 % both flex and extend
                        if mod(count, 2)
                            B{count}.mvtmat = zeros(12, 4);
                            B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
                                (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                                (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                                (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                        else
                            B{count}.mvtmat = zeros(12, 4);
                            B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
                                (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                                (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                                (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                        end
                        
                        
                end
        end
        
    end
    
    % thumb index pinch
    for j = 1:NumTrials*TrialMult
        count = count+1;
        B{count}.tracking = TrackingFlag;
        B{count}.mvtname = 'ThumbIndPinch';
        curDOF = [1,2];
        switch FlexFlag
            case 0 % extension only
                B{count}.mvtmat = zeros(12, 4);
                B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
                    (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                    (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                    (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
            case 1 % flexion only
                B{count}.mvtmat = zeros(12, 4);
                B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
                    (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                    (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                    (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
            case 2 % both flex and extend
                if mod(count, 2)
                    B{count}.mvtmat = zeros(12, 4);
                    B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
                        (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                        (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                        (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                else
                    B{count}.mvtmat = zeros(12, 4);
                    B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
                        (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
                        (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
                        (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
                end
                
        end
    end
    
    %     % tripod pinch
    %     for j = 1:NumTrials*TrialMult
    %         count = count+1;
    %         B{count}.tracking = TrackingFlag;
    %         B{count}.mvtname = 'TripodPinch';
    %         curDOF = [1,2,3];
    %         switch FlexFlag
    %             case 0 % extension only
    %                 B{count}.mvtmat = zeros(12, 4);
    %                 B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
    %                     (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
    %                     (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
    %                     (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
    %             case 1 % flexion only
    %                 B{count}.mvtmat = zeros(12, 4);
    %                 B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
    %                     (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
    %                     (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
    %                     (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
    %             case 2 % both flex and extend
    %                 if mod(count, 2)
    %                     B{count}.mvtmat = zeros(12, 4);
    %                     B{count}.mvtmat(curDOF,:) = repmat([-1*(Endpt+RandomizeEndpt*rand(1)),...
    %                         (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
    %                         (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
    %                         (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
    %                 else
    %                     B{count}.mvtmat = zeros(12, 4);
    %                     B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
    %                         (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
    %                         (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
    %                         (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
    %                 end
    %
    %         end
    %     end
    %
    %     % key grip (flex only)
    %     for j = 1:NumTrials
    %         count = count+1;
    %         B{count}.tracking = TrackingFlag;
    %         B{count}.mvtname = 'KeyGrip';
    %         curDOF = [2,3,4,5,6];
    %         B{count}.mvtmat = zeros(12, 4);
    %         B{count}.mvtmat(curDOF,:) = repmat([(Endpt+RandomizeEndpt*rand(1)),...
    %             (mDelay+RandomizeDelay*RandomizeSpan*rand(1)), ...
    %             (mVelocity+RandomizeVel*RandomizeSpan*rand(1)), ...
    %             (HoldTime+RandomizeHoldTime*RandomizeSpan*rand(1))],length(curDOF),1);
    %
    %     end
    
end
%%
if RandomizeOrder
    shuffledIdx = randperm(length(B));
else
    shuffledIdx = [1:length(B)];
    
end
fid = fopen(outfile, 'w+');
%  fprintf(SS.KEFTrainFID,'SS.TrialTS=%0.0f;%s\r\n' fprintf(SS.KEFTrainFID,'SS.TargOnTS=%0.0f;'
%ThumbFlex_slow;1;1.00,0.00,2.00,1.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;0.00,0.00,0.00,0.00;
for j = 1:length(B)
    curIdx = shuffledIdx(j);
    fprintf(fid,'%s;%0.0f;%s;\r\n',B{curIdx}.mvtname, B{curIdx}.tracking, ...
        regexprep(regexprep(regexprep(mat2str(B{curIdx}.mvtmat, 3), ' ', ',') , '[', ''), ']', ''));
end
fclose(fid);

MovementStruct = B;




