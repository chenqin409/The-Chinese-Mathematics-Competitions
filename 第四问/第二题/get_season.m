function s = get_season(monthNum)
    if ismember(monthNum, [3 4 5])
        s = 1;
    elseif ismember(monthNum, [6 7 8])
        s = 2;
    elseif ismember(monthNum, [9 10 11])
        s = 3;
    else
        s = 4;
    end
end
