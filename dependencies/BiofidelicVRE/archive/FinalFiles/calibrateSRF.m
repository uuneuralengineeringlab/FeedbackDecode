function [varargout] = calibrateSRF(filelocation,varargin)
% calibrateSRF - reads in an SRF file, or folder of SRF files, and then creates a calibration.mat file for each SRF file
%
% Syntax:  [output1] = encode(input1,input2)
%
% Inputs:
%    input1 - SRF file location or folder location containing SRFs
%    input2 - (optional) file location to save all calibration.mat files.  If not specified, files will be saved in the current directory
%
% Outputs:
%    output - (optional) string containing the filepath of the calibration.mat files.  There can be as many output strings as the number of SRF files in the folder. See Example
%               
% Notes:
%    none
%
% Example:
%    [savepath1, savepath2, savepath3] = calibrateSRF('C:\Users\Jake\SRFdata','C:\Users\Jake\SRFcalibrations')
%
% Other m-files required: readSRF.m
% Subfunctions: none
% MAT-files required: none
%
% See also:

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% July 2015; Last revision: 27-July-2015

%% ------------- BEGIN CODE --------------
    %determine save location
    try
        savelocation = varargin{1};
    catch
        savelocation = cd;
    end
    %get all SRF data
    SRFdata = readSRF(filelocation);
    %calibrate SRFs
    if(length(SRFdata) == 1)
        %file name:
        temp = strsplit(filelocation,'\');
        temp = temp{end};
        temp = strsplit(temp,'.');
        temp = temp{1};
        filename = [temp '.mat'];
        %srf data:
        SRF = SRFdata;
        %calibration:
        [cutaneousMap,proprioceptionMap,amplitudeMap,durationMap,frequencyMap1,frequencyMap2,frequencyMap3, SRF] = calibrateEncode(SRF);
        %save:
        proprioLabels = fieldnames(SRF.info.proprioceptionLabels);
        cutaneousLabels = fieldnames(SRF.info.contactLabels);
        cd(savelocation);
        save(filename,'cutaneousMap','proprioceptionMap','amplitudeMap','durationMap','frequencyMap1','frequencyMap2','frequencyMap3','proprioLabels','cutaneousLabels');
        loc = cd;
        fileloc = [loc '\' filename];
        varargout{1} = fileloc;
    else
        for ii = 1:length(SRFdata)
            %file name:
            temp = strsplit(SRFdata(ii).fileName,'.');
            temp = temp{1};
            filename = [temp '.mat'];
            %SRF data:
            SRF = SRFdata(ii).data;
            %calibrate and save:
            try
                fprintf('\nCurrent File: %s\n',filename);
                [cutaneousMap,proprioceptionMap,amplitudeMap,durationMap,frequencyMap1,frequencyMap2,frequencyMap3, SRF] = calibrateEncode(SRF);
                proprioLabels = fieldnames(SRF.info.proprioceptionLabels);
                cutaneousLabels = fieldnames(SRF.info.contactLabels);
                cd(savelocation);
                save(filename,'cutaneousMap','proprioceptionMap','amplitudeMap','durationMap','frequencyMap1','frequencyMap2','frequencyMap3','proprioLabels','cutaneousLabels');
                loc = cd;
                fileloc = [loc '\' filename];
                varargout{ii} = fileloc;
            catch
                fprintf('WARNING: %s may not have been saved!\n',filename);
            end
        end
    end
% ------------ END OF CODE ---------------
end