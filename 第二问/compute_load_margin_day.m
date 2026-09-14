function Delta = compute_load_margin_day(d, date, data, method, q)
Ncol = size(data,2);
idx = find(date < d);
if numel(idx) < 8
    Delta = zeros(Ncol,1);
    return;
end

predd = NaN(numel(idx), Ncol);
act  = data(idx, :);

all_season = arrayfun(@(x) get_season(x.Month), date);
wd_all = weekday(date);

for j = 1:numel(idx)
    k = idx(j);
    if strcmp(method, 'A')      
        tgt = k - 7;
        if tgt >= 1 && days(date(k) - date(tgt)) == 7
            predd(j,:) = data(tgt,:);
        end
    else                       
        hit = idx(idx < k);  
        m = hit(all_season(hit)==all_season(k) & wd_all(hit)==wd_all(k));
        if isempty(m)
            m = hit(wd_all(hit)==wd_all(k));
        end
        if ~isempty(m)
            predd(j,:) = mean(data(m,:),1);
        end
    end
end

valid = ~isnan(predd(:,1));
if nnz(valid) < 5
    Delta = zeros(Ncol,1);
    return;
end
err = max(predd(valid,:) - act(valid,:), 0);
Delta = quantile(err, q)';
end
