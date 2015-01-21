function [ ret_vals ] = boltz( values, temp)
%BOLTZ Summary of this function goes here
%   Detailed explanation goes here
e_v = exp(values / temp);

ret_vals = e_v ./ sum(e_v);

end

