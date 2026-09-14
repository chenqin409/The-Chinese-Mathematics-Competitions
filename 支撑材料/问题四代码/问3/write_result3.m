function write_result3(dayResults, N, dt, filename)

if nargin < 4
    filename = 'result3.xlsx';
end

valid   = ~cellfun(@isempty, dayResults);
results = dayResults(valid);
nDays   = length(results);

if nDays == 0
    warning('没有结果可写入');
    return;
end

% ========== 生成144个时间标签 ==========
timeLabels = cell(1, N);
for t = 1:N
    startMin = (t-1)*10;
    endMin   = t*10;
    sh = floor(startMin/60); sm = mod(startMin, 60);
    eh = floor(endMin/60);   em = mod(endMin, 60);
    timeLabels{t} = sprintf('%d:%02d-%d:%02d', sh, sm, eh, em);
end

if exist(filename, 'file')
    delete(filename);
end

%% ---------- Sheet1: 计划购电量 ----------
% ★ 列结构：1列日期 + N列时间 + 2列汇总 = N+3列
header1 = cell(1, N + 3);
header1{1} = '日期\时间';
for t = 1:N, header1{t+1} = timeLabels{t}; end
header1{N+2} = '全天购电量';
header1{N+3} = '全天购电费';
writecell(header1, filename, 'Sheet', '计划购电量', 'Range', 'A1');

sheet1Rows = cell(nDays, N + 3);
for i = 1:nDays
    r = results{i};
    sheet1Rows{i,1} = datestr(r.date, 'yyyy-mm-dd');
    for t = 1:N
        sheet1Rows{i, t+1} = round(r.pPlan(t) * dt, 4);
    end
    sheet1Rows{i,N+2} = round(sum(r.pPlan) * dt, 4);
    sheet1Rows{i,N+3} = round(r.costPlan, 4);
end
writecell(sheet1Rows, filename, 'Sheet', '计划购电量', 'Range', 'A2');

%% ---------- Sheet2: 调整购电量 ----------
header2 = cell(1, N + 3);
header2{1} = '日期\时间';
for t = 1:N, header2{t+1} = timeLabels{t}; end
header2{N+2} = '全天购电量';
header2{N+3} = '全天购电费';
writecell(header2, filename, 'Sheet', '调整购电量', 'Range', 'A1');

sheet2Rows = cell(nDays, N + 3);
for i = 1:nDays
    r = results{i};
    sheet2Rows{i,1} = datestr(r.date, 'yyyy-mm-dd');
    for t = 1:N
        sheet2Rows{i, t+1} = round(r.netAdj(t) * dt, 4);
    end
    sheet2Rows{i,N+2} = round(sum(r.netAdj) * dt, 4);
    sheet2Rows{i,N+3} = round(r.costAdj, 4);
end
writecell(sheet2Rows, filename, 'Sheet', '调整购电量', 'Range', 'A2');

%% ---------- Sheet3: 充放电量 ----------
header3 = {'日期', '时间段', '充电量', '放电量', '时刻', '储电量'};
writecell(header3, filename, 'Sheet', '充放电量', 'Range', 'A1');

periodRanges = [1 24; 25 48; 49 72; 73 96; 97 120; 121 144];
periodLabels = {'0:00-4:00','4:00-8:00','8:00-12:00', ...
                 '12:00-16:00','16:00-20:00','20:00-24:00'};
nRows3 = nDays * 6;
sheet3Rows = cell(nRows3, 6);
row = 1;
for i = 1:nDays
    r = results{i};
    dateStr = datestr(r.date, 'yyyy-mm-dd');
    for p = 1:6
        rng = periodRanges(p,1):periodRanges(p,2);
        chVal  = sum(r.pCh(rng))  * dt;
        disVal = sum(r.pDis(rng)) * dt;

        if p == 1
            sheet3Rows{row,1} = dateStr;
        else
            sheet3Rows{row,1} = '';
        end
        sheet3Rows{row,2} = periodLabels{p};
        sheet3Rows{row,3} = round(chVal, 4);
        sheet3Rows{row,4} = round(disVal, 4);

        if p == 1
            sheet3Rows{row,5} = '00:00:00';
            sheet3Rows{row,6} = round(r.socInit, 4);
        elseif p == 6
            sheet3Rows{row,5} = '24:00';
            sheet3Rows{row,6} = round(r.socTrace(end), 4);
        else
            sheet3Rows{row,5} = '';
            sheet3Rows{row,6} = '';
        end
        row = row + 1;
    end
end
writecell(sheet3Rows, filename, 'Sheet', '充放电量', 'Range', 'A2');

%% ---------- Sheet4: 紧急购电量 ----------
header4 = {'日期', '购电时间段', '购电量'};
writecell(header4, filename, 'Sheet', '紧急购电量', 'Range', 'A1');

nEmgRows = 0;
for i = 1:nDays
    nEmgRows = nEmgRows + sum(results{i}.emg > 0.01);
end
if nEmgRows == 0
    sheet4Rows = {'无', '无', 0};
else
    sheet4Rows = cell(nEmgRows, 3);
    row = 1;
    for i = 1:nDays
        r = results{i};
        dateStr = datestr(r.date, 'yyyy-mm-dd');
        firstOfDay = true;
        for t = 1:N
            if r.emg(t) > 0.01
                if firstOfDay
                    sheet4Rows{row,1} = dateStr;
                    firstOfDay = false;
                else
                    sheet4Rows{row,1} = '';
                end
                sheet4Rows{row,2} = timeLabels{t};
                sheet4Rows{row,3} = round(r.emg(t) * dt, 4);
                row = row + 1;
            end
        end
    end
end
writecell(sheet4Rows, filename, 'Sheet', '紧急购电量', 'Range', 'A2');

fprintf('%s 已保存（%d 天）\n', filename, nDays);
end