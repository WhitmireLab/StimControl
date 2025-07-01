classdef (HandleCompatible) CameraComponent < HardwareComponent
% Generic wrapper class for camera objects

properties (Access = public)
end

properties (Access = protected)
    Status
    LastAcquisition
    HandleClass = ''
end

methods (Access = public)
function obj = CameraComponent(varargin)  
    p = obj.GetBaseParser();
    % add device-specific parameters here
    parse(p, varargin{:});
    params = p.Results;
    % extract device-specific parameters here
    obj = obj.CommonInitialisation(params);
    if ~params.Abstract
        obj = obj.Configure('Struct', params.Struct);
    end
end

% Initialise device
function obj = Configure(obj, varargin)
    strValidate = @(x) ischar(x) || isstring(x);
    p = inputParser;
    addParameter(p, 'Config', '', strValidate);
    addParameter(p, 'Struct', []);
    parse(p, varargin{:});
    params = p.Results;

    obj.Status = "loading";

    %---device---
    if isempty(obj.SessionHandle) || ~isempty(params.Struct)
        % if the camera is uninitialised or the params have changed
        camstr = obj.GetConfigStruct(params.Struct);

        obj.ConfigStruct = camstr;
        imaqreset
        if ~contains(imaqhwinfo().InstalledAdaptors, camstr.Adaptor)
            error("Camera adaptor %s not installed. Installed adaptors: %s", ...
                camstr.Adaptor, imaqhwinfo.InstalledAdaptors{:});
        end
        vidObj = videoinput(camstr.Adaptor);
        src = getselectedsource(vidObj);
        if contains(camstr.Adaptor, 'pcocameraadaptor')
            clockSpeed = set(src,'PCPixelclock_Hz');
            [~,idx] = max(str2num(cell2mat(clockSpeed))); %get fastest clockspeed
            src.PCPixelclock_Hz = clockSpeed{idx}; %fast scanning mode
            src.E2ExposureTime = 1000/str2double(app.FrameRate.Value) * 1000; %set framerate
            if isfield(camstr, 'Binning')
                bin = str2double(camstr.Binning);
                try 
                    src.B1BinningHorizontal = num2str(bin);
                    src.B2BinningVertical = num2str(bin);
                catch
                    src.B1BinningHorizontal = num2str(bin,'%02i');
                    src.B2BinningVertical = num2str(bin,'%02i');
                end
            end
        elseif contains(camstr.Adaptor, 'gentl')
            src.Gain = str2double(camstr.Gain);
            src.AutoTargetBrightness = 5.019608e-01;
            if isfield(camstr, 'Binning')
                src.BinningHorizontal = str2double(camstr.Binning);
                src.BinningVertical = str2double(camstr.Binning);
            end
        else
            %TODO fill out GENERIC CAMERAS
        end
        if isempty(camstr.ROIPosition)
            vidRes = get(vidObj,'VideoResolution');
            camstr.ROIPosition = [0 0 vidRes];
        end
        set(vidObj,'TriggerFrameDelay',camstr.TriggerFrameDelay);
        set(vidObj,'FrameGrabInterval',camstr.FrameGrabInterval);
        set(vidObj,'TriggerRepeat',camstr.TriggerRepeat);
        set(vidObj,'ROIposition',camstr.ROIPosition);
        set(vidObj,'FramesPerTrigger',str2double(camstr.FramesPerTrigger));
        vidObj.FramesAcquiredFcnCount = camstr.FrameGrabInterval;
        vidObj.FramesAcquiredFcn = @obj.ReceiveFrame;
        switch camstr.TriggerMode
            %TODO FURTHER INTO THIS AND FIND THE DOCUMENTATION
            case "hardware"
                src.LineSelector = camstr.TriggerLine;
                src.LineMode = "Input";
                src.TriggerSelector = camstr.TriggerSelector;
                src.TriggerMode = "On";
                src.TriggerSource = camstr.TriggerLine;
                src.TriggerActivation = camstr.TriggerActivation;
            case "manual" %TODO TEST THESE
                src.TriggerSource = "Software";
                src.TriggerSelector = camstr.TriggerSelector;
                src.TriggerActivation = "none";
            case "immediate" %TODO TEST THESE
                src.LineSelector = camstr.OutputLine;
                src.LineMode = "Output";
                src.TriggerActivation = "none";
        end
        triggerconfig(vidObj,camstr.TriggerMode);
        obj.SessionHandle = vidObj;
        obj.Status = "ok";
    end
    
    % ---display---
    if ~isempty(obj.SessionHandle)
        obj.PrintInfo();
    end
end

% Start device
function Start(obj)
    %TODO if in protocol vs out.
    if ~isrunning(obj.SessionHandle)
        start(obj.SessionHandle);
    end
    obj.FrameCount = 1;
end

% Stop device
function Stop(obj)
    try %TODO CHECK WHICH OF THESE WORKS?
        stoppreview(obj.SessionHandle);
    end
    try
        closepreview(obj.SessionHandle);
    end
    if ~isempty(obj.SessionHandle)
        stop(obj.SessionHandle);
    end
