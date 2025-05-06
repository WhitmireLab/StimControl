%  create quick analysis of the data;

% widefield_setparams;

% filesaveloc = 'C:\3sers\2P_Resonant\Data\WidefieldRig\nan\20181106\';
% a = dir([filesaveloc '*.mj2']);
a = dir(filesaveloc);

a(1:2) = [];
a = {a.name};
a = reshape(a,numel(a),1);

aorder = strfind(a,'.');
timenum = zeros(1,numel(aorder));
for aa = 1:numel(aorder)
    ind1 = aorder{aa};tmpfile = a{aa};
    timenum(aa) = str2double(tmpfile((ind1-6:ind1-1)));
end


[aorderupdate,aorder2] = sort(timenum);

a = a(aorder2);

%% SELECT FILE TO LOAD
fileindex =1;
% set ROI
ROIxy = [220 225];

%% Load Video Data
vidObj = VideoReader([filesaveloc a{fileindex}]);
video = read(vidObj); %#ok<VIDREAD>
video = squeeze(video);
video = double(video);
video(:,:,end) = [];

nframes = size(video,3);
framerate = 50;

% framerate =   nframes/vidObj.Duration;
% framerate = 20;

%% Compute dF/F0
stimframe = tstim*framerate;
F0 = median(video(:,:,5:stimframe),3);
%             figure; imagesc(F0)
F0rep = repmat(F0,[1 1 nframes]);
dF_F0 = (video-F0rep)./F0rep;


%% identify ROI and compute response

% ROIxy = [300 300];
cx=ROIxy(1); cy = ROIxy(2);
r = 10;


ROIact = dF_F0(ROIxy(2)-r/2:ROIxy(2)+r/2,ROIxy(1)-r/2:ROIxy(1)+r/2,:);

dF_ROI = mean(squeeze(mean(ROIact,1)),1);



%% create movie

tic
% create average movie
nframes = size(video,3);
lim1 = 0.15;
dtframe = 1/framerate;

moviefig = figure('pos',[1000 100 700 850]);


for jj = 1:5:nframes
    
    subplot(7,1,2:6)
    %     imagesc(dF_F0(:,:,jj),[-lim1 lim1],'Colormap',cool)
    imshow(dF_F0(:,:,jj),[-lim1 lim1],'Colormap',cool)
    h = gca;
    h.Visible = 'On';
    %     caxis([-0.02 0.04])
    caxis([-0.1 0.1])
    hold on;
    plot(ROIxy(1),ROIxy(2),'.k');
    rectangle('Position',[cx-r/2, cy-r/2, r, r],'Curvature',[1,1],'EdgeColor','k');
    title([filesaveloc a{fileindex}],'interpreter','none')
    
    
    subplot(717)
    hold on;
    plot([tstim tstim],[min(dF_ROI(2:end)) max(dF_ROI)],'k--')
    plot(1/framerate: 1/framerate: jj/framerate,dF_ROI(1:jj),'k')
    xlabel('time (s)')
    ylabel('dF/F0 ROI')
    xlim([0 numel(dF_ROI)/framerate])
    ylim([min(dF_ROI(2:end)) max(dF_ROI)])
    
    %     F(jj) = getframe(moviefig);
    
    pause(0.005);
    
    if jj== 45
        pause(1)
    end
    
end
toc
%% Repeat movie

% movie(F)

