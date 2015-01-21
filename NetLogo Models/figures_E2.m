
%% Load data

load E2_data.mat

%% What figures do we want?

% We want one figure, a bar graph, showing the population marginal means
% for the different changes we made in E1.

f1 = figure;
colormap('gray')
maineffectsplot(results{4}.y,results{4}.g,'varnames',{'EVal' 'H-Mult' 'Pref'})
f2 = figure;
interactionplot(results{4}.y,results{4}.g,'varnames',{'EVal' 'H-Mult' 'Pref'})
[p,~,stats] = anovan(results{4}.y,results{4}.g,'interaction');
f3 = figure;
multcompare(stats,'dim',[1 2]);

print(f1,'-depsc2','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E2\e2_figure1.eps')
print(f1,'-dpng','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E2\e2_figure1.png')
print(f2,'-depsc2','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E2\e2_figure2.eps')
print(f2,'-dpng','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E2\e2_figure2.png')