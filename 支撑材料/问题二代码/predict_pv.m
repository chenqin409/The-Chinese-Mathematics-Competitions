function pred = predict_pv(d, dates, data, method)
    pred = [];
    if strcmp(method, 'A')
        target = d - caldays(1);
        idx = find(dates == target, 1);
        if ~isempty(idx)
            pred = data(idx,:)';
            pred = set_night_zero(pred);
        end
    elseif strcmp(method, 'B')
        w = [0.30 0.25 0.20 0.15 0.07 0.02 0.01];
        pred = zeros(144,1);
        wSum = 0;
        for k = 1:7
            target = d - caldays(k);
            idx = find(dates == target, 1);
            if ~isempty(idx)
                pred = pred + w(k) * data(idx,:)';
                wSum = wSum + w(k);
            end
        end
        if wSum > 0
            pred = pred / wSum;
            pred = set_night_zero(pred);
        else
            pred = [];
        end
    end
end
