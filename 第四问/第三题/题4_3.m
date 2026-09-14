clear; clc; close all;
if exist('result4-3.xlsx', 'file'), delete('result4-3.xlsx'); end

N = 144; dt = 1/6; eta = 0.9;
soc0 = 6000; socMin = 1200; socMax = 10800; pMax = 5000;
qSafe = 0.95;
usePvMargin = true;
predStart = datetime(2025,2,1);
predEnd   = datetime(2025,12,31);


price4Table = readtable('附件4.xlsx', 'VariableNamingRule', 'preserve');
price4Dates = dateshift(datetime(price4Table{:,1}), 'start', 'day');
price4Data  = price4Table{:, 2:145};
fprintf('实时电价: %d 天 × %d 时段\n', size(price4Data,1), size(price4Data,2));

loadTable = readtable('附件2.xlsx', 'Sheet', '小区负载', 'VariableNamingRule', 'preserve');
loadDates = dateshift(datetime(loadTable{:,1}), 'start', 'day');
loadData  = loadTable{:, 2:145};

pvTable = readtable('附件2.xlsx', 'Sheet', '光伏发电实际功率', 'VariableNamingRule', 'preserve');
pvDates = dateshift(datetime(pvTable{:,1}), 'start', 'day');
pvData  = pvTable{:, 2:145};

fcRaw = readmatrix('附件3.xlsx');
if isempty(fcRaw), error('读取附件3失败'); end
nFcRows = size(fcRaw, 1);
nFcDays = floor(nFcRows / 4);
fcData = cell(nFcDays, 1);
for d0 = 1:nFcDays
    rows = (d0-1)*4 + (1:4);
    fcData{d0} = fcRaw(rows, end-23:end);
end
fcBaseDate = datetime(2025,1,1);
fcDates = (predStart:caldays(1):predEnd)';
nDays = length(fcDates);


dayResults = cell(nDays, 1);
totalCost = 0;
socNow = soc0;
nAdjusted = 0;

diagPlanTotal = 0; diagNeedTotal = 0; diagEmgTotal = 0;
diagEmgCost = 0; diagPlanCost = 0; diagAdjCost = 0;
diagNoAdjCost = 0; diagPvBiasSum = 0; diagLdBiasSum = 0;
diagCnt = 0;

