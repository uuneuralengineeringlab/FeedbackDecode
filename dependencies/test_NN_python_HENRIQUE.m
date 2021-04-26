function [prediction] = test_NN_python(neural, kinematic, TRAIN,init, varargin)
%test_NN_python Predict the position of the hand

if init
    config_file = varargin{1};
    model_file = varargin{2};
    nbr_decoding_featires = varargin{3};
    nbr_kinematics = varargin{4};
    ans_client = TRAIN.socket.create_model(config_file, model_file, nbr_kinematics, nbr_decoding_featires);
    
    idx = TRAIN.Zstd==0;
    TRAIN.Zstd(idx) = 10^-6;
   
    idx = TRAIN.Xstd==0;
    TRAIN.Xstd(idx) = 10^-6;
    
    a = ans_client.char;
    message = jsondecode(a(3:end-1));
    disp(message.message)
    
    prediction = zeros(nbr_kinematics,1);
else    
    ans_client = TRAIN.socket.test((neural' - TRAIN.Zmeans)./ TRAIN.Zstd, (kinematic' - TRAIN.Xmeans)./ TRAIN.Xstd);
    
    a = ans_client.char;
    response = jsondecode(a(3:end-1));
    
    prediction = (response.data .*TRAIN.Xstd' + TRAIN.Xmeans');
end

end

