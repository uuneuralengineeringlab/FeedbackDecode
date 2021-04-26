%% Run this to create FeedbackDecodeAux.exe for starting the compiled software
% -p is to include toolboxes in the compilation
% If executable fails, it usually means a missing toolbox, missing mex
% file, or bad file location reference
mcc -m FeedbackDecodeAux.m -d 'Z:\Shared drives\CNI\Tasks\FeedbackDecode\build' -v -N -p instrument -p signal -p stats -p curvefit -p images -p mbc
copyfile('Z:\Shared drives\CNI\Tasks\FeedbackDecode\build\FeedbackDecodeAux.exe','\\PNIMatlab\PNIMatlab_R1\RemoteRepo\FeedbackDecodeAux.exe')