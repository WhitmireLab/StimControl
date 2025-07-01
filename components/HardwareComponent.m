classdef (Abstract, HandleCompatible) HardwareComponent
%Abstract class representing all hardware components

properties (Access = public)
    Name
    SessionHandle
    SavePath
    Required
    ComponentProperties
end
properties(Access=protected)
    Abstract
    ConfigStruct
end
properties (Abstract, Access = protected)
    HandleClass
end

methods(Access=public)
% All device constructors can take the following arguments, 
% as well as device-specific arguments:
% 'Required'    (logical)   whether to throw errors as errors or warnings
% 'Handle'      (handle)    the handle to an existing session of that component type
% 'Struct'      (struct)    struct containing initialisation params
% 'SavePath'    (string)    the path to save outputs
% 'Abstract'    (logical)   if false, does not attempt to initialise a
%                           session with the hardware but retain access to class logic.
function p = GetBaseParser(obj)
    p = inputParser;
    strValidate = @(x) ischar(x) || isstring(x);
    handleValidate = @(x) (contains(class(x), obj.HandleClass)) || isempty(x);
    addParameter(p, 'Required', true, @islogical);
    addParameter(p, 'Handle', [], handleValidate);
    addParameter(p, 'Struct', []);
    addParameter(p, 'SavePath', strValidate);
    addParameter(p, 'Abstract', false, @islogical);
end

function obj = CommonInitialisation(obj, params)
    obj.SavePath = params.SavePath;
    obj.Required = params.Required;
    obj.SessionHandle = params.Handle;
    obj.Abstract = params.Abstract;
    obj.ComponentProperties = obj.GetComponentProperties();
end

function componentStruct = GetDefaultComponentStruct(obj)
    componentStruct = struct();
    fs = fields(obj.ComponentProperties);
    for i = 1:length(fs)
        attr = getfield(obj.ComponentProperties, fs{i});
        d = {attr.default};
        componentStruct = setfield(componentStruct, fs{i}, d{1});
    end
end

function configStruct = GetConfigStruct(obj, configStruct)
    %Fill out a config struct with existing or default values.
    default = obj.GetDefaultComponentStruct();
    if isempty(configStruct)
        warning("No %s config provided. Using default setup", class(obj));
        configStruct = default;
    else
        % fill in required fields with defaults.
        props = obj.GetComponentProperties();
        propFields = fields(props);
        for i = 1:length(propFields)
            f = propFields{i};
            if ~isfield(configStruct, f) %TODO & field is needed?
                if isfield(obj.ConfigStruct, f)
                    % if the property is already defined by the object, use that value
                    val = obj.ConfigStruct.(f);
                else
                    % else, use default value
                    val = props.(f).default;
                end
                configStruct = setfield(configStruct, f, val);
            end
        end
    end
end
end

methods (Abstract, Access=public)
% Initialise hardware session
Configure(obj, varargin)

% Start device
Start(obj)

% Stop device
Stop(obj)

% Complete reset. Clear device
Clear(obj)

% Change device parameters
SetParams(obj, varargin)

% get current device parameters for saving
objStruct = GetParams(obj)

% gets current device status
% Options: ok / ready / running / error / empty / loading
status = GetStatus(obj)

% Dynamic visualisation ofthe object output. Can target a specific
% plot using the "Plot" param.
VisualiseOutput(obj, varargin)

% Print device information
PrintInfo(obj)

% Preload an experimental protocol
LoadProtocol(obj, varargin)

GetComponentProperties(obj)
end
end