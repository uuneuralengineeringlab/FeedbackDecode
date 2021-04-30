classdef VTStim < handle
    % This function activates buzzers for vibrotactile feedback.
    % "C:\Users\Administrator\Box\CNI\Tasks\FeedbackDecode\resources\VibrotactileStim"
    %
    % VT = VTStim;
    % VT.write([255,0,100,50,0,0]); pwm output sent to buzzers (pins 3,5,6,9,10,11 on arduino nano)
    %
    % Version: 20210316
    % Author: Tyler Davis & Michael Paskett
    
    properties
        ARD; COMStr; Status;
    end
    
    methods
        function obj = VTStim
            obj.Status.PWM = zeros(6,1);
            obj.Status.ElapsedTime = nan;
            obj.Status.CurrTime = clock;
            obj.Status.LastTime = clock;
            init(obj);
        end
        function init(obj,varargin)
            devs = getSerialID;
            if ~isempty(devs)
                COMPort = cell2mat(devs(~cellfun(@isempty,regexp(devs(:,1),'CH340')),2));
                if ~isempty(COMPort)
                    obj.COMStr = sprintf('COM%0.0f',COMPort(1));
                end
            end
            delete(instrfind('port',obj.COMStr));
            obj.ARD = serialport(obj.COMStr,250000,'Timeout',1);
            configureCallback(obj.ARD,"terminator",@obj.read);
            flush(obj.ARD); pause(0.1);
            obj.write([0,0,0,0,0,0]); pause(0.1); %back to defaults
        end
        function close(obj,varargin)
            if isobject(obj.ARD)
                obj.write([0,0,0,0,0,0]); pause(0.1);
                delete(obj.ARD);
            end
        end
        function read(obj,varargin)
            try
                status = sscanf(readline(obj.ARD),'%f, '); %read to terminator (LF)
                obj.Status.PWM = status(1:6);
                obj.Status.CurrTime = clock;
                obj.Status.ElapsedTime = etime(obj.Status.CurrTime,obj.Status.LastTime);
                obj.Status.LastTime = obj.Status.CurrTime;
            catch
                disp('fscanf error...')
            end
        end
        function write(obj,varargin)
            pwm = varargin{1}(:);
            pwm(pwm<0) = 0; pwm(pwm>255) = 255;
            write(obj.ARD,uint8(pwm),'uint8');
        end
    end    
end %class