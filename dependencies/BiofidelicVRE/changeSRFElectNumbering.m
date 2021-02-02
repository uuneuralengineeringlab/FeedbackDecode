function newsrf=changeSRFElectNumbering(srf,destinationPort)
%changeSRFElectNumbering changes the electrode numbering in an SRF to
%correspond to a different Ripple NIP port. For example, if the full stim
%map of the original SRF file was carried out using port A, then electrode
%numbering in the SRF file will be 1:100 (less reference elects). However,
%if one would like to later load this same SRF data into FeedbackDecode for
%closed-loop control using port B instead of port A, the electrode
%numbering needs to be updated to correspond to the new port.
%
%Inputs---------------
%   srf: an srf structure array, which can be loaded into matlab using
%   readSRF(srfFilePath).
%
%   destinationPort: an integer that is 1,2,3, or 4, indicating the
%   destination port for the new SRF structure. These correspond to ports
%   A, B, C, and D, respectively.
%
%Outputs-------------
%   newsrf: a new matlab srf structure with updated electrodes
%   corresponding to the new port.
%
%David Page
%david.page@utah.edu
%(208) 403-6191

newsrf=srf;
elecList=cell2mat({srf.input.electrodes_d});

%verify that the contents of original SRF come from only one NIP port
if not((all(1<=elecList) && all(elecList<=100)) | (all(101<=elecList) && all(elecList<=200)) | (all(201<=elecList) && all(elecList<=300)) | (all(301<=elecList) && all(elecList<=400)))
    error('ERROR: Contents of original SRF file come from more than one NIP port')
end

%identify port of original srf file
origPort=ceil(max(elecList)/100);%a number (1,2,3,4) indicating which port number was used
additionFactor=(destinationPort-origPort)*100;


for ii=1:numel(srf.input)
    newsrf.input(ii).electrodes_d=srf.input(ii).electrodes_d + additionFactor;
end
end