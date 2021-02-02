function [SRF] = assignReceptors_FD(SRF)
% assignRegions - assigns receptor types (SA1, SA2, RA1, RA2, MS1, MS2) to all channels possible
%
% Syntax:  [output1] = assignReceptor(input1)
%
% Inputs:
%    input1 - SRF struct
%
% Outputs:
%    output1 - Updated SRF struct
%
% Example:
%    newSRF = assignReceptors(SRF);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 28-July-2015

%------------- BEGIN CODE ---------------
%% First create field name for receptorType_s if it doesn't already exist
    if(~isfield(SRF.output, 'receptorType_s'))
        fieldname = 'receptorType_s';
        tmp=cell(size(SRF.output));
        [SRF.output(:).(fieldname)]=deal(tmp{:});
    end
%% Fill in any known receptors
% If any one input has been determined to be a specific type, all inputs on the same channel are also of that type:
    len = length(SRF.output);
    for ii = 1:len
        if (~isempty(SRF.output(ii).receptorType_s))
            channel = SRF.input(ii).electrodes_d;
            for jj=1:len
                if(all( isequal(SRF.input(jj).electrodes_d,channel)    )   )
                	SRF.output(jj).receptorType_s = SRF.output(ii).receptorType_s;
                end
            end
        end
    end
%% Fill in any SA1 receptors
% SA1 receptors are any receptors that are of quality 'pressure'
    for ii = 1:len
        if ( ( isempty(SRF.output(ii).receptorType_s) ) && ( all( strcmp(SRF.output(ii).quality_s,'Pressure') ) ) )
            SRF.output(ii).receptorType_s = 'SA1';
        end
    end
%% Fill in any SA2 receptors
% SA2 receptors are any receptors are preceived as movement
% SA2 receptors are also diffuse and deep
    for ii = 1:len
        if( isempty(SRF.output(ii).receptorType_s) )
            if (iscell(SRF.output(ii).quality_s))  %get qualities
                qualities = SRF.output(ii).quality_s';
            else
                qualities = {SRF.output(ii).quality_s};
            end
            % check to see if the only reported quality is movement.
            mask = cellfun(@(x)strcmp(x,'Movement'),qualities);
            if ( all(mask) ) % if all the reported qualities are one of the above, continue:
                try %Determine Depth Value
                    depth = SRF.output(ii).DeepVsOn_Surface_s;
                catch
                    depth = '';     %depth field not present, assign null string
                end
                try %Determine Location Value
                    location = SRF.output(ii).ConfinedVsSpread_Out_s;
                catch
                    location = '';  %location field not present, assign null string
                end
                if ( all( strcmp(depth,'Deep') ) || all( strcmp(location,'Spread_Out') ) )  %if depth is surface or location is local, it is an RA1
                    SRF.output(ii).receptorType_s = 'SA2';
                end
            end
        end
    end    
%% Fill in any RA1 receptors
% RA1 receptors are any receptors are either tapping, flutter, vibration, buzzing or tingle
% RA1 receptors are also local and surface
    for ii = 1:len
        if( isempty(SRF.output(ii).receptorType_s) )
            if (iscell(SRF.output(ii).quality_s))  %get qualities
                qualities = SRF.output(ii).quality_s';
            else
                qualities = {SRF.output(ii).quality_s};
            end
            % check to see if the only reported qualities are tapping, flutter, vibration, buzzing or tingle.
            tapping = cellfun(@(x)strcmp(x,'Tapping'),qualities);
            flutter = cellfun(@(x)strcmp(x,'Flutter'),qualities);
            vibration = cellfun(@(x)strcmp(x,'Vibration'),qualities);
            buzzing = cellfun(@(x)strcmp(x,'Buzzing'),qualities);
            tingle = cellfun(@(x)strcmp(x,'Tingle'),qualities);
            mask = tapping | flutter | vibration | buzzing | tingle;
            if ( all(mask) ) % if all the reported qualities are one of the above, continue:
                try %Determine Depth Value
                    depth = SRF.output(ii).DeepVsOn_Surface_s;
                catch
                    depth = '';     %depth field not present, assign null string
                end
                try %Determine Location Value
                    location = SRF.output(ii).ConfinedVsSpread_Out_s;
                catch
                    location = '';  %location field not present, assign null string
                end
                if ( all( strcmp(depth,'On_Surface') ) || all( strcmp(location,'Confined') ) )  %if depth is surface or location is local, it is an RA1
                    SRF.output(ii).receptorType_s = 'RA1';
                end
            end
        end
    end
%% Fill in any RA2 receptors
% RA2 receptors are any receptors are either vibration, buzzing, tickle or tapping
% RA2 receptors are also diffuse and deep
    for ii = 1:len
        if( isempty(SRF.output(ii).receptorType_s) )
            if (iscell(SRF.output(ii).quality_s))  %get qualities
                qualities = SRF.output(ii).quality_s';
            else
                qualities = {SRF.output(ii).quality_s};
            end
            % check to see if the only reported qualities are tapping, flutter, vibration, buzzing or tingle.
            vibration = cellfun(@(x)strcmp(x,'Vibration'),qualities);
            buzzing = cellfun(@(x)strcmp(x,'Buzzing'),qualities);
            tickle = cellfun(@(x)strcmp(x,'Tickle'),qualities);
            tapping = cellfun(@(x)strcmp(x,'Tapping'),qualities);
            mask = vibration | buzzing | tickle | tapping;
            if ( all(mask) ) % if all the reported qualities are one of the above, continue:
                try %Determine Depth Value
                    depth = SRF.output(ii).DeepVsOn_Surface_s;
                catch
                    depth = '';     %depth field not present, assign null string
                end
                try %Determine Location Value
                    location = SRF.output(ii).ConfinedVsSpread_Out_s;
                catch
                    location = '';  %location field not present, assign null string
                end
                if ( all( strcmp(depth,'Deep') ) || all( strcmp(location,'Spread_Out') ) )  %if depth is surface or location is local, it is an RA1
                    SRF.output(ii).receptorType_s = 'RA2';
                end
            end
        end
    end
%% Fill in any MS1 or MS2 receptors
% MS1 or MS2 receptors are any receptors are preceived as movement
% MS1 receptors are preceived as a velocity of movement
% MS2 receptors are preceived as a position of movement
    for ii = 1:len
        if( isempty(SRF.output(ii).receptorType_s) )
            if (iscell(SRF.output(ii).quality_s))  %get qualities
                qualities = SRF.output(ii).quality_s';
            else
                qualities = {SRF.output(ii).quality_s};
            end
            % check to see if the only reported qualities is movement.
            mask = cellfun(@(x)strcmp(x,'Movement'),qualities);
            if ( all(mask) ) % if all the reported qualities are one of the above, continue:
                try %Determine movement value
                    movement = SRF.output(ii).Movement_s;
                catch
                    movement = '';     %movmement field not present, assign null string
                end
                if ( all( strcmp(movement,'Stationary') ) )  %if movement is stationary, then it's a MS2
                    SRF.output(ii).receptorType_s = 'MS2';
                end
                if ( all( strcmp(movement,'Moving') ) )  %if movement is movement, then it's a MS1
                    SRF.output(ii).receptorType_s = 'MS1';
                end
            end
        end
    end
%%
    SRF.info.receptors = 1;
%------------- END OF CODE --------------
end