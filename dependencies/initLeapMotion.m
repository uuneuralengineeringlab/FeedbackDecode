function ready = initLeapMotion()

try
    version = matleap_version;
    f1 = matleap_frame;
    pause(1)
    f2 = matleap_frame;
    if(f1.id == f2.id)
        ready = false;
    else
        ready = true;
    end
catch 
    ready = false;
end