end

% Complete reset. Clear device.
function Clear(obj)
    obj.Stop();
    imaqreset;
end

% Gets current device status
% Options: ok / ready / running / error / empty / loading
function status = GetStatus(obj)
    if obj.Status == "error" || obj.Status == "loading"
        status = obj.Status;
    elseif isempty(obj.SessionHandle)
        status = "empty";
    elseif isrunning(obj.SessionHandle)
        status = "ready";
        if toc(obj.LastAcquisition) > seconds(1)
            status = "running";
        end
    else
        status = "ok";
    end
end

function VisualiseOutput(obj, varargin)
    p = inputParser;
    p.addParameter("Plot", []);
    p.parse(varargin{:});
    target = p.Results.Plot;
    if isempty(obj.SessionHandle)
        return;
    end

    vidRes = get(app.vidObj,'VideoResolution');
    nbands = get(app.vidObj,'NumberOfBands');

    if ~isempty(target)
        imshow(zeros(vidRes(2),vidRes(1),nbands),[],'parent',target);
        preview(obj.SessionHandle, target);
        axis(target, "tight");
    else
        imshow(zeros(vidRes(2),vidRes(1),nbands),[]);
        preview(obj.SessionHandle);
        axis("tight");
    end
end

% Change device parameters
function obj = SetParams(obj, varargin)
    obj.Status = "loading";
    restarters = ["Binning", "TriggerMode", "ROIPosition"];
    vidObj = obj.SessionHandle;
    src = getselectedsource(vidObj);
    for i = 1:length(restarters)
        if contains(varargin, restarters(i))
            Stop(obj);
            break
        end
    end
    for i = 1:length(varargin):2
        param = varargin{i};
        val = varargin{i+1};
        if ~contains(getfields(obj.ConfigStruct), param)
            error("Could not set field %s. Valid fields are: %s", param, getfields(obj.ConfigStruct));
        else
            obj.ConfigStruct = setfield(obj.ConfigStruct, param, val);
        end
        switch param
            case "SavePath"
                obj.SavePath = val;
            case "Binning"
                continue
            case "BinningType"
                continue
            case "Gain"
                src.Gain = val;
            case "ExposureTime"
                src.ExposureTime = val;
            case "OutputLine"
                src.LineSelector = val;
                src.LineMode = "Output";
            case "TriggerActivation"
                src.TriggerActivation = val;
            case "TriggerLine"
                src.LineSelector = val;
                src.LineMode = "Input";
                src.TriggerSource = val;
            case "TriggerMode"
                switch val
                    case "hardware"
                        src.TriggerSource = obj.ConfigStruct.TriggerLine;
                        src.TriggerMode = "On";
                    case "manual" %TODO TEST THESE
                        src.TriggerSource = "Software";
                    case "immediate" %TODO TEST THESE
                end
                triggerconfig(vidObj,val);
            case "TriggerSelector"
                src.TriggerSelector = val;
            case "ROIPosition"
                if isempty(val)
                    % reset ROI
                    vidRes = get(obj.SessionHandle,'VideoResolution');
                    val = [0 0 vidRes];
                end
                    set(obj.SessionHandle, param, val);
            otherwise
                %FramesPerTrigger, TriggerFrameDelay,
                %FrameGrabInterval, TriggerRepeat,
                set(obj.SessionHandle, param, val);
        end

        if contains(varargin, "Binning")
            imaqreset;
            obj = obj.Configure("Struct", obj.ConfigStruct);
        end
    end
    obj.Status = "ok";
end

% get current device parameters for saving
function objStruct = GetParams(obj)
    objStruct = obj.ConfigStruct;
end

% Print device information
function PrintInfo(obj)
    obj.SessionHandle
end

function GetInspector(obj)
    inspect(obj.SessionHandle);
    inspect(obj.ConfigStruct);
end

function LoadProtocol(obj, varargin)
    %TODO THIS
    % depending on trigger type this could be dicey? hardware is
    % taken care of with daq but software is gonna be rough
end

