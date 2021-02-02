function [SRF] = assignContactSensor(SRF,varargin)
% assignContactSensor - creates a new fieldname, given as contactSensor_s, for the SRF output struct.
%
% Syntax:  [output1] = assignSensor(input1, input2, input3, input4, input5)
%
% Inputs:
%    input1 - SRF data file
%    input2 - (optional) image containing each sensor location.  See genSensorRegions.m for help 
%    input3 - (optional) labels corresponding to the colors of the regions for each sensor location.  See genSensorRegions.m for help
%       default values for image and labels are defined below
%
% Outputs:
%    output1 - Matlab structure containing contact sensors with regions defined as all the pixels in that region
%
% Example:
%    newSRF = assignContactSensor(oldSRF);
%
% Other m-files required: none
% Subfunctions: genSensorRegions.m
% MAT-files required: none
%
% See also: ContactSensorColorLabelsTemplate.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 29-June-2015

%------------- BEGIN CODE ---------------
    %new field name
    fieldname = 'contactSensor_s';
    %try to get labels and image
    try
        image = varargin{1};
    catch
        image = load('contactSitesImage');
        image = image.image;
    end
    try
        labels = varargin{2};
    catch
        labels = load('contactLabels');
        labels = labels.labels;
    end
    %Generate regions
    regions = genSensorRegions(image,labels);
    %Update SRF file info to contain labels
    newfield1 = 'contactLabels';
    SRF.info.(newfield1) = labels;
    if(isfield(SRF.output,fieldname))
        return;
    end
    %Pre-allocate space
    tmp=cell(size(SRF.output));
    [SRF.output(:).(fieldname)]=deal(tmp{:});
    %Determine # of sensors
    contactNames = fieldnames(regions);
    nContacts = length(contactNames);
    for ii = 1:length(SRF.output)       %go through each entry and find sensor regions that the coords are within
        % check only the appropriate marker type
        if (iscell(SRF.output(ii).markerType_s))
        	marker = SRF.output(ii).markerType_s';
        else
            marker = {SRF.output(ii).markerType_s};
        end
        mask = cellfun(@(x)strcmp(x,'Point'),marker);
        if(any(mask))
            xloc = [SRF.output(ii).xposition_a]';
            yloc = [SRF.output(ii).yposition_a]';
            xlocp = xloc(mask);
            ylocp = yloc(mask);
            xlocp = [xlocp{:,:}]';
            ylocp = [ylocp{:,:}]';
            mask2 = cellfun(@(x)strcmp(x,'FreeForm'),marker);
            xlocpoly = xloc(mask2);
            ylocpoly = yloc(mask2);
            xlocpoly = [xlocpoly{:,:}]';
            ylocpoly = [ylocpoly{:,:}]';
            x = [xlocp;xlocpoly];
            y = [ylocp;ylocpoly];
            locations = [x, y];
            name = {};
            for jj = 1:nContacts                                  %check all locations against all possible sensor regions
                pixels = regions.(contactNames{jj});
                if (any(ismember(locations,pixels,'rows')))
                    name = [name contactNames(jj)];
                end
            end
            SRF.output(ii).(fieldname) = name;                    %add new name to odd names
        end
    end
    
%------------- END OF CODE --------------
end

function [sensorLocations] = genSensorRegions(image,labels)
% genSensorRegions - returns a struct of contact sensors with regions defined by pixel coordinates
%
% Syntax:  [output1] = genSensorRegions(input1, input2)
%
% Inputs:
%    input1 - image containing color coded contact sensor locations. 400x600 pixels
%    input2 - labels struct matching each region name with it's corresponding color (see ContactSensorColorLabelsTemplate.m for help generating the struct) 
%
% Outputs:
%    output1 - Matlab array containing contact sensors with regions defined as pixel coordinates.
%            - The output array is a Zx2 double, where Z(:,1) is the y pixels and Z(:,2) is the x pixels
%
% Example:
%    sensorLocations = genSensorRegions(image,labels);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: Appendix A of SRF_Example.m

% Author: Jacob A. George
% University of Utah, Dept. of Bioengineering
% email address: jakegeorge93@utexas.edu  
% Website: http://www.bioen.utah.edu/faculty/Clark/research.html
% June 2015; Last revision: 3-June-2015

%------------- BEGIN CODE ---------------
    %% Segmenet Image
    cform = makecform('srgb2lab');
    lab_image = applycform(image,cform);
    ab = double(lab_image(:,:,2:3));       %creates a giant double array of the a and b LAB space vals
    nrows = size(ab,1);
    ncols = size(ab,2);
    ab = reshape(ab,nrows*ncols,2);
    contactNames = fieldnames(labels);
    nContacts = length(contactNames);
    nColors = nContacts + 1;   %add one for background
    [cluster_idx, cluster_center] = kmeans(ab,nColors,'distance','sqEuclidean','Replicates',3);     %repeat the clustering 3 times to avoid local minima
    pixel_labels = reshape(cluster_idx,nrows,ncols);    % Label all pixels with their appropriate index
    rgb_label = repmat(pixel_labels,[1 1 3]);
    %% Fill in contact regions
    sensorLocations = labels;              %allocate space
    for ii = 1:nColors      %create pixel list for each contact sensor, save into struct
        %Create mask for region
        mask = pixel_labels;
        mask(pixel_labels ~= ii) = 0;
        mask(pixel_labels == ii) = 1;
        region = regionprops(mask, 'PixelList');
        pixels = region.PixelList;
        %Use first pixel set to get RGB color
        y = pixels(1,1);
        x = pixels(1,2);
        r = image(x,y,1);
        g = image(x,y,2);
        b = image(x,y,3);
        rgb = [r,g,b];
        for jj = 1:nContacts        %when segment color equals label, save with label fieldname
            contactColor = labels.(contactNames{jj});
            if (all(isequal(rgb,contactColor)))
                sensorLocations.(contactNames{jj}) = pixels;
            end
        end
    end
%------------- END OF CODE --------------
end
