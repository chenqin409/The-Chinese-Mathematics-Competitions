function s = get_season(month_num)
    if ismember(month_num, [3 4 5])
        s = 1;
    elseif ismember(month_num, [6 7 8])
        s = 2;
    elseif ismember(month_num, [9 10 11])
        s = 3;
    else
        s = 4;
    end
end