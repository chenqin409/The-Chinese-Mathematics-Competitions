function bias = compute_pv_bias_q3(d, fcBaseDate, fcData, pvDates, pvData, window)

N = 144;
bias = zeros(N, 1);

idx = find(pvDates < d);
if numel(idx) < 8
    return;
end

idx = idx(max(1, end-window+1):end);

pred = NaN(numel(idx), N);
act  = NaN(numel(idx), N);

for j = 1:numel(idx)
    k = idx(j);
    dk = pvDates(k);

    iFc = days(dk - fcBaseDate) + 1;
    if iFc < 1 || iFc > numel(fcData)
        continue;
    end

    if iFc > 1
        prevFc = fcData{iFc-1};
    else
        prevFc = NaN(4,24);
    end

    fc0 = fcData{iFc};
    pred(j, :) = staircase_pv_fc(fc0(1,:), prevFc(1,:))';
    act(j, :)  = pvData(k, :);
end

valid = ~isnan(pred(:,1)) & ~isnan(act(:,1));
if nnz(valid) < 5
    return;
end

bias = mean(pred(valid,:) - act(valid,:), 1)';
end