for i = 1:nDays
    d = fcDates(i);
    iFc = days(d - fcBaseDate) + 1;
    if iFc < 1 || iFc > nFcDays, continue; end
    fc = fcData{iFc};
    if iFc > 1
        prevFc = fcData{iFc-1};
    else
        prevFc = NaN(4, 24);
    end

    idxP = find(price4Dates == d, 1);
    if isempty(idxP)
        fprintf(' [跳过] %s 附件4无电价\n', datestr(d));
        continue;
    end
    price = price4Data(idxP, :)';

    loadPredRaw = predict_load_q3(d, loadDates, loadData);
    if isempty(loadPredRaw), continue; end

    idxAct = find(loadDates == d, 1);
    if ~isempty(idxAct)
        loadAct = loadData(idxAct, :)';
        pvAct   = pvData(idxAct, :)';
    else
        loadAct = loadPredRaw;
        pvAct   = staircase_pv_fc(fc(1,:), prevFc(1,:));
    end
    isLastDay = (d == predEnd);

    deltaLd = compute_load_margin_day(d, loadDates, loadData, 'A', qSafe);
    if usePvMargin
        deltaPv = compute_pv_bias_q3(d, fcBaseDate, fcData, pvDates, pvData, 30);
    else
        deltaPv = zeros(N, 1);
    end

    pvPlanRaw = staircase_pv_fc(fc(1,:), prevFc(1,:));
    pvPlan = max(pvPlanRaw - deltaPv, 0);

    nightMask = (pvPlanRaw < 50);
    deltaLdUse = deltaLd;
    deltaLdUse(~nightMask) = 0;
    loadPred = loadPredRaw + deltaLdUse;

    [pPlan, ~, ~, ~] = solve_stage0(...
        loadPred, pvPlan, price, N, dt, eta, socNow, ...
        socMin, socMax, pMax, isLastDay);
    if isempty(pPlan)
        fprintf(' [优化失败] %s 阶段0\n', datestr(d));
        continue;
    end
    pEff = pPlan;

    [~,~,~,soc36] = simulate_realtime3(pPlan(1:36), ...
        loadAct(1:36), pvAct(1:36), price(1:36), 36, dt, eta, ...
        socNow, socMin, socMax, pMax);
    socAt36 = soc36(end);

    pv6Raw = staircase_pv_fc_stage(fc(2,:), 37);
    pv6 = max(pv6Raw - deltaPv(37:N), 0);
    nightMask6 = (pv6Raw < 50);
    deltaLd6 = deltaLd(37:N);
    deltaLd6(~nightMask6) = 0;
    loadPred6 = loadPredRaw(37:N) + deltaLd6;

    [pAdj6, ~, ~, ~, ~, ~] = solve_stageK(...
        loadPred6, pv6, price(37:N), N-36, dt, eta, socAt36, ...
        socMin, socMax, pMax, pPlan(37:N), isLastDay);
    if ~isempty(pAdj6), pEff(37:N) = pAdj6; end

    pUpto72 = [pPlan(1:36); pEff(37:72)];
    [~,~,~,soc72] = simulate_realtime3(pUpto72, ...
        loadAct(1:72), pvAct(1:72), price(1:72), 72, dt, eta, ...
        socNow, socMin, socMax, pMax);
    socAt72 = soc72(end);

    pv12Raw = staircase_pv_fc_stage(fc(3,:), 73);
    pv12 = max(pv12Raw - deltaPv(73:N), 0);
    nightMask12 = (pv12Raw < 50);
    deltaLd12 = deltaLd(73:N);
    deltaLd12(~nightMask12) = 0;
    loadPred12 = loadPredRaw(73:N) + deltaLd12;

    [pAdj12, ~, ~, ~, ~, ~] = solve_stageK(...
        loadPred12, pv12, price(73:N), N-72, dt, eta, socAt72, ...
        socMin, socMax, pMax, pPlan(73:N), isLastDay);
    if ~isempty(pAdj12), pEff(73:N) = pAdj12; end

    pUpto108 = [pPlan(1:36); pEff(37:72); pEff(73:108)];
    [~,~,~,soc108] = simulate_realtime3(pUpto108, ...
        loadAct(1:108), pvAct(1:108), price(1:108), 108, dt, eta, ...
        socNow, socMin, socMax, pMax);
    socAt108 = soc108(end);

    pv18Raw = staircase_pv_fc_stage(fc(4,:), 109);
    pv18 = max(pv18Raw - deltaPv(109:N), 0);
    nightMask18 = (pv18Raw < 50);
    deltaLd18 = deltaLd(109:N);
    deltaLd18(~nightMask18) = 0;
    loadPred18 = loadPredRaw(109:N) + deltaLd18;

    [pAdj18, ~, ~, ~, ~, ~] = solve_stageK(...
        loadPred18, pv18, price(109:N), N-108, dt, eta, socAt108, ...
        socMin, socMax, pMax, pPlan(109:N), isLastDay);
    if ~isempty(pAdj18), pEff(109:N) = pAdj18; end

    [emg, pChSim, pDisSim, socTrace, costEmg] = simulate_realtime3(...
        pEff, loadAct, pvAct, price, N, dt, eta, socNow, ...
        socMin, socMax, pMax);

    [emgNoAdj, pChNoAdj, pDisNoAdj, socNoAdj, costEmgNoAdj] = ...
        simulate_realtime3(pPlan, loadAct, pvAct, price, N, dt, eta, ...
        socNow, socMin, socMax, pMax);

    costPlan = sum(price .* pPlan) * dt;
    dP = pEff - pPlan;
    costAdjWith = sum(1.5*price.*max(dP,0) + 0.5*price.*max(-dP,0)) * dt;
    costTotalWith = costPlan + costAdjWith + costEmg;
    costTotalNo   = costPlan + costEmgNoAdj;

    if costTotalWith <= costTotalNo
        costAdjFinal  = costAdjWith;
        costEmgFinal  = costEmg;
        pChUse = pChSim; pDisUse = pDisSim;
        socUse  = socTrace; emgUse = emg;
        costTotal = costTotalWith;
        usedAdj = true;
    else
        pEff = pPlan;
        costAdjFinal = 0;
        costEmgFinal = costEmgNoAdj;
        pChUse = pChNoAdj; pDisUse = pDisNoAdj;
        socUse  = socNoAdj;  emgUse  = emgNoAdj;
        costTotal = costTotalNo;
        usedAdj = false;
    end
    totalCost = totalCost + costTotal;
    netAdj = pEff - pPlan;
    if usedAdj, nAdjusted = nAdjusted + 1; end

    dayResults{i}.date = d;
    dayResults{i}.pPlan = pPlan;
    dayResults{i}.pEff = pEff;
    dayResults{i}.netAdj = netAdj;
    dayResults{i}.pCh = pChUse;
    dayResults{i}.pDis = pDisUse;
    dayResults{i}.emg = emgUse;
    dayResults{i}.socTrace = socUse;
    dayResults{i}.costPlan = costPlan;
    dayResults{i}.costAdj = costAdjFinal;
    dayResults{i}.costEmg = costEmgFinal;
    dayResults{i}.costTotal = costTotal;
    dayResults{i}.socInit = socNow;
    socNow = socUse(end);

    planKwh = sum(pPlan) * dt;
    needKwh = sum(loadAct - pvAct) * dt;
    emgKwh  = sum(emgUse) * dt;
    pvBiasDay = mean(pvPlan(43:102) - pvAct(43:102));
    ldBiasDay = mean(loadPred - loadAct);
    diagPlanTotal = diagPlanTotal + planKwh;
    diagNeedTotal = diagNeedTotal + needKwh;
    diagEmgTotal  = diagEmgTotal + emgKwh;
    diagEmgCost   = diagEmgCost + costEmgFinal;
    diagPlanCost  = diagPlanCost + costPlan;
    diagAdjCost   = diagAdjCost + costAdjFinal;
    diagNoAdjCost = diagNoAdjCost + costEmgNoAdj;
    diagPvBiasSum = diagPvBiasSum + pvBiasDay;
    diagLdBiasSum = diagLdBiasSum + ldBiasDay;
    diagCnt = diagCnt + 1;

    if mod(i,20)==0 || i==1 || i==nDays
        if usedAdj, flagStr = '调整'; else, flagStr = '不调整'; end
        fprintf(' [%d/%d] %s 计划=%.0f 调整=%.0f 紧急=%.0f 总=%.0f SOC=%.1f %s\n', ...
            i, nDays, datestr(d), costPlan, costAdjFinal, ...
            costEmgFinal, costTotal, socNow, flagStr);
    end
end


fprintf('总费用: %.0f 元\n', totalCost);


fprintf('统计天数: %d\n', diagCnt);
fprintf('方案A被选中: %d 天 (%.1f%%)\n', nAdjusted, 100*nAdjusted/max(diagCnt,1));
fprintf('计划购电量总计: %.0f kWh\n', diagPlanTotal);
fprintf('实际需求总计: %.0f kWh\n', diagNeedTotal);
fprintf('差额（计划-需求）: %.0f kWh\n', diagPlanTotal - diagNeedTotal);
fprintf('紧急购电量总计: %.0f kWh (%.2f%%)\n', ...
    diagEmgTotal, 100*diagEmgTotal/max(diagNeedTotal,1));
fprintf('计划费: %.0f 元\n', diagPlanCost);
fprintf('调整费: %.0f 元\n', diagAdjCost);
fprintf('实际总费: %.0f 元\n', totalCost);
fprintf('光伏预报偏差: %.2f kW\n', diagPvBiasSum / max(diagCnt,1));
fprintf('负载预报偏差: %.2f kW\n', diagLdBiasSum / max(diagCnt,1));

write_result3(dayResults, N, dt, 'result4-3.xlsx');
fprintf('result4-3.xlsx 已保存\n');
