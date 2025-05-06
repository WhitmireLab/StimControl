%% Software to initialize the Hamamatsu camera for widefield imaging
% this script will initiate contact with the hamamatsu camera and put the
% camera into a waiting mode for triggers. The acquisition is triggered by
% the stimulus control software. 

% this script is called by the widefield setparams script. it is not run
% independently.

%% CONNECT CAMERA
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

vid.FramesPerTrigger = ceil(TMAX./src.ExposureTime);



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
    a = tic;
    data = getdata(vid,vid.FramesAvailable);
    data = squeeze(data);
    filenametiff = [filesaveloc stimid '_trial' num2str(countid) '_' exptime '.tiff'];
    saveastiff(data, filenametiff);
    
    stoppreview(vid);
    stop(vid);
    
    countid = countid +1;
end

%% Load Data and analyze





