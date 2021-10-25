function [a,b,g] = R2abg(R,joint)
% This function takes in a rotation matrix and returns joint angles
% a is alpha, b is beta, and g is gamma; all angles
% Joint 1 is shoulder, 2 is elbow, and 3 is wrist

a = zeros(size(R,3),1);
b = a;
g = a;

% After much discussion, it was decided that by always choosing positive 
% square root to give beta, we would elminate possibilities of NaN values 
% and keep from any discontinuities. There does not need to be any 
% constraints listed, nor any switch statement between two solutions.

for i = 1:size(R,3)
    
    if joint == 1   % SHOULDER JOINT
        
% We only want to extract one possible set. It is
% not always intuitive to think about the shoulder joint angles. In some
% orientations, there are ways to get to those orientations that do not
% make much physical sense, yet they are solutions. By constraining each of
% the DOF, you add risk that there is no way to obtain the orientation, and
% thus you will get NaN. We will choose only one set by choosing the positive
% value of the square root.
        
        % YXY Euler angle sequence
%         b(i) = atan2(sqrt(R(2,1,i)^2 + R(2,3,i)^2), R(2,2,i));
%         a(i) = atan2(R(1,2,i)/sin(b(i)), R(3,2,i)/sin(b(i)));
%         g(i) = atan2(R(2,1,i)/sin(b(i)), -R(2,3,i)/sin(b(i)));

        % ZXY Euler angle sequence
        a(i) = atan2(R(2,3,i),R(3,3,i));
        b(i) = -asin(R(1,3,i));
        g(i) = atan2(R(1,2,i),R(1,1,i));
%        b(i) = atan2(R(3,2,i), sqrt(R(3,1,i)^2 + R(3,3,i)^2));
%        a(i) = atan2(-R(1,2,i)/cos(b(i)), R(2,2,i)/cos(b(i)));
%        g(i) = atan2(-R(3,1,i)/cos(b(i)), R(3,3,i)/cos(b(i)));
 
    elseif (joint == 2 || joint == 3)   % ELBOW/FOREARM OR WRIST JOINT
        b(i) = atan2(R(3,2,i), sqrt(R(3,1,i)^2 + R(3,3,i)^2));
        a(i) = atan2(-R(1,2,i)/cos(b(i)), R(2,2,i)/cos(b(i)));
        g(i) = atan2(-R(3,1,i)/cos(b(i)), R(3,3,i)/cos(b(i)));
        
    end
    
end