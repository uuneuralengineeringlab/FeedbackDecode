function [subSRF,varargout] = getSRF_FD(SRF, varargin)
% getSRF - returns a subset of an SRF dataset that matches the given criteria
%
% Syntax:  [output1] = getSRF(input1, input2, input3, input4, variable inputs)
%
% Inputs:
%    input1 - srf struct created by parseInput.m
%    input2 - srf label for the data parameter
%    input3 - range of the value the subset must contain
%    input4 - variable options.  Can be a single parameter or a struct of parameters (SEE BELOW)
%    input5, input6 & input 7 - paired arguments similar to input2, input3 and input4, respectively.  Use for additional parameters if needed
%    ...
%    inputN, inputN+1 & inputN+2 - same as above.
%
% Outputs:
%    output1 - Matlab structure containing only SRF data meeting the given criteria
%
% Options:
%    Option Parameter       ::  Data Types  ::  Description
%    'involves'             ::  t-d-a-s     ::  ALL experiments that involve the given parameter
%    'onlyinvolves'         ::  d-a-s       ::  ONLY experiments that involve the given parameter
%    'within'               ::  d-t         ::  ONLY experiments that are within the given range
%    'outside'              ::  d-t         ::  ONLY experiments that are outside the given range
%    'greaterthan'          ::  d-t-a       ::  ALL experiments that involve values above the given cutoff
%    'onlygreaterthan'      ::  d-t-a       ::  ONLY experiments that involve values below the given cutoff
%    'allonlygreaterthan'   ::  a           ::  ONLY experiments that involve ALL array values below the given cutoff
%    'lessthan'             ::  d-t-a       ::  ALL experiments that involve values below the given cutoff
%    'onlylessthan'         ::  d-t-a       ::  ONLY experiments that involve values below the given cutoff
%    'allonlylessthan'      ::  a           ::  ONLY experiments that involve ALL array values below the given cutoff
%
% Example:
%    subSRF = getSRF(SRF, 'xposition_d', [120:150], 'yposition_d', [100,101,102,150,151,152], 'quality_s', 'pressure');
%
% Other m-files required: none
% Subfunctions: genMask()
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 4-June-2015

%------------- BEGIN CODE ---------------
    subSRF = SRF;
    if (nargin == 1) %if num arguments is even, fail
        fprintf('No conditions given!\n')
        return
    end
    if (mod(nargin-1,3) ~= 0) %if num of parameters after SRF is not in a set of 3, fail.
        fprintf('Invalid Input!\nPlease make sure to include sets of three: label, value, option')
        return
    end
    len = length(SRF.input);
    if (len == 0)
        return;
    end
    mask = true(1,len);
    for index = 1:3:( length(varargin) - 2 )
        label = varargin{index};
        val = varargin{index + 1};
        options = varargin{index + 2};
        try submask = genMask(SRF,label, val, options);
        catch
            fprintf('Operation Terminated\n')
            return
        end
        mask = (mask & submask);
    end
    subSRF.input = SRF.input(mask);
    subSRF.output = SRF.output(mask);
    varargout{1} = mask;
%------------- END OF CODE --------------
end

function [submask] = genMask(SRF,label, val, options)
% genMask - returns a mask of the SRF dataset based on the val and options parameters
%
% Syntax:  [output1] = genMask(input1, input2, input3, input4)
%
% Inputs:
%    input1 - srf struct created by parseInput.m
%    input2 - srf label for the data parameter
%    input3 - range of the value the subset must contain
%    input4 - variable options.  Can be a single parameter or a struct of parameters (SEE BELOW)
%
% Outputs:
%    output1 - mask for the SRF data
%
% Options:
%    see getSRF.m for detailed explanations about each option
%
% Example:
%    subMask = genMask(SRF, 'xposition_d', [120:150], 'within');
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also:

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 2-June-2015

