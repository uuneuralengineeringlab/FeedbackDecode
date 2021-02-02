function shimmerunix_ms = shimmerUnixTimeConversion_ms()
    import java.util.TimeZone
    
    n = now;
    dt = datetime(n, 'ConvertFrom', 'datenum' ,'TimeZone',char(TimeZone.getDefault().getID())); % need to convert for time zones
    shimmerunix_ms = posixtime(dt)*1000; % convert to ms

    
%     n = now;
%     ds = datestr(n);
%     dt = datetime(ds,'TimeZone',char(TimeZone.getDefault().getID())); % need to convert for time zones
%     shimmerunix_ms = posixtime(dt)*1000; % convert to ms

%     shimmerunix_ms = 24*3600*1000 * (datenum(clock)-datenum('01-Jan-1970')) - (1*3600*1000);
