function pred = predict_load_q3(targetDate, histDates, histData)
    N = size(histData, 2);
    refDate = targetDate - days(7);
    idx = find(histDates == refDate, 1);
    if isempty(idx)
        pred = [];
        return;
    end
    pred = histData(idx, :)';
end
