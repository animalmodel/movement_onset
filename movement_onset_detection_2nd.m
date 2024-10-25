% movement_onset_detection_2nd.m
% Programmed by Akito Kosugi
% ver 1.2    10.25.2024

clear all
close all
clc

%% Initialization

screenSize = get(0,'ScreenSize');


%% Data loading

%---Load mat file---%
currentfolder = pwd;
dpath = uigetdir;
   
%     folderNameStart = max(findstr(dpath,'/'));
folderNameStart = max(findstr(dpath,'\'));
folderNameEnd = length(dpath);
folderName = dpath(folderNameStart+1:folderNameEnd);
cd(dpath)
D = dir('*.mat');
dataNum = size(D,1);
h = waitbar(0,'file loading...');
for n=1:dataNum
    fname = D(n).name;
    dataName(n) = {fname};
    load(fname)
    temp =  eval(char(who('-file', fname)));
    loadData(n) = temp;
    clear temp
    waitbar(n/dataNum,h);
end
close(h)

cd(currentfolder)
disp('File Loading complete');

fps = loadData(1).param.fps;
partsName = loadData(1).param.partsName;
condition = loadData(1).param.condition;
leverIdx = loadData(1).param.leverIdx;
handIdx = loadData(1).param.handIdx;
homeIdx = loadData(1).param.homeIdx;

%---Load analysis data---%
handPos = nan(500,2,dataNum);
handSpeed = nan(500,2,dataNum);
time = nan(500,dataNum);
leverpos = nan(2,dataNum);
for n = 1:dataNum
    trial(n) = loadData(n).param.trial;
    triggerIdx(n) = loadData(n).data.triggerIdx;
    onsetIdx(n) = loadData(n).data.onsetIdx;
    taskEndIdx(n) = loadData(n).data.taskEndIdx;
    reachingTime(n) = loadData(n).data.onsetTime_from_trig;
    handPos_temp = loadData(n).data.handPos;
%     handPos(1:length(handPos_temp)-onsetIdx(n)+1,:,n) = handPos_temp(onsetIdx(n):end,:);
    handPos(1:length(handPos_temp)-onsetIdx(n)+1+floor(0.1*fps),:,n) = handPos_temp(onsetIdx(n)-floor(0.1*fps):end,:);
    handSpeed_temp = loadData(n).data.handSpeed(onsetIdx(n)-floor(0.1*fps):taskEndIdx(n)-1,:);
    handSpeed(1:length(handSpeed_temp),:,n) = handSpeed_temp;
%     time(1:length(handSpeed_temp(:,1)),n) = (1:length(handSpeed_temp(:,1)))'./fps*1000;
    time(1:length(handSpeed_temp(:,1)),n) = (-floor(0.1*fps):length(handSpeed_temp(:,1))-floor(0.1*fps)-1)'./fps*1000;
    leverPos(:,n) = loadData(n).data.leverPos;
    homePos(:,n) = loadData(n).data.homePos;
end

saveNameTemp = char(dataName(1));
idx = findstr(saveNameTemp,'_');
saveName = saveNameTemp(1:idx(7)-1);


%% Plot

fSize = 14;
f = figure('position',[screenSize(1)+screenSize(3)*1/30 screenSize(2)+screenSize(4)*4/20 screenSize(3)*26/30 screenSize(4)*11/20]);
subplot(1,2,1)
hold on
grid on
for n = 1:dataNum
    l(1) = plot(squeeze(handPos(:,1,n)),squeeze(handPos(:,2,n)),'b','linewidth',1);
    l(2) = scatter(leverPos(1,n),leverPos(2,n),100,'g','filled');
    l(3) = scatter(homePos(1,n),homePos(2,n),100,'r','filled');
end
xlim([-50,450]);
ylim([-50,450]);
% legend(l,partsName,'location','northwest');
legend(l,partsName{[handIdx,leverIdx,homeIdx]},'location','northwest','interpreter','none');
title(['Tracking from side view: ' condition]);
xlabel('Horizontal axis position (px)');
ylabel('Vertical axis position (px)');
set(gca,'fontsize',fSize);

fSize = 11;
subplot(2,6,4)
hold on
for n = 1:dataNum
    plot(time(:,n),squeeze(handPos(:,1,n)),'b','linewidth',1);
end
title('Horizontal position');
xlabel('Time from onset [ms]');
ylabel('Position (px)');
xlim([-100,400]);
ylim([0,350]);
set(gca,'fontsize',fSize);
subplot(2,6,10)
hold on
for n = 1:dataNum
    plot(time(:,n),squeeze(handPos(:,2,n)),'b','linewidth',1);
end
title('Vertical position');
xlabel('Time from onset [ms]');
ylabel('Position (px)');
xlim([-100,400]);
ylim([0,350]);
set(gca,'fontsize',fSize);
subplot(2,6,5)
hold on
for n = 1:dataNum
    plot(time(:,n),squeeze(handSpeed(:,1,n)),'b','linewidth',1);
end
title('Horizontal speed');
xlabel('Time from onset [ms]');
ylabel('Speed (px/s)');
xlim([-100,400]);
ylim([-10,35]);
set(gca,'fontsize',fSize);
subplot(2,6,11)
hold on
for n = 1:dataNum
    plot(time(:,n),squeeze(handSpeed(:,2,n)),'b','linewidth',1);
end
title('Vertical speed');
xlabel('Time from onset [ms]');
ylabel('Speed (px/s)');
xlim([-100,400]);
ylim([-10,30]);
set(gca,'fontsize',fSize);
subplot(1,6,6)
hold on
bar(1,mean(-reachingTime),'FaceColor','w');
scatter(1,-reachingTime,120,'k','LineWidth',1);
ylim([0,600]);
title('Time from onset to lever pull');
ylabel('Time [ms]')
set(gca,'xtick',[]);
set(gca,'fontsize',fSize);

saveas(gcf,[saveName '_merge.fig']);
saveas(gcf,[saveName '_merge.bmp']);


%% Save

saveData.param.fps = fps;
saveData.param.condition = condition;
saveData.param.partsName = partsName;

saveData.data.trial = trial;
saveData.data.triggerIdx = triggerIdx;
saveData.data.onsetIdx = onsetIdx;
saveData.data.taskEndIdx = taskEndIdx;
saveData.data.reachingTime = reachingTime;
saveData.data.time = time;
saveData.data.handPos = handPos;
saveData.data.handSpeed = handSpeed;
saveData.data.leverPos = leverPos;
saveData.data.homePos = homePos;

save([saveName '_merge.mat'],'saveData');

saveData_csv = nan(dataNum,3);
saveData_csv(:,1) = 1:dataNum;
saveData_csv(:,2) = triggerIdx;
saveData_csv(:,3) = round(reachingTime)./1000;

saveMatrix = ["Trial" "Lever trigger index (DI2)" "Movement onset from lever trigger [s]"; saveData_csv];
writematrix(saveMatrix,[saveName '_merge.csv']);
