function list = getElectrodesInRadius(acceptanceDistanceUsed,center)


numberRowsColumns = 10;
roundingFix = 0.9*mod( sqrt( 1*1 + (numberRowsColumns-1)^2 ),1 );
numberChannels = 96;

electrodeZeroBased = arrayWiringConversion( (1:96),'TDT1', 'ConnectorChannel', 'Electrode' ) - 1;

centerX = mod(center,numberRowsColumns);
centerY = fix(center/numberRowsColumns);

electrodeZeroBasedX = mod( electrodeZeroBased , numberRowsColumns );
electrodeZeroBasedY = fix( electrodeZeroBased / numberRowsColumns );

for n = 1:numberChannels
    electrodeElectrodeDistance(n) = sqrt( ...
        ( ( centerX - electrodeZeroBasedX(n) ).^2 ) + ...
        ( ( centerY - electrodeZeroBasedY(n) ).^2 ) ...
        );
    
    
end;

z = find( electrodeElectrodeDistance <= acceptanceDistanceUsed );
if( isempty( z ) )
    warning( 'softwareReferenceMatrix:noElectrodes', ...
        'No electrodes within distance\n' );
    list = [];
else
    list = setdiff(electrodeZeroBased(z),center);
end;

end