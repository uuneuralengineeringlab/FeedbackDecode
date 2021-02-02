classdef AfferentStream < Afferent
   
    properties (SetAccess = private)
        state
        stim_hist
    end
    
    
    methods
        
        function obj = AfferentStream(class,varargin)
            obj@Afferent(class,varargin{:});
            obj.reset();
        end
        
        function [rate,spike_times] = response(obj,stim,sampling_frequency)
            if nargin<3
                sampling_frequency = 40;
            end
            
            dt_input=1/sampling_frequency;
            dt=1/20000;
            stim_int = pchip([-dt_input 0 dt_input],[obj.stim_hist stim],dt:dt:dt_input);
            
            [stimes,state] = MN_neuron_stream_wrapper(obj.parameters,obj.state,stim_int);
            win = state(1) - obj.state(1);
            spike_times = stimes - win(1);
            rate = length(spike_times)/win;
            obj.state = state;
            obj.stim_hist(1) = obj.stim_hist(2);
            obj.stim_hist(2) = stim;
        end
            
        function reset(obj)
            obj.state = [...
                0;...       % Time in s
                -.07;...    % V
                -.03;...    % Theta
                -Inf;...    % latest spike time
                ];
            
            obj.stim_hist = [0 0];
        end
        
    end
    
end
