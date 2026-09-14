function write_result2(results, N, dt, filename)
if nargin < 4
    filename = 'result2.xlsx';
end

nDays = length(results);
if nDays == 0
    warning('没有结果可写入');
    return;
end

timeLabels = cell(1, N);
for t = 1:N
    startMin = (t-1)*10; endMin = t*10;
    sh = floor(startMin/60); sm = mod(startMin,60);
    eh = floor(endMin/60);   em = mod(endMin,60);
    if t == N
        timeLabels{t} = sprintf('%d:%02d-%d:00+1', sh, sm, eh);
    else
        timeLabels{t} = sprintf('%d:%02d-%d:%02d', sh, sm, eh, em);
    end
end

header1 = [{'日期\时间'}, timeLabels(2:end), timeLabels(1), ...
    {'购电总量(kWh)'}, {'购电成本(元)'}];
writecell(header1, filename, 'Sheet', '计划购电量', 'Range', 'A1');

sheet1Rows = cell(nDays, 147);
for i = 1:nDays
    r = results(i);
    sheet1Rows{i,1} = datestr(r.date, 'yyyy-mm-dd');
    buyRotated = [r.pBuy(2:end); r.pBuy(1)];
    for t = 1:N
        sheet1Rows{i, t+1} = round(buyRotated(t), 4);
    end
    sheet1Rows{i,146} = round(sum(r.pBuy) * dt, 4);
    sheet1Rows{i,147} = round(r.dayCostPlan, 4);
end
writecell(sheet1Rows, filename, 'Sheet', '计划购电量', 'Range', 'A2');

header2 = {'日期', '时间段', '充电量', '放电量', '时刻', '储电量'};
writecell(header2, filename, 'Sheet', '充放电量', 'Range', 'A1');

periodRanges = [1 24; 25 48; 49 72; 73 96; 97 120; 121 144];
periodLabels = {'0:00-4:00', '4:00-8:00', '8:00-12:00', ...
    '12:00-16:00', '16:00-20:00', '20:00-24:00'};

nRows2 = nDays * 6;
sheet2Rows = cell(nRows2, 6);
row = 1;
for i = 1:nDays
    r = results(i);
    dateStr = datestr(r.date, 'yyyy-mm-dd');
    for p = 1:6
        rng = periodRanges(p,1):periodRanges(p,2);
        chVal  = sum(r.pCh(rng))  * dt;
        disVal = sum(r.pDis(rng)) * dt;
        if p == 1
            sheet2Rows{row,1} = dateStr;
        else
            sheet2Rows{row,1} = '';
        end
        sheet2Rows{row,2} = periodLabels{p};
        sheet2Rows{row,3} = round(chVal, 4);
        sheet2Rows{row,4} = round(disVal, 4);
        if p == 1
            sheet2Rows{row,5} = '00:00:00';
            sheet2Rows{row,6} = round(r.socInit, 4);
        elseif p == 2
            sheet2Rows{row,5} = '24:00';
            sheet2Rows{row,6} = round(r.soc(end), 4);
        else
            sheet2Rows{row,5} = '';
            sheet2Rows{row,6} = '';
        end
        row = row + 1;
    end
end
writecell(sheet2Rows, filename, 'Sheet', '充放电量', 'Range', 'A2');

header3 = {'日期', '购电时间段', '购电量'};
writecell(header3, filename, 'Sheet', '紧急购电量', 'Range', 'A1');

nEmgRows = 0;
for i = 1:nDays
    nEmgRows = nEmgRows + sum(results(i).emg > 0.01);
end

if nEmgRows == 0
    sheet3Rows = {'无', '无', 0};
else
    sheet3Rows = cell(nEmgRows, 3);
    row = 1;
    for i = 1:nDays
        r = results(i);
        dateStr = datestr(r.date, 'yyyy-mm-dd');
        firstOfDay = true;
        for t = 1:N
            if r.emg(t) > 0.01
                if firstOfDay
                    sheet3Rows{row,1} = dateStr;
                    firstOfDay = false;
                else
                    sheet3Rows{row,1} = '';
                end
                sheet3Rows{row,2} = timeLabels{t};
                sheet3Rows{row,3} = round(r.emg(t) * dt, 4);
                row = row + 1;
            end
        end
    end
end
writecell(sheet3Rows, filename, 'Sheet', '紧急购电量', 'Range', 'A2');

fprintf('%s 已保存（%d 天）\n', filename, nDays);
end
