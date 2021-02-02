classdef Afferent < handle
    
    properties
        class
        parameters
        location@double vector
        depth@double scalar
        model
        idx
    end
    
    properties (Dependent = true, SetAccess = private)
        iSA1, iRA, iPC
    end
    
    methods
        
        function obj = Afferent(class,varargin)
            if strcmpi(class,'ra')
                defaultDepth = 1.62;
            elseif strcmpi(class,'sa1')
                defaultDepth = .77;
            elseif strcmpi(class,'pc')
                defaultDepth = 2; % should check literature for real value
            else
                error('Afferent must be RA, SA1, or PC.')
            end
            p = inputParser;
            addRequired(p,'class');
            addOptional(p,'location',[0 0]);
            addParamValue(p,'depth', defaultDepth);
            addParamValue(p,'parameters',[]);
            addParamValue(p,'idx',[]);
            addParamValue(p,'model',[],@(x) strcmpi(x,'MN') || strcmpi(x,'GIF'));
            parse(p,class,varargin{:});
            
            obj.class = p.Results.class;
            obj.location = p.Results.location;
            
            obj.model = p.Results.model;
            if isempty(obj.model)
                obj.model = 'MN';
            end
            
            if ~isempty(p.Results.parameters)
                obj.parameters = p.Results.parameters;
            else
                if strcmp(obj.model,'MN')
                    MN_parameters;
                elseif strcmp(obj.model,'GIF')
                    GIF_parameters;
                end
                if ~isempty(p.Results.idx)
                    switch lower(obj.class)
                        case 'sa1'
                            idx = mod(p.Results.idx-1,length(parameters.sa))+1;
                            obj.parameters = parameters.sa{idx};
                        case 'ra'
                            idx = mod(p.Results.idx-1,length(parameters.ra))+1;
                            obj.parameters = parameters.ra{idx};
                        case 'pc'
                            idx = mod(p.Results.idx-1,length(parameters.pc))+1;
                            obj.parameters = parameters.pc{idx};
                    end
                    obj.idx = idx;
                    obj.depth = p.Results.depth;
                else
                    switch lower(obj.class)
                        case 'sa1'
                            idx = randperm(length(parameters.sa));
                            obj.parameters = parameters.sa{idx(1)};
                        case 'ra'
                            idx = randperm(length(parameters.ra));
                            obj.parameters = parameters.ra{idx(1)};
                        case 'pc'
                            idx = randperm(length(parameters.pc));
                            obj.parameters = parameters.pc{idx(1)};
                    end
                    obj.idx = idx(1);
                    obj.depth = p.Results.depth;
                end
            end
        end
        
        function obj = set.class(obj,class)
            if strcmpi(class,'SA')
                class = 'SA1';
            end
            if ~(strcmpi(class,'SA1') || strcmpi(class,'RA') || strcmpi(class,'PC'))
                error('Class must be SA1, RA, or PC.')
            end
            obj.class = upper(class);
        end
        
        function iSA1 = get.iSA1(obj)
            iSA1 = strcmp('SA1',obj.class);
        end
        
        function iRA = get.iRA(obj)
            iRA = strcmp('RA',obj.class);
        end
        
        function iPC = get.iPC(obj)
            iPC = strcmp('PC',obj.class);
        end
        
        function r = response(obj,stim)
            % propagates complex spatial stimulus to a single trace at a give location
            if(isa(stim,'Stimulus'))
                propagated_struct=propagate(stim,obj);
            else
                propagated_struct=stim;
            end
            if strcmp(obj.model,'MN')
                r = Response(obj,propagated_struct,MN_neuron_wrapper(obj,propagated_struct));
            elseif strcmp(obj.model,'GIF')
                r = Response(obj,propagated_struct,GIF_neuron_wrapper(obj,propagated_struct));
            end
        end
        
        function ax=plot(obj,ax,col)
            affclass={'SA1','RA','PC'};
            affcol= [ 50 200 105;6 128 191;245 127  31]/255;
            
            if(nargin<2||isempty(ax))
                ax=zeros(3,1);
                for ii=1:3
                    ax(ii)=subplot(1,3,ii);
                    
                    title(ax(ii),affclass{ii},'fontsize',22)
                    [origin,theta,pxl_per_mm]=plot_hand(ax(ii),...
                        'names',0,'axes',0,'centers',0);
                end
                set(ax,'nextplot','add');
                set(ax(1),'userdata',[origin,theta,pxl_per_mm])
                set(ax(1), 'position',[0 0 .33 .93])
                set(ax(2), 'position',[.33 0 .33 .93])
                set(ax(3), 'position',[.66 0 .33 .93])
            else
                info=get(ax(1),'userdata');
                origin=info(1:2);
                theta=info(3);
                pxl_per_mm=info(4);
            end
            rot=[cos(-theta) -sin(-theta);sin(-theta) cos(-theta)];
            loc=obj.location*rot;
            loc=loc*pxl_per_mm;
            loc=bsxfun(@plus,loc,origin);
            affidx=find(strcmp(affclass,obj.class));
            h=plot(ax(affidx),loc(:,1),loc(:,2),'.','markersize',15);
            if(nargin<3),    set(h,'color',affcol(affidx,:));
            else             set(h,'color',col);
            end
            set(gcf,'Color','white');
        end
    end
end
