%% Run this to create FeedbackDecode.exe  
% -a means include folder and files in compilation
mcc -m FeedbackDecode.m -d 'Z:\Shared drives\CNI\Tasks\FeedbackDecode\build' -v -a 'Z:\Shared drives\CNI\Tasks\FeedbackDecode\dependencies' -N -p instrument -p signal -p stats -p curvefit -p images -p mbc -p nnet
copyfile('Z:\Shared drives\CNI\Tasks\FeedbackDecode\build\FeedbackDecode.exe','\\PNIMatlab\PNIMatlab_R1\RemoteRepo\FeedbackDecode.exe')