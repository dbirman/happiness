
%% Load Data

[num,~] = xlsread('forage_12_model E1-Survival-table.csv');

num = num(3:end,2:end); % Remove the first column which is run #

%% Split data into groups and data

edata = num(:,6);
g1 = num(:,1); % max seed
g2 = num(:,2); % num patches
g3 = num(:,4); % seed #

%% Run Anova

% [p,~,stats] = anovan(edata,{g1 g2 g3},'interaction','display','off');
% if any(p(4:end)<.05)
%     warning('INTERACTION EFFECTS SIGNIFICANT');
% end
[p,t,stats] = anovan(edata,{g1 g2 g3},'display','off');
if ~all(p(1:3)<.05)
    warning('NOT ALL EFFECTS SIGNIFICANT');
end

%% Multiple Comparisons

[~,means_1,~,labels_1] = multcompare(stats,'dim',[1],'display','off');
% Levels are 15, 20, 25
[~,means_2,~,labels_2] = multcompare(stats,'dim',[2],'display','off');
% Levels are 15, 20, 25

%% Report results

load E1_data.mat

results = {};
results{1}.name = 'Max Seed';
results{1}.means = means_1(:,1);
results{1}.se = means_1(:,2);
for l = 1:length(labels_1)
    results{1}.labels{l} = labels_1{l}(4:end);
end

results{2}.name = 'Num Patches';
results{2}.means = means_2(:,1);
results{2}.se = means_2(:,2);
for l = 1:length(labels_2)
    results{2}.labels{l} = labels_2{l}(4:end);
end

save('E1_data.mat','results');