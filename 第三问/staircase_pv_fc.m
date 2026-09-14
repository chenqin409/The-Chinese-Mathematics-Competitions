function pv = staircase_pv_fc(fc24, fc24Prev)

N = 144;
pv = zeros(N, 1);

if ~isempty(fc24Prev) && ~isnan(fc24Prev(24))
    pv(1:6) = max(fc24Prev(24), 0);
end

for h = 1:24
    startIdx = (h-1)*6 + 7;
    endIdx   = min(startIdx + 5, N);
    if startIdx <= N
        pv(startIdx:endIdx) = max(fc24(h), 0);
    end
end
end
