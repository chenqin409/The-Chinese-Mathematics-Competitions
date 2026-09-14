
clear; clc;

N          = 144;
dt         = 1/6;
Q_SAFE     = 0.93;
PRED_START = datetime(2025,2,1);
PRED_END   = datetime(2025,12,31);
USE_SINGLE_FILE = true;  

%% 
time_labels = cell(1, N);
for t = 1:N
    start_min = (t-1)*10;
    end_min   = t*10;
    sh = floor(start_min/60); sm = mod(start_min,60);
    eh = floor(end_min/60);   em = mod(end_min,60);
    if t == N
        time_labels{t} = sprintf('%d:%02d-%d:00+1', sh, sm, eh);
    else
        time_labels{t} = sprintf('%d:%02d-%d:%02d', sh, sm, eh, em);
    end
end

%% 
load_tbl   = readtable('附件2.xlsx', 'Sheet', '小区负载', ...
    'VariableNamingRule', 'preserve');
load_dates = dateshift(datetime(load_tbl{:,1}), 'start', 'day');
load_data  = load_tbl{:, 2:145};

pv_tbl     = readtable('附件2.xlsx', 'Sheet', '光伏发电实际功率', ...
    'VariableNamingRule', 'preserve');
pv_dates   = dateshift(datetime(pv_tbl{:,1}), 'start', 'day');
pv_data    = pv_tbl{:, 2:145};

fprintf('负载历史: %d 天 × %d 时段\n', size(load_data,1), size(load_data,2));
fprintf('光伏历史: %d 天 × %d 时段\n', size(pv_data,1), size(pv_data,2));

%% 
pred_dates = (PRED_START:caldays(1):PRED_END)';
n_days     = length(pred_dates);
fprintf('预测日期: %d 天\n', n_days);
fprintf('安全分位数 Q_SAFE = %.2f\n', Q_SAFE);

%% 
combos = {
    'LA_PA', 'A', 'A';   
    'LA_PB', 'A', 'B';   
    'LB_PA', 'B', 'A';   
    'LB_PB', 'B', 'B';   
    };

if USE_SINGLE_FILE
    xls_all = 'forecast_all.xlsx';
    if exist(xls_all, 'file'), delete(xls_all); end
    fprintf('\n输出合并文件: %s\n', xls_all);
end

%% 主循环
for c = 1:4
    tag         = combos{c,1};
    load_method = combos{c,2};
    pv_method   = combos{c,3};
    
       
    % 初始化矩阵
    load_pred_mat   = NaN(n_days, N);
    pv_pred_mat     = NaN(n_days, N);
    load_margin_mat = NaN(n_days, N);
    pv_margin_mat   = NaN(n_days, N);
    load_plan_mat   = NaN(n_days, N);
    pv_plan_mat     = NaN(n_days, N);
    
    for i = 1:n_days
        d = pred_dates(i);
        
        % 原始预测
        lp = predict_load(d, load_dates, load_data, load_method);
        pp = predict_pv(d, pv_dates, pv_data, pv_method);
        if isempty(lp) || isempty(pp)
            continue;
        end
        
        % 安全余量
        dl = compute_load_margin_day(d, load_dates, load_data, load_method, Q_SAFE);
        dp = compute_pv_margin_day(d, pv_dates, pv_data, pv_method, Q_SAFE);
        
        % 计划用值
        load_plan = lp + dl;
        pv_plan   = max(pp - dp, 0);
        
        load_pred_mat(i,:)   = lp';
        pv_pred_mat(i,:)     = pp';
        load_margin_mat(i,:) = dl';
        pv_margin_mat(i,:)   = dp';
        load_plan_mat(i,:)   = load_plan';
        pv_plan_mat(i,:)     = pv_plan';
        
        if mod(i,50)==0 || i==1 || i==n_days
            fprintf(' [%d/%d] %s\n', i, n_days, datestr(d));
        end
    end
    
    %% 导出
    if USE_SINGLE_FILE
        xls_file = xls_all;
    else
        xls_file = sprintf('forecast_%s.xlsx', tag);
        if exist(xls_file, 'file'), delete(xls_file); end
    end
    
    % 6 个 sheet 的数据
    sheet_names = {'负载原始预测', '光伏原始预测', ...
                   '负载安全余量', '光伏安全余量', ...
                   '负载计划值',   '光伏计划值'};
    sheet_mats  = {load_pred_mat, pv_pred_mat, ...
                   load_margin_mat, pv_margin_mat, ...
                   load_plan_mat, pv_plan_mat};
    
    for s = 1:6
        if USE_SINGLE_FILE
            sheet_name = sprintf('%s_%s', tag, sheet_names{s});
        else
            sheet_name = sheet_names{s};
        end
        % sheet 名长度限制 31 字符
        if length(sheet_name) > 31
            sheet_name = sheet_name(1:31);
        end
        
        % 表头
        header = [{'日期'}, time_labels];
        writecell(header, xls_file, 'Sheet', sheet_name, 'Range', 'A1');
        
        % 数据
        data = cell(n_days, N + 1);
        for i = 1:n_days
            data{i,1} = datestr(pred_dates(i), 'yyyy-mm-dd');
            for t = 1:N
                data{i, t+1} = round(sheet_mats{s}(i,t), 4);
            end
        end
        writecell(data, xls_file, 'Sheet', sheet_name, 'Range', 'A2');
    end
    
end


fprintf('全部完成！\n');
