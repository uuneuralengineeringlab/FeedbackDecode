function vout = mapRippleUEA(vin,mode,varargin)
% conversion between electrode, channel, feedback decode index 
% inputs: 
%   vin: integer values of elec, ch, or index   
%   mode: conversion mode.  options are 'e2c', 'c2e', 'i2c', 'c2i', 'e2i',
%   'i2e'
%   mapname: (optional), name of electrode map.  options are 'pns' (classic
%   tdt), 'haptix' (passive gator Haptix S1), 'haptixActive' (active gator Haptix s1)
% outputs: 
%   vout: integer value of the converted ch, elec, or index
% example ch = mapRippleUEA(elec, 'e2c, 'haptixActive');
% updated for gator mapping 8/31/15 smw, changed e2c and c2e flag from 'pns' to 'haptix'
% updated with optional input mapname , default 'haptix' for passive gator.smw 9/17/15

if nargin > 2
    mapname = varargin{1};
else
    mapname = 'haptixActive'; % active gator
end

vin = vin(:);
switch mode
    case 'e2c'
        vout = 128*floor((vin-1)/100) + e2c(rem((vin-1),100)+1,mapname);
    case 'c2e'
        vout = 100*floor(vin/128) + c2e(rem(vin,128),mapname);
    case 'c2i'
        vout = 96*floor(vin/128) + rem(vin,128);
    case 'i2c'
        vout = 128*floor((vin-1)/96) + (rem((vin-1),96)+1);
    case 'e2i'
        vout = 96*floor((vin-1)/100) + e2c(rem((vin-1),100)+1,mapname);
    case 'i2e'
        vout = 100*(floor((vin-1)/96)) + c2e(rem((vin-1),96)+1,mapname);
end