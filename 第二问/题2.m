clear; clc; close all;

N = 144; dt = 1/6; eta = 0.9;
soc0 = 6000; soc_Min = 1200; soc_Max = 10800; p_Max = 5000;
qSafe = 0.93;

predStart = datetime(2025,2,1);
predEnd = datetime(2025,12,31);

price_Table = readtable('附件1.xlsx', 'VariableNamingRule', 'preserve');
price = price_Table{:, 2}; price = price(:);

loadTable = readtable('附件2.xlsx', 'Sheet', '小区负载', ...
    'VariableNamingRule', 'preserve');
loadDates = dateshift(datetime(loadTable{:,1}), 'start', 'day');
loadData = loadTable{:, 2:145};

pvTable = readtable('附件2.xlsx', 'Sheet', '光伏发电实际功率', ...
    'VariableNamingRule', 'preserve');
pvDates = dateshift(datetime(pvTable{:,1}), 'start', 'day');
pvData = pvTable{:, 2:145};

fprintf('数据加载完成\n');
fprintf('电价: %d 个点\n', length(price));
fprintf('负载: %d 天 × %d 时段\n', size(loadData,1), size(loadData,2));
fprintf('光伏: %d 天 × %d 时段\n', size(pvData,1), size(pvData,2));

predDates = (predStart:caldays(1):predEnd)';
nDays = length(predDates);
fprintf('预测天数: %d\n', nDays);

combos = {
    '组合1: 负载A(上周同期) + 光伏A(前日同期)', 'A', 'A';
    '组合2: 负载A(上周同期) + 光伏B(近7天加权)', 'A', 'B';
    '组合3: 负载B(同季度同星期) + 光伏A(前日同期)', 'B', 'A';
    '组合4: 负载B(同季度同星期) + 光伏B(近7天加权)', 'B', 'B';
    };

comboResults = cell(4,1);
comboCosts = zeros(4,3);

for c = 1:4
    comboName = combos{c,1};
    loadMethod = combos{c,2};
    pvMethod = combos{c,3};
    fprintf('\n=== %s ===\n', comboName);

    results = struct([]);
    costPlan = 0; costEmg = 0;
    socNow = soc0;

    for i = 1:nDays
        d = predDates(i);

        loadPred = predict_load(d, loadDates, loadData, loadMethod);
        pvPred = predict_pv(d, pvDates, pvData, pvMethod);
        if isempty(loadPred) || isempty(pvPred)
            continue;
        end

        deltaPv = compute_pv_margin_day(d, pvDates, pvData, pvMethod, qSafe);
        deltaLd = compute_load_margin_day(d, loadDates, loadData, loadMethod, qSafe);

        loadPlan = loadPred + deltaLd;
        pvPlan = max(pvPred - deltaPv, 0);

        if i < nDays
            socEndMin = soc0;
        else
            socEndMin = 0;
        end

        [pBuy, pCh, pDis, soc] = optimize_daily(...
            loadPlan, pvPlan, price, N, dt, eta, socNow, ...
            soc_Min, soc_Max, p_Max, socEndMin);
        if isempty(pBuy)
            fprintf(' 优化失败: %s\n', datestr(d));
            continue;
        end

        idx = find(loadDates == d, 1);
        if isempty(idx)
            continue;
        end
        loadAct = loadData(idx,:)';
        pvAct = pvData(idx,:)';

        [emg, dayCostPlan, dayCostEmg, socHist] = simulate_realtime(...
            pBuy, pCh, pDis, loadAct, pvAct, price, dt, ...
            socNow, eta, soc_Min, soc_Max, p_Max);

        soc(end) = socHist(end);

        results(end+1).date = d;
        results(end).pBuy = pBuy;
        results(end).pCh = pCh;
        results(end).pDis = pDis;
        results(end).soc = soc;
        results(end).emg = emg;
        results(end).costPlan = dayCostPlan;
        results(end).costEmg = dayCostEmg;
        results(end).socInit = socNow;

        costPlan = costPlan + dayCostPlan;
        costEmg = costEmg + dayCostEmg;
        socNow = socHist(end);

        if mod(i,50)==0 || i==1
            fprintf(' [%d/%d] %s 计划费=%.0f 紧急费=%.0f SOC=%.1f\n', ...
                i, nDays, datestr(d), dayCostPlan, dayCostEmg, socNow);
        end
    end

    comboResults{c} = results;
    comboCosts(c,:) = [costPlan, costEmg, costPlan + costEmg];
    fprintf('总计: 计划费=%.0f 紧急费=%.0f 总费=%.0f\n', ...
        costPlan, costEmg, costPlan + costEmg);
end

[~, bestIdx] = min(comboCosts(:,3));
fprintf('\n=== 所有组合对比 ===\n');
for c = 1:4
    fprintf('%-50s 计划费=%10.0f 紧急费=%10.0f 总费=%10.0f\n', ...
        combos{c,1}, comboCosts(c,1), comboCosts(c,2), comboCosts(c,3));
end
fprintf('\n★ 最优组合: %s\n', combos{bestIdx,1});
fprintf(' 总成本: %.0f 元\n', comboCosts(bestIdx,3));

write_result2(comboResults{bestIdx}, N, dt);
fprintf('\n完成!\n');
