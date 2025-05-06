%% Software to initialize the Hamamatsu camera for widefield imaging
% this script will initiate contact with the hamamatsu camera and put the
% camera into a waiting mode for triggers. The acquisition is triggered by
% the stimulus control software. 

% this script is called by the widefield setparams script. it is not run
% independently.

%% CONNECT HAMAMATSU CAMERA
vid1 = videoinput('hamamatsu', 1, 'MONO16_BIN4x4_512x512_FastMode');
src1 = getselectedsource(vid1);

vid1.FramesPerTrigger = 1;
src1.TriggerConnector = 'bnc';   %must have this or it throws an error
src1.PixelType = 'mono16'; %must be updated to match the mode *see above' or it causes errors in the image reconstruction.

src1.ExposureTime = 0.02;    % need to determine the optimal settings for this

triggerconfig(vid1, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
src1.TriggerMode = 'start';

src1.TriggerSource = 'external';
src1.TriggerPolarity = 'positive';

vid1.FramesPerTrigger = ceil(TMAX./src1.ExposureTime);

%% CONNECT BASLER CAMERA

vid2 = videoinput('gentl', 1, 'Mono8');
% vid2 = videoinput('gentl', 1, 'Mono12');
src2 = getselectedsource(vid2);

src2.AcquisitionFrameRateEnable = 'True';
src2.AutoFunctionROIUseBrightness = 'False';



% Set up pixel binning to reduce the data size
src2.BinningHorizontal = 4;
src2.BinningVertical = 4;
src2.BinningHorizontalMode = 'Average';  %'sum'
src2.BinningVerticalMode = 'Average';


%restrict FOV
src2.CenterY = 'False';
src2.CenterX = 'False';
vid2.ROIPosition = [60 0 200 150];% goniometer up
% vid2.ROIPosition = [60 30 200 150]; %position without adjusting
% goniometer

src2.ExposureTime = 4800; 
vid2.FramesPerTrigger = 1;
samplerate = 200;
src2.AcquisitionFrameRate = samplerate;
src2.Gain = 15; % range = [0, 23.9]

vid2.TriggerRepeat = Inf;

% set up triggering
src2.TriggerMode = 'On';
triggerconfig(vid2, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
src2.TriggerMode = 'On';
src2.TriggerSource = 'Line3';
src2.TriggerSelector = 'FrameStart';

src2.AcquisitionFrameRateEnable = 'False';%%%%%

vid_src2 = getselectedsource(vid2);
vid_src2.ExposureAuto = 'Off';

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
    
    % hamamatsu camera load params
    filename1 = [stimid '_trial' num2str(countid) '_' exptime '.mj2'];
    vid1.LoggingMode = 'disk&memory';
    diskLogger1 = VideoWriter([filesaveloc filename1], 'Motion JPEG 2000');
    diskLogger1.FrameRate = 100;%samplerate;
    vid1.DiskLogger = diskLogger1;
    % basler camera load params
    filename2 = [stimid '_trial' num2str(countid) '_' exptime '_basler.mj2'];
    vid2.LoggingMode = 'disk&memory';
    diskLogger2 = VideoWriter([filesaveloc2 filename2], 'Motion JPEG 2000');
    diskLogger2.FrameRate = samplerate;
    vid2.DiskLogger = diskLogger2;
    
    
    
    
    
    %image each trial
    preview(vid1);
    start(vid1);
   
     pause(1);
    preview(vid2);
   
    start(vid2);
    
    timeflag = 0;
    while timeflag<TMAX+0.5 %500 ms wiggleroom
        if ~isempty(vid1.InitialTriggerTime)
            tstart = vid1.InitialTriggerTime;
            timeflag = etime(clock,tstart);
        else
            timeflag = 0;
        end
%         nframes = vid.FramesAcquired;
    end
    
    % hamamatsu data save
    data1 = getdata(vid1,vid1.FramesAvailable);
    data1 = squeeze(data1);
    filenametiff1 = [filesaveloc stimid '_trial' num2str(countid) '_' exptime '.tiff'];
    saveastiff(data1, filenametiff1);
    
    % basler data save
    data2 = getdata(vid2,vid2.FramesAvailable);
    data2 = squeeze(data2);
    filenametiff2 = [filesaveloc2 stimid '_trial' num2str(countid) '_' exptime '_basler.tiff'];
    saveastiff(data2, filenametiff2);
    
    stoppreview(vid1);
    stop(vid1);
    
    stoppreview(vid2);
    stop(vid2);
    
    countid = countid +1;
end







