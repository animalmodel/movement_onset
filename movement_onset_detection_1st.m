% movement_onset_detection_1st.m
% Programmed by Akito Kosugi
% ver. 1.1    10.11.2024

clear all
close all
clc

%% Initialization1170

likeliTh = 0.8;
visibleTh = 0.7;
fps = 239.76;
cutoff = 30;
screenSize = get(0,'ScreenSize');


%% Data loading

currentFolder = pwd;

[fName, dPath] = uigetfile('*.csv');
addpath(pwd);
cd(dPath);
data=csvread(fName,3,0);
fileID = fopen(fName);
temp=textscan(fileID,'%s',2);
nameTemp = strsplit(temp{1,1}{2,1},',');
cd(currentFolder);
rmpath(pwd);

triggerIdx =input('Please input the nuber of lever trigger: ');
num_ledLeverPull =input('Please input the nuber of LED after lever pull: ');

dataName = fName(1:length(fName)-4);
idx = findstr(dataName,'_');
date = dataName(1:idx(2)-1);
recNode = str2num(dataName(idx(2)+1:idx(3)-1));
exp = str2num(dataName(idx(3)+1:idx(4)-1));
rec = str2num(dataName(idx(4)+1:idx(5)-1));
condition = dataName(idx(5)+1:idx(6)-1);
session = str2num(dataName(idx(6)+1:idx(7)-1));
trial = str2num(dataName(idx(9)+1:idx(9)+2));

saveName = dataName(1:idx(9)+2);

disp(['Date: ' date]);
disp(['Recording node: ' num2str(recNode)]);
disp(['experiment: ' num2str(exp)]);
disp(['recording: ' num2str(rec)]);
disp(['Condition: ' condition]);
disp(['Session: ' num2str(session)]);
disp(['Trial: ' num2str(trial)]);

frame = data(:,1)+1;
data_x = data(:,2:3:end);
data_y = data(:,3:3:end);
likeli= data(:,4:3:end);

frameNum = length(frame);
partsNum = (size(data,2)-1)/3;

for i=1:partsNum
   partsName(i) = nameTemp(i*3+1);  
end

time = 1/fps:1/fps:frameNum/fps;

handIdx = 3;
homeIdx = 4;
leverLEDIdx = 6;

if contains(condition,'center') == 1
    leverIdx = 2;
elseif contains(condition,'medial') == 1
    leverIdx = 1;
end

LEDOnIdx = find(likeli(:,leverLEDIdx)>0.8);
LEDOnIdx_diff = diff(LEDOnIdx);
idx = [0;find(LEDOnIdx_diff>1)];
LEDStartIdx = LEDOnIdx(idx+1);
taskEndIdx = LEDStartIdx(num_ledLeverPull);
% taskEndIdx = min(find(likeli(:,leverLEDIdx)>0.8));


%% Signal processing

dataTemp_x = data_x;
dataTemp_y = data_y;

%---check likeli---%
for i=1:frameNum
    for j = 1:partsNum
        if likeli(i,j) < likeliTh
            isLikeli(i,j) = 0;
            dataTemp_x(i,j) =nan;
            dataTemp_y(i,j) = nan;
        else
            isLikeli(i,j) = 1;
        end
    end
end

%---check visible---%
for i=1:frameNum
    for j = 1:partsNum
        if likeli(i,j) < visibleTh
            isVisible(i,j) = 0;
        else
            isVisible(i,j) = 1;
        end
    end
end

acc = sum(isLikeli,1)./sum(isVisible,1);
for i = 1:partsNum
    disp(['acc ' char(partsName(i)) ': ' num2str(acc(i))]);
end
    
%---interpolation and filter---%
dataTemp2_x = fillmissing(dataTemp_x,'linear');
dataTemp2_y = fillmissing(dataTemp_y,'linear');

