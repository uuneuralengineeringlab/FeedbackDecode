function [rotation_matrices] = quat2rnew(q)
%Input: nx4 matrix containing quaternions
%Output: 3x3xn matrix containing 3x3 rotation matrices

for i=1:size(q,1)
    R(:,:,i) = [1-2*q(i,3)^2-2*q(i,4)^2, 2*q(i,2)*q(i,3)-2*q(i,1)*q(i,4), 2*q(i,2)*q(i,4)+2*q(i,1)*q(i,3);
                2*q(i,2)*q(i,3)+2*q(i,1)*q(i,4), 1-2*q(i,2)^2-2*q(i,4)^2, 2*q(i,3)*q(i,4)-2*q(i,1)*q(i,2);
                2*q(i,2)*q(i,4)-2*q(i,1)*q(i,3), 2*q(i,3)*q(i,4)+2*q(i,1)*q(i,2), 1-2*q(i,2)^2-2*q(i,3)^2];
end

rotation_matrices = R;
end