
%% Load Data

[num,~] = xlsread('forage_12_model E3-Difficult500-table.csv');

num = num(3:end,7:end); % Remove the first column which is run #

%% Split data into groups and data

control = num(:,4);
final = num(:,5);
g1 = num(:,1); % seed #
g2 = num(:,2); % preference

success = log10(final./control);

%% These data are more complicated, we want to know a few things:
% (1) Who was most successful initially (anova for g2, control)
% (2) Who was most successful at the end of the data, controlling for
% initial. (anova for g2, log10(final / control))

%% Run Anova

warning('NOT MODELING INIT-SI');
[~,~,o_stats] = anovan(control,{g2},'display','off');
[~,~,s_stats] = anovan(success,{g2},'display','off');

%% Multiple Comparisons
means = {}; labels = {};

[~,means{1},~,labels{1}] = multcompare(o_stats,'display','off');
[~,means{2},~,labels{2}] = multcompare(s_stats,'display','off');

%% Report results

load E3_data.mat

results{1}.name = 'Control';
results{1}.means = means{1}(:,1);
results{1}.se = means{1}(:,2);
for l = 1:length(labels{1})
    results{1}.labels(l,:) = labels{1}{l}(4:end);
end

results{2}.name = 'Success';
results{2}.means = means{2}(:,1);
results{2}.se = means{2}(:,2);
for l = 1:length(labels{2})
    results{2}.labels(l,:) = labels{2}{l}(4:end);
end

save('E3_data.mat','results');