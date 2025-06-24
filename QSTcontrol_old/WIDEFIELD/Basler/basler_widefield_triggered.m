% clear
% imaqreset
%% SET PARAMETERS
% widefield_setparams;


% animalid = 'nan';
% stimid = 'TEST';
% TMAX = 5; %trial duration (10 seconds)
% NTRIAL = 3;
% 
% 
% % file directory
% filesavedir = 'C:\Users\2P_Resonant\Data\WidefieldRig\';
% yy =num2str(year(datetime));
% mm = num2str(month(datetime));
% dd = num2str(day(datetime));
% if numel(mm)<2
%     mm = ['0' mm];
% end
% if numel(dd)<2
%     dd = ['0' dd];
% end
% expdate = [yy mm dd];
% filesaveloc = [filesavedir animalid filesep expdate filesep];
% if ~isfolder(filesaveloc)
%     mkdir(filesaveloc);
% end


%% CONNECT CAMERA

% vid = videoinput('gentl', 1, 'Mono8');
vid = videoinput('gentl', 1, 'Mono12');
src = getselectedsource(vid);

src.AcquisitionFrameRateEnable = 'True';
src.AutoFunctionROIUseBrightness = 'False';

% Set up pixel binning to reduce the data size
src.BinningHorizontal = 4;
src.BinningVertical = 4;
src.BinningHorizontalMode = 'Average';  %'sum'
src.BinningVerticalMode = 'Average';

%% set acquisition properties
src.ExposureTime = 35000;
vid.FramesPerTrigger = 1;
src.AcquisitionFrameRate = 20;
vid.TriggerRepeat = Inf;

% set up triggering
src.TriggerMode = 'On';
triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
src.TriggerMode = 'On';
src.TriggerSource = 'Line3';
src.TriggerSelector = 'FrameStart';

%% SET UP ROI
%
resolution = vid.VideoResolution;
Ax = resolution(1);
Ay = resolution(2);

%Region of interest, centered
ROIy = 1024; 
ROIx = 1024;

vid_src = getselectedsource(vid);
vid_src.ExposureAuto = 'Off';
% centre = [Ax/2 - ROIx/2, Ay/2 - ROIy/2, ROIx, ROIy];
centre = [201 201 200 200];
vid.ROIPosition = centre;
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
    filename = [stimid '_trial' num2str(countid) '_' exptime '.avi'];
    vid.LoggingMode = 'disk';
    diskLogger = VideoWriter([filesaveloc filename], 'Grayscale AVI');
    vid.DiskLogger = diskLogger;
    diskLogger.FrameRate = 20;
    
    
    
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
    
    stoppreview(vid);
    stop(vid);
    
    countid = countid +1;
end

%% Load Data and analyze





