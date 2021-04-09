function [Return] = train_NN_python(x, z, TrainMask, TestMask, ip, port, timeout)
    % Train the neural specified in the config files throught he socket
    
    size(x)
    size(z)
    
    %% Create socket and train the system
    socket = py.utah_client.UtahSocketClient();
    socket.connect("localhost", 54321);

    success = socket.train(z(:,TrainMask)', x(:,TrainMask)');
    socket.disconnect();
    if success
        disp("OSU training successful!")
    else
        disp("OSU training unsuccessful!")
    end 
    
    %% Prepare output
    NN_Python.TRAIN.socket = socket;
    NN_Python.TRAIN.Xmeans = mean(x(:,TrainMask)');
    NN_Python.TRAIN.Zmeans = mean(z(:,TrainMask)');
    NN_Python.TRAIN.Xstd = std(x(:,TrainMask)');
    idx  =  NN_Python.TRAIN.Xstd ==0;
    NN_Python.TRAIN.Xstd(idx) = 10^-6;
    NN_Python.TRAIN.Zstd = std(z(:,TrainMask)');
    idx  =  NN_Python.TRAIN.Zstd ==0;
    NN_Python.TRAIN.Zstd(idx) = 10^-6;
    Return = NN_Python.TRAIN;
end

