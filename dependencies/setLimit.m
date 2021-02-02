function valout = setLimit(valin,lim)
    valout = min(max(valin,lim(1)),lim(2));
return