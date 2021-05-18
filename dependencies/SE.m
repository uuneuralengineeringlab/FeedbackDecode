function [idxs] = SE(varargin)
% returns indexs for single ended in EMG matrix.
    EMGMatrix = genEMGMatrix([]);
    idxs = find(sum(EMGMatrix,1) == 1);
end