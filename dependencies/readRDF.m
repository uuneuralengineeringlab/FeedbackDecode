function [Data, RDFTime] = readRDF(fname)

% Reads in data saved to *.rdf file (Kalman decode filespec). This data is
% saved to disk when running FeedbackDecode.vi.
% input: 
%    fname- string, full file path of .rdf file
% output: 
%    Data - nsamples x nchannels matrix of baseline data
%    RDFTime - NS5 time of first Data sample (divide by 30e3 to get time in seconds
%    into NS5 file)
% Version: 20150716
% Author: smw
 
fid = fopen(fname);
RDFTime = fread(fid,1,'single');
numUEAs = fread(fid,1,'single');
blockSize = fread(fid,1,'single');
Data = fread(fid,'single');
fclose(fid);


% reshape into 3d, then 2D, then get rid of nans
nchans = 96*numUEAs;
nsegs = length(Data)/(nchans*blockSize);

Data = reshape(Data,blockSize,nchans,nsegs);
Data = permute(Data,[1,3,2]);
Data = reshape(Data,[],nchans);
Data(any(isnan(Data),2),:) = [];


