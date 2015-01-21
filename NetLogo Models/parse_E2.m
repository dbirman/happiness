
%% Load Data

[num,~] = xlsread('forage_13_model E2-Initial_Vals-table.csv');

num = num(3:end,5:end); % Remove the first column which is run #

%% Split data into groups and data

edata = num(:,6);
% adata = num(:,7);
g1 = num(:,1); % seed #
g2 = num(:,2); % eval
g3 = num(:,3); % h-mul
g4 = num(:,4); % preference

%% Run Anova

warning('NOT MODELING INIT-SI');
[p,~,stats] = anovan(edata,{g2 g3 g4},'interaction');
if any(p(4:end)<.05)
    warning('INTERACTION EFFECTS SIGNIFICANT');
end
% [p,t,stats] = anovan(edata,{g2 g3 g4},'display','off');
% if ~all(p(1:3)<.05)
%     warning('NOT ALL EFFECTS SIGNIFICANT');
% end

%% Multiple Comparisons
means = {}; labels = {};

for c = 1:3
    [~,means{c},~,labels{c}] = multcompare(stats,'dim',[c],'display','off');
end

%% Report results

load E2_data.mat

results = {};

results{4}.y = edata;
results{4}.g = {g2 g3 g4};

results{1}.name = 'Eval';
results{1}.means = means{1}(:,1);
results{1}.se = means{1}(:,2);
for l = 1:length(labels{1})
    results{1}.labels{l} = labels{1}{l}(4:end);
end

results{2}.name = 'H-Mult';
results{2}.means = means{2}(:,1);
results{2}.se = means{2}(:,2);
for l = 1:length(labels{2})
    results{2}.labels{l} = labels{2}{l}(4:end);
end

results{3}.name = 'Pref';
results{3}.means = means{3}(:,1);
results{3}.se = means{3}(:,2);
for l = 1:length(labels{3})
    results{3}.labels{l} = labels{3}{l}(4:end);
end

save('E2_data.mat','results');