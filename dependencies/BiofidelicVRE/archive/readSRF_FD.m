function [srf_metaData] = readSRF_FD(filelocation)
% readSRF - Driver File that can be used to process folders of SRF data or a single SRF file
%
% Syntax:  [output1] = readSRF(input1)
%
% Inputs:
%    input1 - SRF file location or folder location containing SRFs
%
% Outputs:
%    output1 - Matlab structure containing all srf datasets
%
% Example:
%    all_SRF_data = readSRF('C:\Users\Jake\Data\mySRFfolder');
%
% Other m-files required: none
% Subfunctions: parseInput
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 26-June-2015

%------------- BEGIN CODE ---------------
    if(isdir(filelocation))
        cd(filelocation);
        files = dir('*.srf');   %get all srf files
        len = length(files);
        fieldNames = cell(1,len);    %preallocate space
        %make filenames into fieldnames
        for index=1:len
            fieldNames(1,index) = cellstr(files(index).name);
        end
        % Create Struct
        srf_metaData = struct('fileName',fieldNames,'data',[]);
        % Fill in SRF datas
        for index=1:len
            filename = files(index).name;
            try
                srf_metaData(index).data = parseInput(filename);
            catch ME
                msg = ['Error occured in file: ',filename];
                causeException = MException('MATLAB:myCode:dimensions',msg);
                ME = addCause(ME,causeException);
                rethrow(ME)
            end
        end
    else
        srf_metaData = parseInput(filelocation);
    end
%------------- END OF CODE --------------
end

function [SRF] = parseInput(filename)
% parseInput - Reads an srf.txt file and extracts information into a dataset array
%
% Syntax:  [output1] = parseInput(input1)
%
% Inputs:
%    input1 - Filename with .srf file extension
%
% Outputs:
%    output1 - Matlab structure containing all srf data
%
% Example: 
%    MySRFdata = parseInput('mydata.srf');
%
% Other m-files required: none
% Subfunctions: formatValue
% MAT-files required: none
%
% See also: none

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% May 2015; Last revision: 1-June-2015

%------------- BEGIN CODE --------------
    %% Determine Size
    % File information
    fileID = fopen(filename);
    % Determine the number of i/o sequences
    inputfile = textscan(fileID, '%s', 'delimiter', '\n');
    text_lines = inputfile{1};
    filelength = length(text_lines);
    A = 0;
    for index = 1:length(text_lines)    %count each line to find number of inputs
        if(strcmp(text_lines(index),'**Input:'))
            A = A + 1;
        end
    end
    % Determine size of input and output parameters
    inputStarts = find(strcmp(text_lines, '**Input:'), filelength, 'first');    %starting locations for input sections
    outputStarts = find(strcmp(text_lines, '**Output:'), filelength, 'first');  %starting locations for output sections
    %double check the filetype
    if (size(inputStarts) ~= size(outputStarts))
        fprintf('Corrupt File: # of Input != # of Output')
    end
    %sizes
    inputSize = outputStarts(1,1) - inputStarts(1,1) - 1;
    if(length(inputStarts) == 1)    %size when only one i/o
        outputSize = length(text_lines) - inputStarts(1,1) - inputSize - 1;
    else
        outputSize = inputStarts(2,1) - outputStarts(1,1) - 1;
    end
    %% Allocate Space
    % get file information
    fileID = fopen(filename);
    formatSpec = '%s%s';
    B = textscan(fileID,formatSpec,...
    'Delimiter',';');
    labels = B{1};
    data = B{2};
    diff = length(labels) - length(data);
    if (diff > 1)   %Error checking for last line null
        fprintf('Error! Somehow the length of the labels vector is more than the length of the data vector.\n');
    elseif (diff == 1)
        data{end+1} = {};
    end
    % create information struct (use header lines)
    infoStart = (find(strcmp(text_lines, '**File Information:'), filelength, 'first')) + 1;    %starting locations for file information
    infoEnd = inputStarts(1,1) - 1;
    infoFields = labels( infoStart:infoEnd );
    infoFieldNames = cellstr(infoFields');
    info = cell2struct(cell([1 length(infoFieldNames)]), infoFieldNames, 2);
    % create input struct (use only labels and data for the input section)
    inputStart = inputStarts(1,1) + 1;
    inputEnd = inputStart + inputSize - 1;
    inputFields = labels(inputStart:inputEnd);
    inputFieldNames = cellstr(inputFields');
    input = cell2struct(cell([A length(inputFieldNames)]), inputFieldNames, 2);
    % create output struct (use only labels and data for the output section)
    outputStart = outputStarts(1,1) + 1;
    outputEnd = outputStart + outputSize - 1;
    outputFields = labels(outputStart:outputEnd);
    outputFieldNames = cellstr(outputFields');
    output = cell2struct(cell([A length(outputFieldNames)]), outputFieldNames, 2);
    % create SRF struct
    SRF = struct('info',info,'input',input,'output',output);
    %% fill in data
    % info values
    infoEnd = inputStarts(1,1) - 1;
    infoSubsection = data(infoStart:infoEnd);
    for jj = 1:length(infoSubsection);
        label = infoFields{jj};
        val = infoSubsection{jj};
        val = formatValue(label,val);
        SRF.info.(infoFields{jj}) = val;
    end
    % input values
    for index=1:length(inputStarts)
        inputStart = inputStarts(index,1) + 1;
        inputEnd = inputStart + inputSize - 1;
        inputSubsection = data(inputStart:inputEnd);
        for jj = 1:length(inputSubsection);
            label = inputFields{jj};
            val = inputSubsection{jj};
            val = formatValue(label,val);
            SRF.input(index).(inputFields{jj}) = val;
        end
    end
    % output values
    for index=1:length(outputStarts)
        outputStart = outputStarts(index,1) + 1;
        outputEnd = outputStart + outputSize - 1;
        outputSubsection = data(outputStart:outputEnd);
        for jj = 1:length(outputSubsection);
            label = outputFields{jj};
            val = outputSubsection{jj};
            val = formatValue(label,val);
            SRF.output(index).(outputFields{jj}) = val;
        end
    end
%------------- END OF CODE --------------
end

function [val] = formatValue(label,val)
% FUNCTION_NAME - Reads an srf.txt file and extracts information into a dataset array
%
% Syntax:  [output1] = formatValue(input1, input2)
%
% Inputs:
%    input1 - datatype label
%    input2 - data value
%
% Outputs:
%    output1 - value for data structure
%
% Example: 
%    MySRFdata = formatValue(srf.txt);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: none

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 1-June-2015

%------------- BEGIN CODE --------------
    if(isempty(val));
        return;
    end
    tag = label( (length(label) - 1):length(label) );
    switch tag
        case '_t'   %time
            val = strsplit(val,',');
            val = str2double(val);
            val = datetime(val);
        case '_d'   %double
            val = strsplit(val,',');
            val = str2double(val);
        case '_a'   %array
            val = regexprep(val,'[[]]',''); %remove all brackets
            val = strsplit(val,',');
            for ii = 1:length(val)
                subval = val{ii};
                subval =  strsplit(subval,' ');
                subval = str2double(subval);
                val{ii} = subval;
            end
        case '_s'   %string
            val = strsplit(val,',');
            if (length(val) == 1)
                val = val{1};
            end
        otherwise
            fprintf('Corrupt File: no tag specificied for datatype!\n');
            fprintf('The corrupt datatype label is: %s\n', label);
            fprintf('The tag was interpreted as: %s\n', tag);
    end 
%------------- END OF CODE --------------
end