%------------- BEGIN CODE ---------------
    tag = label( (length(label) - 1):length(label) );
    try SRF.output.(label); %determine if input or output
        io = 'output';
    catch
        io = 'input';
    end
    labels = {SRF.(io).(label)};
    switch tag
        case '_t'   %time
            switch options
                case 'involves'
                    submask = cellfun(@(x)all(ismember(val,x)),labels);
                case 'within'
                    try
                        if (length(val) ~= 2)
                            throw(ex);
                        else
                            t1 = val(1); t2 = val(2);
                        end
                    catch
                        fprintf('Invalid range for times. Type "Help getSRF" for more information.\n')
                        throw(ex);
                    end
                    submask = cellfun(@(x)isbetween(x,t1,t2),labels);
                case 'outside'
                    try
                        if (length(val) ~= 2)
                            throw(ex);
                        else
                            t1 = val(1); t2 = val(2);
                        end
                    catch
                        fprintf('Invalid range for times. Type "Help getSRF" for more information.\n')
                        throw(ex);
                    end
                    submask = cellfun(@(x)~(isbetween(x,t1,t2)),labels);
                case 'lessthan'
                    submask = cellfun(@(x)gt(val,x),labels);               
                case 'greaterthan'
                    submask = cellfun(@(x)gt(x,val),labels);
                otherwise
                    fprintf('Invalid option parameter for label of type "time"\n')
                    fprintf('Your option was: %s. Type "Help getSRF" for a list of valid option parameters\n', options)
                    return;  
            end         
        case '_d'   %double
            switch options
                case 'involves'
                    submask = cellfun(@(x)all(ismember(val,x)),labels);
                case 'onlyinvolves'
                    submask = cellfun(@(x)isequal(unique(x),unique(val)),labels);
                case 'within'
                    submask = cellfun(@(x)all(ismember(x,val)),labels);
                case 'outside'
                    submask = cellfun(@(x)all(~ismember(x,val)),labels);
                case 'greaterthan'
                    submask = cellfun(@(x)any(gt(x,val)),labels);
                case 'onlygreaterthan'
                    submask = cellfun(@(x)all(gt(x,val)),labels);
                case 'lessthan'
                    submask = cellfun(@(x)any(lt(x,val)),labels);
                case 'onlylessthan'
                    submask = cellfun(@(x)all(lt(x,val)),labels);
                otherwise
                    fprintf('Invalid option parameter for label of type "double"\n')
                    fprintf('Your option was: %s. Type "Help getSRF" for a list of valid option parameters\n', options)
                    return;   
            end        
        case '_a'   %array
            switch options
                case 'involves'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)any(isequal(val,x)),labels{ii});
                        if (sum(a) >= 1)
                            submask(ii) = 1;
                        end
                    end
                case 'onlyinvolves'
                    submask = cellfun(@(x)isequal(val,x{:}),labels);
                case 'greaterthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)any(gt(x,val)),labels{ii});
                        if (sum(a) >= 1)
                            submask(ii) = 1;
                        end
                    end
                case 'allgreaterthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)all(gt(x,val)),labels{ii});
                        if (sum(a) >= 1)
                            submask(ii) = 1;
                        end
                    end
                case 'onlygreaterthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)any(gt(x,val)),labels{ii});
                        if (mean(a) == 1)
                            submask(ii) = 1;
                        end
                    end
                case 'allonlygreaterthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)all(gt(x,val)),labels{ii});
                        if (mean(a) == 1)
                            submask(ii) = 1;
                        end
                    end
                case 'lessthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)any(lt(x,val)),labels{ii});
                        if (sum(a) >= 1)
                            submask(ii) = 1;
                        end
                    end
                case 'alllessthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)all(lt(x,val)),labels{ii});
                        if (sum(a) >= 1)
                            submask(ii) = 1;
                        end
                    end
                case 'onlylessthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)any(lt(x,val)),labels{ii});
                        if (mean(a) == 1)
                            submask(ii) = 1;
                        end
                    end
                case 'allonlylessthan'
                    submask = logical(zeros(1,length(labels)));
                    for ii = 1:length(labels)
                    a = cellfun(@(x)all(lt(x,val)),labels{ii});
                        if (mean(a) == 1)
                            submask(ii) = 1;
                        end
                    end
                otherwise
                    fprintf('Invalid option parameter for label of type "array"\n')
                    fprintf('Your option was: %s. Type "Help getSRF" for a list of valid option parameters\n', options)
                    return;   
            end           
        case '_s'   %string
            sublabel = cellfun(@(x)strcmp(x,val),labels,'UniformOutput', false);
            sublabel = cellfun(@mean, sublabel);
            sublabel(isnan(sublabel)) = 0;
            switch options
                case 'involves'
                	submask = logical(ceil(sublabel));
                case 'onlyinvolves'
                    submask = logical(floor(sublabel));
                otherwise
                    fprintf('Invalid option parameter for label of type "string"\n')
                    fprintf('Your option was: %s. Type "Help getSRF" for a list of valid option parameters\n', options)
                    return;
            end          
        otherwise
            fprintf('Invalid Label Name!\n');
            fprintf('The corrupt datatype label is: %s\n', label);
            fprintf('The tag was interpreted as: %s\n', tag);
    end
%------------- END OF CODE --------------    
end