function componentProperties = GetComponentProperties(obj)
    % https://au.mathworks.com/help/imaq/videoinput.html
    componentProperties = struct( ...
    Adaptor = struct( ...
        default     = 'gentl', ...
        allowable   = imaqhwinfo().InstalledAdaptors, ... 
        validatefcn = @(x) isstring(x) || ischar(x), ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Any MATLAB-supported camera adaptor."), ...
    Binning = struct( ...
        default     = 1, ...
        allowable   = {1, 2, 4}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) strcmpi(propStruct.Adaptor, 'gentl') || ...
                        strcmpi(propStruct.Adaptor, 'pcocameraadaptor'), ...
        required    = @(propStruct) true, ...
        note        = ""), ...
    BinningType = struct( ...
        default     = "Sum", ...
        allowable   = {{}}, ... %TODO unknown as yet.
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) propStruct.Binning.dependencies == true, ...
        required    = @(propStruct) true, ...
        note        = ""), ...
    DeviceName = struct( ... 
        default     = "", ...
        allowable   = {{}}, ... 
        validatefcn = @(x) true, ... 
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) false, ...
        note        = "Only needed to distinguish between cameras"), ...
    ExposureTime = struct( ...
        default     = "10000", ...
        allowable   = {{}}, ...
        validatefcn = @(x) ~isNan(str2double(x)), ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) false, ... 
        note        = "Only needed to distinguish between cameras"), ...
    FramesPerTrigger = struct( ...
        default     = "1", ...
        allowable   = {"1"}, ...
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) strcmpi(propStruct.TriggerMode, "hardware") || ...
                        strcmpi(propStruct.TriggerMode, "manual"), ...
        required    = @(propStruct) true, ... 
        note        = "Ideally any number will be permitted but not yet"), ...
    Gain = struct( ...
        default     = "20", ...
        allowable   = {{}}, ...
        validatefcn = @(x) ~isNan(str2double(x)) && ...
                        str2double(x)>=0 && str2double(x)<=36, ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) false, ... 
        note        = "dB. Max of 36."), ...
    OutputLine = struct( ...
        default     = "Line3", ...
        allowable   = [], ...
        validatefcn = @(propStruct) true, ...
        dependencies= @(propStruct) strcmpi(propStruct.TriggerMode, "immediate"), ...
        required    = @(propStruct) false, ... 
        note        = "Depends on specific camera hardware."), ...
    TriggerActivation = struct( ...
        default     = "RisingEdge", ...
        allowable   = [], ... %TODO
        validatefcn = @(propStruct) true, ... 
        dependencies= @(propStruct) strcmpi(propStruct.TriggerMode, "hardware"), ...
        required    = @(propStruct) false, ... 
        note        = "Depends on specific camera hardware."), ...
    TriggerMode = struct( ...
        default     = "hardware", ...
        allowable   = ["hardware", "manual", "immediate"], ...
        validatefcn = [], ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) true, ... 
        note        = "hardware: GPIO-triggered, manual: software-triggered, " + ...
                        "immediate: camera-driven acquisition."), ...
    TriggerFrameDelay = struct( ...
        default     = 0, ...
        allowable   = [], ...
        validatefcn = @(x) isnumeric(x), ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) true, ... 
        note        = ""), ...
    FrameGrabInterval = struct( ...
        default     = 10, ...
        allowable   = [], ...
        validatefcn = [], ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) true, ... 
        note        = "Number of frames to have captured before " + ...
                        "activating framesavailable"), ...
    TriggerRepeat = struct( ...
        default     = 100000000, ...
        allowable   = [], ...
        validatefcn = [], ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) true, ... 
        note        = "Number of frames to capture before the camera closes itself. " + ...
                        "Ideally indefinite but I can't figure out how to do that"), ...
    ROIPosition = struct( ...
        default     = [], ...
        allowable   = [], ...
        validatefcn = [], ...
        dependencies= @(propStruct) true, ...
        required    = @(propStruct) true, ... 
        note        = "ROI, set programmatically. If empty, defaults to full camera FOV"), ...
    TriggerSelector = struct( ...
        default     = "FrameStart", ...
        allowable   = [], ... #TODO
        validatefcn = @(propStruct) true, ...
        dependencies= @(propStruct) strcmpi(propStruct.TriggerMode, "hardware") || ...
                        strcmpi(propStruct.TriggerMode, "manual"), ...
        required    = @(propStruct) true, ... 
        note        = ""));
end


end

methods (Access = private)
function name = GetCameraName(obj, adaptorName)
    info = imaqhwinfo;
    nameCheck = contains(info.InstalledAdaptors, adaptorName);
    name = '';
    if any(nameCheck)
        name = adaptorName;
    else
        warning("Target camera adaptor %s not available. Searching for other cameras.", adaptorName);
        if length(info.InstalledAdaptors) == 1
            name = info.InstalledAdaptors{1};
        elseif obj.Required
            out = listdlg('Name', 'Please select your camera', ...
                'SelectionMode','single','liststring',info.InstalledAdaptors,'listsize',[300 300]);
            if ~isempty(out)
                name = info.InstalledAdaptors{out};
            end
        end
    end
end

function ReceiveFrame(obj, src, vidObj)
    try
        imgs = getdata(src,src.FramesAvailable); 
        obj.LastAcquisition = tic;
        numImgs = size(imgs);
        numImgs = numImgs(4);
        for i = 1:numImgs
            imname = strcat(obj.SavePath, filesep, string(obj.FrameCount), '_', string(datetime(datetime, "Format", 'yyyyMMdd_HHmmss.SSS')), ".TIFF");
            imwrite(imgs(:,:,:,i),imname);
            obj.FrameCount = obj.FrameCount + 1;
        end
    catch exception
        obj.Status = "error";
        disp("Encountered an error imaging.")
        dbstack
        disp(exception.message)
    end
end
end
end