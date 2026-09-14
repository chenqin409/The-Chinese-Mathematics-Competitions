function pred = predict_load(d, dates, data, method)
    pred = [];
    if strcmp(method, 'A')
        target = d - caldays(7);
        idx = find(dates == target, 1);
        if ~isempty(idx)
            pred = data(idx,:)';
        end
    elseif strcmp(method, 'B')
        season = get_season(d.Month);
        wd = weekday(d);

        seasons = arrayfun(@(x) get_season(x.Month), dates);
        weekdays = weekday(dates);

        mask = (dates < d) & (seasons == season) & (weekdays == wd);
        idx = find(mask);

        if isempty(idx)
            mask = (dates < d) & (weekdays == wd);
            idx = find(mask);
        end

        if ~isempty(idx)
            pred = mean(data(idx,:), 1)';
        end
    end
end
