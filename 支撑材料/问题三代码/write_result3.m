function write_result3(all_results, N, dt)
valid   = ~cellfun(@isempty, all_results);
results = all_results(valid);
n_days  = length(results);

if n_days == 0
    warning('没有结果可写入');
    return;
end

time_labels = cell(1, N);
for t = 1:N
    start_min = (t-1)*10;
    end_min   = t*10;
    sh = floor(start_min/60); sm = mod(start_min, 60);
    eh = floor(end_min/60);   em = mod(end_min, 60);
    time_labels{t} = sprintf('%d:%02d-%d:%02d', sh, sm, eh, em);
end

if exist('result3.xlsx', 'file')
    delete('result3.xlsx');
end


header1 = cell(1, N + 3);
header1{1} = '日期\时间';
for t = 1:N, header1{t+1} = time_labels{t}; end
header1{N+2} = '全天购电量';
header1{N+3} = '全天购电费';
writecell(header1, 'result3.xlsx', 'Sheet', '计划购电量', 'Range', 'A1');

sheet1_data = cell(n_days, N + 3);
for i = 1:n_days
    r = results{i};
    sheet1_data{i,1} = datestr(r.date, 'yyyy-mm-dd');
    for t = 1:N
        sheet1_data{i, t+1} = round(r.pPlan(t) * dt, 4);   % ★ 改成 pPlan
    end
    sheet1_data{i,N+2} = round(sum(r.pPlan) * dt, 4);
    sheet1_data{i,N+3} = round(r.costPlan, 4);
end
writecell(sheet1_data, 'result3.xlsx', 'Sheet', '计划购电量', 'Range', 'A2');

%% 
header2 = cell(1, N + 3);
header2{1} = '日期\时间';
for t = 1:N, header2{t+1} = time_labels{t}; end
header2{N+2} = '全天购电量';
header2{N+3} = '全天购电费';
writecell(header2, 'result3.xlsx', 'Sheet', '调整购电量', 'Range', 'A1');

sheet2_data = cell(n_days, N + 3);
for i = 1:n_days
    r = results{i};
    sheet2_data{i,1} = datestr(r.date, 'yyyy-mm-dd');
    for t = 1:N
        sheet2_data{i, t+1} = round(r.netAdj(t) * dt, 4);   % ★ 改成 netAdj
    end
    sheet2_data{i,N+2} = round(sum(r.netAdj) * dt, 4);
    sheet2_data{i,N+3} = round(r.costAdj, 4);
end
writecell(sheet2_data, 'result3.xlsx', 'Sheet', '调整购电量', 'Range', 'A2');

%% 
header3 = {'日期', '时间段', '充电量', '放电量', '时刻', '储电量'};
writecell(header3, 'result3.xlsx', 'Sheet', '充放电量', 'Range', 'A1');

period_ranges = [1 24; 25 48; 49 72; 73 96; 97 120; 121 144];
period_labels = {'0:00-4:00','4:00-8:00','8:00-12:00', ...
                 '12:00-16:00','16:00-20:00','20:00-24:00'};
n_rows3 = n_days * 6;
sheet3_data = cell(n_rows3, 6);
row = 1;
for i = 1:n_days
    r = results{i};
    date_str = datestr(r.date, 'yyyy-mm-dd');
    for p = 1:6
        rng = period_ranges(p,1):period_ranges(p,2);
        ch_val  = sum(r.pCh(rng))  * dt;      
        dis_val = sum(r.pDis(rng)) * dt;      

        if p == 1
            sheet3_data{row,1} = date_str;
        else
            sheet3_data{row,1} = '';
        end
        sheet3_data{row,2} = period_labels{p};
        sheet3_data{row,3} = round(ch_val, 4);
        sheet3_data{row,4} = round(dis_val, 4);

        if p == 1
            sheet3_data{row,5} = '00:00:00';
            sheet3_data{row,6} = round(r.socInit, 4);      
        elseif p == 6
            sheet3_data{row,5} = '24:00';
            sheet3_data{row,6} = round(r.socTrace(end), 4);  
        else
            sheet3_data{row,5} = '';
            sheet3_data{row,6} = '';
        end
        row = row + 1;
    end
end
writecell(sheet3_data, 'result3.xlsx', 'Sheet', '充放电量', 'Range', 'A2');

%% ---------- Sheet4: 紧急购电量 ----------
header4 = {'日期', '购电时间段', '购电量'};
writecell(header4, 'result3.xlsx', 'Sheet', '紧急购电量', 'Range', 'A1');

total_emg_rows = 0;
for i = 1:n_days
    total_emg_rows = total_emg_rows + sum(results{i}.emg > 0.01);
end
if total_emg_rows == 0
    sheet4_data = {'无', '无', 0};
else
    sheet4_data = cell(total_emg_rows, 3);
    row = 1;
    for i = 1:n_days
        r = results{i};
        date_str = datestr(r.date, 'yyyy-mm-dd');
        first_in_day = true;
        for t = 1:N
            if r.emg(t) > 0.01
                if first_in_day
                    sheet4_data{row,1} = date_str;
                    first_in_day = false;
                else
                    sheet4_data{row,1} = '';
                end
                sheet4_data{row,2} = time_labels{t};
                sheet4_data{row,3} = round(r.emg(t) * dt, 4);
                row = row + 1;
            end
        end
    end
end
writecell(sheet4_data, 'result3.xlsx', 'Sheet', '紧急购电量', 'Range', 'A2');

fprintf('result3.xlsx 已保存（%d 天）\n', n_days);
end