function pv = staircase_pv_fc_stage(fc24, tStart)

N = 144;
pv = zeros(N - tStart + 1, 1);

for h = 1:24
    absStart = tStart + (h-1)*6;
    for s = 0:5
        target = absStart + s;
        if target >= tStart && target <= N
            pv(target - tStart + 1) = max(fc24(h), 0);
        end
    end
end
end
