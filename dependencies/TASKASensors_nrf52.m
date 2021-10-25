classdef TASKASensors_nrf52 < handle
    % This class for connecting to, reading from, and closing the TASKA fingertip sensors
    %
    % Note: It is currently hard-coded for eight sensors (4 IR, 4 baro),
    % but could be adapted for other sensor counts
    %
    % Example usage:
    % TS = TASKASensors;
    % TS.Status.IR or TS.Status.BARO would display IR or baro data,
    % respectively
    %
    % Version: 20210222
    % Author: Tyler Davis
    
    properties
        ARD; COMStr; Status; Ready;
        BAROBuffer; IRBuffer; LoopCnt;
    end
    
    methods
        function obj = TASKASensors_nrf52(varargin)
            obj.Ready = false;
            obj.BAROBuffer = zeros(4,200);
            obj.IRBuffer = zeros(4,200);
            obj.LoopCnt = 1;
            obj.Status.IR = zeros(4,1);
            obj.Status.BARO = zeros(4,1);
            obj.Status.FORCE_EST = zeros(4,1);
            obj.Status.BAROSmallBuff = zeros(4,10);
            obj.Status.IRSmallBuff = zeros(4,10);
            obj.Status.ElapsedTime = nan;
            obj.Status.CurrTime = clock;
            obj.Status.LastTime = clock;
            obj.Status.Count = 1;
            init(obj);
        end
        function init(obj,varargin)
            devs = getSerialID;
            if ~isempty(devs)
                COMPort = cell2mat(devs(~cellfun(@isempty,regexp(devs(:,1),'USB Serial Device')),2));
                if ~isempty(COMPort)
                    obj.COMStr = sprintf('COM%0.0f',COMPort(1));
                end
            end
            delete(instrfind('port',obj.COMStr));
            obj.ARD = serialport(obj.COMStr,115200,'Timeout',1);
            configureCallback(obj.ARD,"terminator",@obj.read);
            flush(obj.ARD);
            pause(0.1);
            obj.Ready = true;
        end
        function close(obj,varargin)
            if isobject(obj.ARD)
                delete(obj.ARD);
            end
        end
        function read(obj,varargin)
            try
                [status, n] = sscanf(readline(obj.ARD),'%f,');
                obj.Status.BARO = [status(3); status(3:3:n)];
                obj.Status.IR = [status(2); status(2:3:n)];
                obj.Status.FORCE_EST = [status(1); status(1:3:n)];
                obj.Status.CurrTime = clock;
                obj.Status.ElapsedTime = etime(obj.Status.CurrTime,obj.Status.LastTime);
                obj.Status.LastTime = obj.Status.CurrTime;
                
                obj.Status.BAROSmallBuff = circshift(obj.Status.BAROSmallBuff,-1,2);
                obj.Status.IRSmallBuff = circshift(obj.Status.IRSmallBuff,-1,2);
                
                obj.Status.BAROSmallBuff(:,end) = obj.Status.BARO;
                obj.Status.IRSmallBuff(:,end) = obj.Status.IR;                
                
                % debug step to check how often samples actually make it to FeedbackDecode
%                 obj.Status.Count = obj.Status.Count + 1;
                
                % fill buffer for later use with calibration call in FeedbackDecode
                % this will prevent railing the LabVIEW loop speed
                obj.BAROBuffer(:,obj.LoopCnt) = obj.Status.BARO;
                obj.IRBuffer(:,obj.LoopCnt) = obj.Status.IR;
                obj.LoopCnt = obj.LoopCnt+1;
                if obj.LoopCnt>200
                    obj.LoopCnt = 1;
                end
            catch
                disp('TASKA sensors serial error...')
            end
        end
    end    
end %class