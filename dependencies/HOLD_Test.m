function velEst = velDecoder(Z,model)
    
    b = model.b;
    h = model.h;
    velEst = model.w*[Z; ones(1,size(Z,2))];
    velEstOrig = velEst;
    velEst(velEstOrig<=-b) = -b+h;
    velEst(velEstOrig>-b&velEstOrig<=-h) = h+velEst(velEstOrig>-b&velEstOrig<=-h);%*...
        %b/(b-h)+b*h/(b-h);
    velEst(velEstOrig<0&velEstOrig>=-h) = 0;
    
    velEst(velEst<0) = velEst(velEst<0)*model.negVelScale;
    %velEst = velEst(1:end/2,:)-velEst(end/2+1:end,:);
    
end