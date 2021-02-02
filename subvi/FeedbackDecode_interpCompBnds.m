function JAngle = FeedbackDecode_interpCompBnds(CompBnds,Val)

% CompBnds is a matrix with rows as different joints and columns as
% low-to-high bounds for each joint in degrees. Val is a scalar from -1 to
% 1. JAngle is a vector of interpolated joint angles in radians.

JAngle = ((CompBnds(:,2)-CompBnds(:,1))/(-2/(-1-Val)) + CompBnds(:,1))*pi/180;