function [] = writeSRF(SRF, filename,filelocation)
% writeSRF - writes a .srf text file to the file location
%
% Syntax:  [] = writeSRF(input1, input2, input3)
%
% Inputs:
%    input1 - SRF file to write as text
%    input2 - filename (if .srf is excluded, it will be added automatically)
%    input3 - file location to be saved into
%
% Outputs:
%    none
%
% Example:
%    writeSRF(mySRF, 'mySRF', 'C:\Users\Jake\Documents\')
%
% Other m-files required: none
% Subfunctions: printData
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 10-June-2015

%------------- BEGIN CODE ---------------
    %% File setup
    %create file extension if needed
    len = length(filename);
    if(len < 4)
        filename = [filename '.srf'];
    end
    if(~strcmp(filename(len - 3:len),'.srf'))
    	filename = [filename '.srf'];
    end
    %create file
    cd(filelocation);
    fid = fopen(filename, 'wt');
    %% Info Section
    fprintf(fid,'**File Information:\n');
    data = SRF.info;
    printData(fid,data);
    %% I/O Section
    input = SRF.input;
    numEntry = length(input);
    output = SRF.output;
    for entry =1:numEntry
    	fprintf(fid,'**Input:\n');
        data = input(entry);
        printData(fid,data);
        fprintf(fid,'**Output:\n');
        data = output(entry);
        printData(fid,data);
    end     %print each io
%------------- END OF CODE --------------
end

function [] = printData(fid,data)
% printData - writes each field and value to the file ID text file using the SRF format
%
% Syntax:  [] = printData(input1, input2)
%
% Inputs:
%    input1 - file ID number used to print to
%    input2 - data struct containing fields and values.  Struct size should be 1x1
%
% Outputs:
%    none
%
% Example:
%    writeSRF(fid, SRF.input(1))
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
% June 2015; Last revision: 10-June-2015

%------------- BEGIN CODE ---------------
    names = fieldnames(data);
    numNames = length(names);
    for jj=1:numNames
        field = names{jj};
        value = data.(field);
        tag = field( (length(field) - 1):length(field) );
        switch tag
            case '_t'
                value = datevec(value);
                text = sprintf('%.0f,',value);
                text = text(1:end-1);
                fprintf(fid,'%s;%s\n',field,text);
            case '_d'
                text = sprintf('%.0f,',value);
                text = text(1:end-1);
                fprintf(fid,'%s;%s\n',field,text);
            case '_a'
                fprintf(fid,'%s;',field);
                text = [];
                for ii = 1:length(value);
                    text = [text '['];
                    val = value{ii};
                    subtext = sprintf('%.0f ',val);
                    subtext(end) = ']';    %replace last space
                    text = [text subtext ','];
                end
                text = text(1:end-1);   %remove last comma
                fprintf(fid,'%s\n',text);
            case '_s'
                if(iscell(value))
                    fprintf(fid,'%s;',field);
                    text = [];
                    for ii = 1:length(value)
                        val = value{ii};
                        subtext = sprintf('%s,',val);
                        text = [text subtext];
                    end
                    text = text(1:end-1);   %remove last comma
                    fprintf(fid,'%s\n',text);
                else
                	fprintf(fid,'%s;%s\n',field,value);
                end
            otherwise
                
        end
    end     %print each field
%------------- END OF CODE --------------
end