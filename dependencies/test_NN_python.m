function [prediction] = test_NN_python(neural, kinematic, TRAIN,init, varargin)
%test_NN_python Predict the position of the hand

if init
    % config_file = varargin{1};
    % model_file = varargin{2};
    nbr_decoding_featires = varargin{3};
    nbr_kinematics = varargin{4};
    % START THE CONTROL
    success = TRAIN.socket.start_control(nbr_decoding_featires, nbr_kinematics);
    
    idx = TRAIN.Zstd==0;
    TRAIN.Zstd(idx) = 10^-6;
    
    idx = TRAIN.Xstd==0;
    TRAIN.Xstd(idx) = 10^-6;
  
    if success
        disp("OSU control started!")
    else
        disp("OSU control error!")
    end 
    
    prediction = zeros(nbr_kinematics,1);
else    
    % PREDICTION
    response = TRAIN.socket.predict((neural' - TRAIN.Zmeans)./ TRAIN.Zstd);
    response = double(response);
    if isempty(response)
        disp("Error retreiving OSU prediction!")
        prediction = zeros(nbr_kinematics, 1);
    else
        prediction = (response .*TRAIN.Xstd' + TRAIN.Xmeans');
    end
end

end

