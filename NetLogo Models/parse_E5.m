%% Run types
ex_dat = {};
for r_num = 1:3
    switch r_num
        case 1
            runtype = 'EASY';
        case 2
            runtype = 'HARD';
        case 3
            runtype = 'IMPOSSIBLE';
    end
    
    %% Start by loading the file(s)

    fname = sprintf('forage_12_model E5-WellBeing_Report--%s-spreadsheet.csv',runtype);
    [~,txt] = xlsread(fname);

    % Now move find the line that reads "[all run data]"

    for y = 1:size(txt,1)
        if isequal(txt{y,1},'[all run data]')
            break
        end
    end

    txt = txt(y+1:end,2:end);

    %% Split txt into runs

    txt_r = {};
    for r = 1:size(txt,2)/4
        txt_r{r} = txt(:,1+(r-1)*4:4+(r-1)*4);
    end

    alldata = {};
    for r = 1:length(txt_r)
        %% Now replace each timestep into a new cell with arrays
        run = txt_r{r};

        z = cell(size(run));
        for x = 1:size(run,1)
            for y = 1:size(run,2)
                z{x,y} = str2num(run{x,y});
            end
        end

        %% Re-organize using the WHO values

        edata = {};
        for t = 1:size(z,1) % current timestep
            dat = z{t,1};
            for c = 1:length(dat)
                who = dat(c);
                for m = 2:size(z,2)
                    edata{who+1}(t,m-1) = z{t,m}(c);
                end
            end
        end

        % dump empty who values

        data = {};
        for d = 1:length(edata)
            if size(edata{d},1) > 0
                data{end+1} = edata{d};
            end
        end

        alldata = cat(2,alldata,data);
    end
    %% Now we can start analysis! What do we do now!! Oh shit!

    srho = []; xcs = []; prho = []; sp = []; pp = [];
    for f = 1:length(alldata)
        dat = alldata{f};
        
        if length(ex_dat) < 5 && ~any(dat(:,1)==0)
            if mean(dat(:,2)) > 0 && mean(dat(:,2)) < .5
                if mean(dat(:,3)) > 0 && mean(dat(:,3)) < .5
                    ex_dat{end+1} = dat;
                end
            end
        end
        [srho(f,:,:),sp(f,:,:)] = corr(dat,'type','Spearman');
        [prho(f,:,:),pp(f,:,:)] = corr(dat,'type','Pearson');
        %%xcs(f,:) = xcorr(dat(:,2),dat(:,3));
    end

    %% Interpretation

    % A high Spearman's Rho means that the data are monotonically related
    % A high Pearson means that the data are linear related
    nanmean(srho)
    nanmean(sp)
    nanmean(prho)
    nanmean(pp)

    %% Next Analysis, look at peak//trough activity, length of peaks/troughs

    perc = []; h_lengths{1} = []; h_lengths{2} = []; e_lengths{1} = []; e_lengths{2} = []; % h_l(1,:) = ZEROS, 2,: = ONES
    for f = 1:length(alldata)
        dat = alldata{f};
        % Get % data for
        perc(f,1) = mean(dat(:,1));
        perc(f,2) = mean(dat(:,2));
        perc(f,3) = mean(dat(:,3));

        zero_1 = []; one_1 = [];
        zero_2 = []; one_2 = [];
        % We're looking now at one forager's data from one run.
        % Let's go through the data and try to find any consistency in the
        % hed/eud activity (peak to trough distance for example). To do this,
        % we'll simply track the locations where there is a switch from 0 to 1
        % or 1 to 0
        d1 = dat(:,2);
        d2 = dat(:,3);
        t1 = d1(1); t2 = d2(1);
        for i = 2:size(dat,1)
            if ~d1(i)==t1
                if t1 == 0
                    zero_1 = [zero_1 i];
                else
                    one_1 = [one_1 i];
                end
                t1 = d1(i);
            end
            if ~d2(i)==t2
                if t2 == 0
                    zero_2 = [zero_2 i];
                else
                    one_2 = [one_2 i];
                end
                t2 = d2(i);
            end
        end
        h_lengths{1} = [h_lengths{1} diff(zero_1)];
        h_lengths{2} = [h_lengths{2} diff(one_1)];
        e_lengths{1} = [e_lengths{1} diff(zero_2)];
        e_lengths{2} = [e_lengths{2} diff(one_2)];
    end

    %% Save Results for Figures

    load E5_data.mat
    results{r_num}.name = runtype;
    results{r_num}.date = date;
    results{r_num}.msrho(:,:) = squeeze(nanmean(srho));
    results{r_num}.msp(:,:) = squeeze(nanmean(sp));
    results{r_num}.mprho(:,:) = squeeze(nanmean(prho));
    results{r_num}.mpp(:,:) = squeeze(nanmean(pp));
    results{r_num}.h_l = {};
    results{r_num}.h_l{1} = h_lengths{1};
    results{r_num}.h_l{2} = h_lengths{2};
    results{r_num}.e_l = {};
    results{r_num}.e_l{1} = e_lengths{1};
    results{r_num}.e_l{2} = e_lengths{2};
    save('E5_data.mat','results');
    
end

%%
results{end+1} = ex_dat;

f = figure;
hold on
use = 4;
plot(smooth(ex_dat{use}(:,1)/max(ex_dat{use}(:,1)),5),'r')
plot(smooth(ex_dat{use}(:,2),10),'b')
plot(smooth(ex_dat{use}(:,3),10),'g')
legend({'Energy' 'Hedonic' 'Eudaimonic'})
a = axis;
xlabel('Simulation Days')
% set(gca,'YLabelTicks',[])
axis([0 100 a(3) a(4)])
print(f,'-depsc2','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E5\e5_figure1.eps')
print(f,'-dpng','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E5\e5_figure1.png')