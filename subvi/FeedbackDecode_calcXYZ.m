function XYZ = FeedbackDecode_calcXYZ(JAngle,COM,RotAxis,SphereOff)

% JAngle is a vector of interpolated joint angles for a specific movement
% in radians. COM is a matrix where the rows are XYZ coordinates and
% columns are individual components for a specific movement (including the
% distal segment -> #cols is length(JAngle)+1). RotAxis is the XYZ
% orientation of each component (joint) in 3D space with rows as XYZ and
% columns as joint (#cols is length(JAngle)). SphereOff is a XYZ offset
% vector with respect to the distal segment so sphere is located at
% fingertip. XYZ is the final position of the sphere.
%
% JAngle = [J1;J2;J3]; joint angles in radians
% COM = [[C1X;C1Y;C1Z],[C2X;C2Y;C2Z],[C3X;C3Y;C3Z],[CdX;CdY;CdZ]]; C1 is inboard COM for J1, Cd is COM for distal segment
% RotAxis = [[R1X;R1Y;R1Z],[R2X;R2Y;R2Z],[R3X;R3Y;R3Z]; 3D position of each joint
% SphereOff = [SdX;SdY;SdZ]; Offset with respect to COM of distal segment in meters

T = eye(4,4); T(1:3,4) = COM(:,1);
for k=1:size(RotAxis,2)    
    uvw = RotAxis(:,k);
    tensorUVW = [uvw(1)^2,uvw(1)*uvw(2),uvw(1)*uvw(3);uvw(1)*uvw(2),uvw(2)^2,uvw(2)*uvw(3);uvw(1)*uvw(3),uvw(2)*uvw(3),uvw(3)^2];
    crossUVW = [0,-uvw(3),uvw(2);uvw(3),0,-uvw(1);-uvw(2),uvw(1),0];
    r = eye(3,3)*cos(JAngle(k)) + sin(JAngle(k))*crossUVW + (1-cos(JAngle(k)))*tensorUVW;
    R = eye(4,4); R(1:3,1:3) = r;
    O = eye(4,4); O(1:3,4) = COM(:,k+1)';
    if k==size(RotAxis,2)        
        D = eye(4,4); D(1:3,4) = SphereOff;
        T = T*R*O*D;
    else
        T = T*R*O;
    end
end
XYZ = T(1:3,4);