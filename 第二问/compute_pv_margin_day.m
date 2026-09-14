function margin = compute_pv_margin_day(d, date, data, method, q)

nCol = size(data,2);
idx = find(date < d);
if numel(idx) < 8
    margin = zeros(nCol,1);
    return;
end

pred = NaN(numel(idx), nCol);
act  = data(idx, :);

if strcmp(method, 'A')
    for j = 1:numel(idx)
        k = idx(j);
        tgt = k - 1;
        if tgt >= 1 && days(date(k) - date(tgt)) == 1
            pred(j,:) = set_night_zero(data(tgt,:)');
        end
    end
else
    w = [0.30 0.25 0.20 0.15 0.07 0.02 0.01];
    for j = 1:numel(idx)
        k = idx(j);
        acc = zeros(1, nCol); wSum = 0;
        for m = 1:7
            tgt = k - m;
            if tgt >= 1
                acc = acc + w(m)*data(tgt,:);
                wSum = wSum + w(m);
            end
        end
        if wSum > 0
            pred(j,:) = set_night_zero(acc / wSum);
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
