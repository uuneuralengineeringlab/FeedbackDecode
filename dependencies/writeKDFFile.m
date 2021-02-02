function varargout = writeKDFFile(Kinematics, Features, Targets, Kalman, NIPTime, NewKDFFileName)
% writes data to KDF file
% smw 4/2017

SS.X = Kinematics; % 12 x n samples
SS.Z = Features;% 720 x n samples
SS.T = Targets; % 12 x n samples
SS.K = Kalman; % 12 x n samples
SS.KDFTimes = NIPTime; % n samples
NewKDFFileFID = fopen(NewKDFFileName,'w+');
fwrite(NewKDFFileFID,[1;size(SS.Z,1);size(SS.X,1);size(SS.T, 1);size(SS.K, 1)],'single'); %writing header
fwrite(NewKDFFileFID,[SS.KDFTimes',SS.Z',SS.X',SS.T',SS.K']','single');
fclose(NewKDFFileFID);

disp(['Files written to: ' NewKDFFileName]);