%% CONNECT CAMERA

% vid = videoinput('gentl', 1, 'Mono8');
% vid = videoinput('gentl', 1, 'Mono12');
% src = getselectedsource(vid);

% vid = videoinput('hamamatsu', 1, 'MONO16_2048x2048_FastMode');
% vid = videoinput('hamamatsu', 1, 'MONO16_BIN2x2_1024x1024_FastMode');
vid = videoinput('hamamatsu', 1, 'MONO16_BIN4x4_512x512_FastMode');
src = getselectedsource(vid);

vid.FramesPerTrigger = 1;
src.TriggerConnector = 'bnc';   %must have this or it throws an error
src.PixelType = 'mono16'; %must be updated to match the mode *see above' or it causes errors in the image reconstruction.

src.ExposureTime = 0.02;    % need to determine the optimal settings for this

triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
src.TriggerMode = 'start';

src.TriggerSource = 'external';
src.TriggerPolarity = 'positive';
% vid.FramesPerTrigger = 100;

% TMAX = src.ExposureTime*vid.FramesPerTrigger;
vid.FramesPerTrigger = ceil(TMAX./src.ExposureTime);

% preview(vid);
% 
% 
% stoppreview(vid);

% NTRIAL = 1;
% stimid = 'aa';
% filesaveloc = 'C:\Users\2P_Resonant\Desktop\testhamamatsu\';


%{ 
% 
% 
% vid = videoinput('hamamatsu', 1, 'MONO8_2048x2048_FastMode');
% src = getselectedsource(vid);
% 
% vid.FramesPerTrigger = 1;
% 
% % vid.FramesPerTrigger = Inf;
% 
% src.ExposureTime = 0.02;
% 
% src.TriggerConnector = 'bnc';

% src.TriggerConnector = 'interface';
% % % 
% % % figure;
% % % img_ = (getsnapshot(vid));
% % %     imagesc(img_(:,:)); colorbar
% % % 
% % % 
% % % 
% % % 
% % % 
% % % 
% % % 
% % % src.AcquisitionFrameRateEnable = 'True';
% % % src.AutoFunctionROIUseBrightness = 'False';
% % % 
% % % % Set up pixel binning to reduce the data size
% % % src.BinningHorizontal = 4;
% % % src.BinningVertical = 4;
% % % src.BinningHorizontalMode = 'Average';  %'sum'
% % % src.BinningVerticalMode = 'Average';
% % % 
% % % %% set acquisition properties
% % % src.ExposureTime = 45000; %25000
% % % vid.FramesPerTrigger = 1;
% % % samplerate = 20;
% % % src.AcquisitionFrameRate = samplerate;%20;
% % % src.Gain = 24; % range = [0, 23.9]
% % % 
% % % vid.TriggerRepeat = Inf;
% % % 
% % % % set up triggering
% % % src.TriggerMode = 'On';
% % % triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
% % % src.TriggerMode = 'On';
% % % src.TriggerSource = 'Line3';
% % % src.TriggerSelector = 'FrameStart';
% % % 
% % % %% SET UP ROI
% % % %
% % % resolution = vid.VideoResolution;
% % % Ax = resolution(1);
% % % Ay = resolution(2);
% % % 
% % % %Region of interest, centered
% % % ROIy = 1024; 
% % % ROIx = 1024;
% % % 
% % % vid_src = getselectedsource(vid);
% % % vid_src.ExposureAuto = 'Off';
% centre = [Ax/2 - ROIx/2, Ay/2 - ROIy/2, ROIx, ROIy];
% centre = [250 220 250 250];
% vid.ROIPosition = centre;
%}
%% set up video saving & wait for triggered acquisition
countid = 1;

while countid<=NTRIAL 
% for trialrec = 1:5
    
    hh =num2str(hour(datetime));
    mn = num2str(minute(datetime));
    ss = num2str(round(second(datetime)));
    if numel(mn)<2
        mn = ['0' mn];
    end
    if numel(ss)<2
        ss = ['0' ss];
    elseif numel(ss)>2
        ss = ss(1:2);
    end
    exptime = [hh mn ss];
    filename = [stimid '_trial' num2str(countid) '_' exptime '.mj2'];
    vid.LoggingMode = 'disk&memory';
    diskLogger = VideoWriter([filesaveloc filename], 'Motion JPEG 2000');
    
    diskLogger.FrameRate = 100;%samplerate;
    
    
    vid.DiskLogger = diskLogger;
    
    
    
    %image each trial
    
    
    preview(vid);
    start(vid);
    
    timeflag = 0; %vid.InitialTriggerTime;
%     nframes = vid.FramesAcquired;

    
    while timeflag<TMAX+0.5 %500 ms wiggleroom
        if ~isempty(vid.InitialTriggerTime)
            tstart = vid.InitialTriggerTime;
            timeflag = etime(clock,tstart);
        else
            timeflag = 0;
        end
%         nframes = vid.FramesAcquired;
    end
    
    data = getdata(vid,vid.FramesAvailable);
    data = squeeze(data);
    filenametiff = [filesaveloc stimid '_trial' num2str(countid) '_' exptime '.tiff'];
    saveastiff(data, filenametiff);
    
    stoppreview(vid);
    stop(vid);
    
    countid = countid +1;
end

%% Load Data and analyze