passband = cutoff/(fps/2);
[b,a] = butter(4,passband,'low');
f = dataTemp2_x(:,handIdx)./(fps/2);
filtData_x = (filtfilt(b,a,f)*(fps/2)); 
clear f;
f = dataTemp2_y(:,handIdx)./(fps/2);
filtData_y = (filtfilt(b,a,f)*(fps/2)); 
clear a b f;

handPos = [filtData_x(1:taskEndIdx),-filtData_y(1:taskEndIdx)];

homePosIdx = taskEndIdx;
homePos = [dataTemp2_x(homePosIdx,homeIdx),-dataTemp2_y(homePosIdx,homeIdx)];
handPos = handPos - homePos;
handPos_all = [dataTemp2_x(:,handIdx),-dataTemp2_y(:,handIdx)] - homePos;


%% Onset detection
% Movementonset was defined as the time at which the hand velocity first exceeded 5% of the peak velocity

th = 0.05;

handSpeed = diff(handPos);
passband = cutoff/(fps/2);
[b,a] = butter(4,passband,'low');
f = handSpeed./(fps/2);
handSpeed = (filtfilt(b,a,f)*(fps/2)); 

handSpeed_all = diff(handPos_all);
passband = cutoff/(fps/2);
[b,a] = butter(4,passband,'low');
f = handSpeed_all./(fps/2);
handSpeed_all = (filtfilt(b,a,f)*(fps/2)); 

[max_x, maxIdx_x] = max(abs(handSpeed(:,1)));
searchStartIdx = maxIdx_x-floor(fps*0.2);
onsetTh_x = max_x*th;
onsetIdx_x = min(find(abs(handSpeed(searchStartIdx:maxIdx_x,1))>onsetTh_x))+searchStartIdx-1;
[max_y, maxIdx_y] = max(abs(handSpeed(:,2)));
searchStartIdx = maxIdx_y-floor(fps*0.2);
onsetTh_y = max_y*th;
onsetIdx_y = min(find(abs(handSpeed(searchStartIdx:maxIdx_y,2))>onsetTh_y))+searchStartIdx-1;

onsetIdx = min(onsetIdx_x,onsetIdx_y)+1;

onsetTime_from_trig = (onsetIdx-taskEndIdx)/fps*1000;

disp(['Trigger frame: ' num2str(floor(taskEndIdx))]);
disp(['Onset frame: ' num2str(floor(onsetIdx))]);
disp(['Onset time from trigger: ' num2str(floor(onsetTime_from_trig)) ' ms']);

leverPos = [dataTemp2_x(onsetIdx,leverIdx),-dataTemp2_y(onsetIdx,leverIdx)];
leverPos = leverPos - homePos;
homePos = homePos - homePos;


%% Plot

% Trajectory
fSize = 15;
f = figure('position',[screenSize(1)+screenSize(3)*1/10 screenSize(2)+screenSize(4)*2/10 screenSize(3)*7/20 screenSize(4)*6/10]);
hold on
grid on
l(1) = scatter(leverPos(1),leverPos(2),100,'g','filled');
l(2) = plot(handPos(onsetIdx:end,1),handPos(onsetIdx:end,2),'b','linewidth',1);
l(3) = scatter(homePos(1),homePos(2),100,'r','filled');
legend(l,partsName{[leverIdx,handIdx,homeIdx]},'location','northwest','interpreter','none');
xlim([-50,350]);
ylim([-50,350]);
title(['Tracking from side view: ' condition]);
xlabel('X-axis position (px)');
ylabel('Y-axis position (px)');
set(gca,'fontsize',fSize);
saveas(gcf,[saveName '_trajectory.fig']);
saveas(gcf,[saveName '_trajectory.bmp']);

pause(1)

