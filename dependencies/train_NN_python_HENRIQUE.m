function [Return] = train_NN_python(x, z, TrainMask, TestMask, ip, port, timeout)
    % Train the neural specified in the config files throught he socket
    
    size(x)
    size(z)
    
    %% Save csv files TODO  
    disp('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< WE ARE HERE')
    csvwrite('C:\Users\Administrator\Code\General\MLP\kine_data_train.csv', x(:,TrainMask))
    csvwrite('C:\Users\Administrator\Code\General\MLP\neural_data_train.csv', z(:,TrainMask))
    csvwrite('C:\Users\Administrator\Code\General\MLP\kine_data_test.csv', x(:,TestMask))
    csvwrite('C:\Users\Administrator\Code\General\MLP\neural_data_test.csv', z(:,TestMask))
    
    

    
    %% Create socket and train the system
    socket = py.socket_client.socket_client(ip, port, timeout);

    ans_socket = socket.train('//PNIMATLAB/PNIMatlab_R1/decodeenginepython_DO_NOT_DELETE/config.json');
    
    a = ans_socket.char;
    message = jsondecode(a(3:end-1));
    disp(message.message)
    
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
    disp('Trained')
    Return = NN_Python.TRAIN;
end

