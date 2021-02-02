function [pwind_st pwind_end nwind_st nwind_end avWindSize version] = findWindows(X,avWindSize)
%pwind_st is positive trials starting points
%_end is ending
%nwind_st is negative trials starting points

version = mfilename;
    ind = find(X>0);
    
    if ~isempty(ind)
    
    diffs = diff(ind);
    
    [jumps] = find(diffs>1);
    bigJump = find(diffs>200);
    numGroups = numel(jumps)+1;
    
    pwind_st(1) = ind(1);
    pwind_end = [];
    for i = 1:numel(jumps)
        if i ~= numel(jumps)
        if isempty(bigJump)||jumps(i+1)~=bigJump
            pwind_st = [pwind_st ind(jumps(i)+1)];
        end 
        end
        if isempty(bigJump)||jumps(i)~=bigJump
            pwind_end = [pwind_end ind(jumps(i))];
        end
    end
    pwind_st = [pwind_st ind(jumps(end)+1)];
    pwind_end = [pwind_end ind(end)];
    
    %pwind_st = pwind_st(2:end);
    %pwind_end = pwind_end(2:end);
    %pwind_st
    
    for i = 1:numel(pwind_st)
        windSize(i) = pwind_end(i)-pwind_st(i)+1;
    end
    if avWindSize == 0
        avWindSize = round(mean(windSize));
    end
    
    for i = 1:numel(pwind_st)
        if windSize(i)>avWindSize
            diffSize = windSize(i)-avWindSize;
            pwind_end(i) = pwind_end(i)-diffSize;
        elseif windSize(i)<avWindSize
            diffSize = avWindSize-windSize(i);
            pwind_end(i) = pwind_end(i)+diffSize;
        end
    end
    else
        pwind_st = [];
        pwind_end = [];
    end    
    
    ind = find(X<0);
    
    if ~isempty(ind)
    diffs = diff(ind);
    
    [jumps] = find(diffs>1);
    bigJump = find(diffs>200);
    numGroups = numel(jumps)+1;
    
    nwind_st(1) = ind(1);
    nwind_end = [];
    for i = 1:numel(jumps)
        if i ~= numel(jumps)
        if isempty(bigJump)||jumps(i+1)~=bigJump
            nwind_st = [nwind_st ind(jumps(i)+1)];
        end 
        end
        if isempty(bigJump)||jumps(i)~=bigJump
            nwind_end = [nwind_end ind(jumps(i))];
        end
    end
    nwind_st = [nwind_st ind(jumps(end)+1)];
    nwind_end = [nwind_end ind(end)];
    
    %nwind_st = nwind_st(2:end);
    %nwind_end = nwind_end(2:end);
    %pwind_st
    
    for i = 1:numel(nwind_st)
        windSize(i) = nwind_end(i)-nwind_st(i)+1;
    end
    if avWindSize == 0
        avWindSize = round(mean(windSize));
    end
    
    for i = 1:numel(nwind_st)
        if windSize(i)>avWindSize
            diffSize = windSize(i)-avWindSize;
            nwind_end(i) = nwind_end(i)-diffSize;
        elseif windSize(i)<avWindSize
            diffSize = avWindSize-windSize(i);
            nwind_end(i) = nwind_end(i)+diffSize;
        end
    end
    else
        nwind_st = [];
        nwind_end = [];
    end
    
%     ind = find(X<0);
%     
%     if ~isempty(ind)
%     diffs = diff(ind);
%     
%     [jumps] = find(diffs>1);
%     numGroups = numel(jumps)+1;
%     
%     nwind_st(1) = ind(1);
%     nwind_st = [nwind_st ind(jumps+1)];
%     nwind_end = ind(jumps);
%     nwind_end = [nwind_end ind(end)];
%     
%     clear windSize
%     for i = 1:numel(nwind_st)
%         windSize(i) = nwind_end(i)-nwind_st(i)+1;
%     end
%     if avWindSize == 0
%         avWindSize = round(mean(windSize));
%     end
%     
%     for i = 1:numel(nwind_st)
%         if windSize(i)>avWindSize
%             diffSize = windSize(i)-avWindSize;
%             nwind_end(i) = nwind_end(i)-diffSize;
%         elseif windSize(i)<avWindSize
%             diffSize = avWindSize-windSize(i);
%             nwind_end(i) = nwind_end(i)+diffSize;
%         end
%     end
%     else
%         nwind_st = [];
%         nwind_end = [];
%     end
end