% Position and speed
fSize = 13;
f = figure('position',[screenSize(1)+screenSize(3)*5/10 screenSize(2)+screenSize(4)*1/10 screenSize(3)*4/10 screenSize(4)*8/10]);
subplot(4,2,1)
plot(frame(1:taskEndIdx),data_x(1:taskEndIdx,handIdx),'r','linewidth',1);
title('Horizonta hand rawdata');
ylabel('Position (px)');
set(gca,'fontsize',fSize);
subplot(4,2,3)
plot(frame(1:taskEndIdx),handPos(:,1),'r','linewidth',1);
title('Horizontal hand filtered data');
ylabel('Position (px)');
set(gca,'fontsize',fSize);
subplot(4,2,5)
hold on
plot(frame(1:taskEndIdx-1),handSpeed(:,1),'r','linewidth',1);
plot([frame(1),frame(taskEndIdx-1)],[onsetTh_x,onsetTh_x],'k--');
plot([frame(1),frame(taskEndIdx-1)],[-onsetTh_x,-onsetTh_x],'k--');
scatter(frame(onsetIdx_x),handSpeed(onsetIdx_x,1),30,'k','filled');
title('Horizonta hand speed');
ylabel('Speed (px/s)');
set(gca,'fontsize',fSize);
subplot(4,2,7)
plot(frame(1:taskEndIdx),likeli(1:taskEndIdx,handIdx),'k','linewidth',1);
title('Tracking accuracy');
ylabel('Likelihood');
ylim([0,1.05]);
xlabel('Frame');
set(gca,'fontsize',fSize);
subplot(4,2,2)
plot(frame(1:taskEndIdx),-data_y(1:taskEndIdx,handIdx),'b','linewidth',1);
title('Vertical hand rawdata');
ylabel('Position (px)');
set(gca,'fontsize',fSize);
subplot(4,2,4)
plot(frame(1:taskEndIdx),handPos(:,2),'b','linewidth',1);
title('Vertical hand filtered data');
ylabel('Position (px)');
set(gca,'fontsize',fSize);
subplot(4,2,6)
hold on
plot(frame(1:taskEndIdx-1),handSpeed(:,2),'b','linewidth',1);
plot([frame(1),frame(taskEndIdx-1)],[onsetTh_y,onsetTh_y],'k--');
plot([frame(1),frame(taskEndIdx-1)],[-onsetTh_y,-onsetTh_y],'k--');
scatter(frame(onsetIdx_y),handSpeed(onsetIdx_y,2),30,'k','filled');
title('Vertical hand speed');
ylabel('Speed (px/s)');
set(gca,'fontsize',fSize);
subplot(4,2,8)
plot(frame(1:taskEndIdx),likeli(1:taskEndIdx,handIdx),'k','linewidth',1);
title('Tracking accuracy');
xlabel('Frame');
ylabel('Likelihood');
ylim([0,1.05]);
set(gca,'fontsize',fSize);
saveas(gcf,[saveName '_speed.fig']);
saveas(gcf,[saveName '_speed.bmp']);


%% Save

saveData.param.date = date;
saveData.param.recNode = recNode;
saveData.param.exp = exp;
saveData.param.rec = rec;
saveData.param.condition = condition;
saveData.param.session = session;
saveData.param.trial = trial;
saveData.param.partsName = partsName;
saveData.param.fps = fps;
saveData.param.handIdx = handIdx;
saveData.param.homeIdx = homeIdx;
saveData.param.leverLEDIdx = leverLEDIdx;
saveData.param.leverIdx = leverIdx;

saveData.data.handPos = handPos;
saveData.data.leverPos = leverPos;
saveData.data.homePos = homePos;
saveData.data.handSpeed  = handSpeed;
saveData.data.handPos_all = handPos_all;
saveData.data.handSpeed_all = handSpeed_all;
saveData.data.taskEndIdx = taskEndIdx;
saveData.data.triggerIdx = triggerIdx;
saveData.data.onsetIdx = onsetIdx;
saveData.data.onsetTime_from_trig = onsetTime_from_trig;

save([saveName '.mat'],'saveData');
