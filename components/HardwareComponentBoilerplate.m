classdef (HandleCompatible) Component < HardwareComponent
%UNTITLED2 Summary of this class goes here
%   Detailed explanation goes here

properties (Access = public)
Name
SessionHandle
SavePath
Required
Status
ComponentProperties = obj.GetComponentProperties()
end

properties (Access = protected)
HandleClass = ''
Abstract
end

methods (Access = public)
function obj = Component(varargin)
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

% Configure device
function Configure(obj, varargin)
    %TODO STOP/START
    strValidate = @(x) ischar(x) || isstring(x);
    p = inputParser;
    addParameter(p, 'Struct', []);
    parse(p, varargin{:});
    params = p.Results;

    %---device---
    if isempty(obj.SessionHandle) || ~isempty(params.Struct)
        % if the component is uninitialised or the params have changed
        configStruct = obj.GetConfigStruct(params.Struct);

        obj.SessionHandle = daq(name);
        obj.SessionHandle.Rate = rate;
    end
    
    %---display---
    if ~isempty(obj.SessionHandle)
        obj.PrintInfo();
    end
    
end

% Start device
function Start(obj)

end

%Stop device
function Stop(obj)

end

% Complete reset. Clear device
function Clear(obj)

end

% Change device parameters
function SetParams(obj, varargin)

end

% get current device parameters for saving
function objStruct = GetParams(obj)
    
end

% gets current device status
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

% Dynamic visualisation ofthe object output. Can target a specific
% plot using the "Plot" param.
function VisualiseOutput(obj, varargin)
    p = inputParser;
    p.addParameter("Plot", []);
    p.parse(varargin{:});
    target = p.Results.Plot;
    if isempty(obj.SessionHandle)
        return;
    end
end

% Print device information
function PrintInfo(obj)
    disp(' ')
    disp(obj.SessionHandle)
    disp(' ')
end

function LoadProtocol(obj, varargin)

end

function defaults = GetDefaultComponentStruct(obj)
   defaults = GetDefaultComponentStruct@HardwareComponent(obj);
end

function componentProperties = GetComponentProperties(obj)
    componentProperties = struct( ...
    PropertyName = struct( ...
        default     = 'defaultValue', ...
        allowable   = {'allowable', 'values'}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Put Comments Here"), ...
    PropertyNameTwo = struct( ...
        default     = 'defaultValue', ...
        allowable   = {'allowable', 'values'}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Put Comments Here") ...
   );
end
end

end