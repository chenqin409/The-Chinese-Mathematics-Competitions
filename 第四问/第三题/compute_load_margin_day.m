function margin = compute_load_margin_day(d, dates, data, method, q)

nCol = size(data,2);
idx = find(dates < d);
if numel(idx) < 8
    margin = zeros(nCol,1);
    return;
end

pred = NaN(numel(idx), nCol);
act  = data(idx, :);

seasons = arrayfun(@(x) get_season(x.Month), dates);
weekdays = weekday(dates);

for j = 1:numel(idx)
    k = idx(j);
    if strcmp(method, 'A')
        tgt = k - 7;
        if tgt >= 1 && days(dates(k) - dates(tgt)) == 7
            pred(j,:) = data(tgt,:);
        end
    else
        hist = idx(idx < k);
        m = hist(seasons(hist)==seasons(k) & weekdays(hist)==weekdays(k));
        if isempty(m)
            m = hist(weekdays(hist)==weekdays(k));
        end
        if ~isempty(m)
            pred(j,:) = mean(data(m,:),1);
        end
    end
end

valid = ~isnan(pred(:,1));
if nnz(valid) < 5
    margin = zeros(nCol,1);
    return;
end
err = max(pred(valid,:) - act(valid,:), 0);
margin = quantile(err, q)';
end
