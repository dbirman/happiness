
%% Load data

load E1_data.mat

%% What figures do we want?

% We want one figure, a bar graph, showing the population marginal means
% for the different changes we made in E1.

f = figure;
colormap('gray')
subplot(121)
barwitherr(results{1}.se(1:end-1),results{1}.means(1:end-1))
set(gca,'XTickLabel',results{1}.labels(1:end-1))
xlabel(results{1}.name)
ylabel('Population Marginal Means [total forager energy]')
a = axis;
axis([a(1) 6 0 4500])
subplot(122)
barwitherr(results{2}.se(1:end-1),results{2}.means(1:end-1),'FaceColor',[.75 .75 .75])
set(gca,'XTickLabel',results{2}.labels(1:end-1))
set(gca,'YTickLabel',[])
xlabel(results{2}.name)
a2 = axis;
axis([a2(1) 6 0 4500]);
print(f,'-depsc2','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E1\e1_figure.eps')
print(f,'-dpng','C:\Users\Dan\Documents\Happiness (Shimon)\NetLogo Models\figures\E1\e1_figure.png')