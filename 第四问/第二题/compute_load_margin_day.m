function margin = compute_load_margin_day(d, date, data, method, q)
nCol = size(data,2);
idx = find(date < d);
if numel(idx) < 8
    margin = zeros(nCol,1);
    return;
end

pred = NaN(numel(idx), nCol);
act  = data(idx, :);

seasons = arrayfun(@(x) get_season(x.Month), date);
weekdays = weekday(date);

for j = 1:numel(idx)
    k = idx(j);
    if strcmp(method, 'A')      
        tgt = k - 7;
        if tgt >= 1 && days(date(k) - date(tgt)) == 7
            pred(j,:) = data(tgt,:);
        end
    else                       
        hit = idx(idx < k);  
        m = hit(seasons(hit)==seasons(k) & weekdays(hit)==weekdays(k));
        if isempty(m)
            m = hit(weekdays(hit)==weekdays(k));
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
