classdef (Abstract, HandleCompatible) HardwareComponent < handle
% Abstract class representing all hardware components
properties(Abstract, Constant, Access = public)
    ComponentProperties
end

properties (Access = public)
    Name
    SessionHandle
    SavePath
    TrialPrefix
    Abstract
    ConfigStruct
    PreviewPlot = []
    Previewing = false
    statusPanel = [];
    ComponentID
    TriggerTimer = [];
    ConnectedDevices = [];
end

properties(Access=public, Dependent)
    SavePrefix
    HasAdditionalConfig
end

properties(Access=protected)
    statusHandles = [];
end

properties(Constant, Access=protected)
    StatusColourMap = struct( ...
        'abstract', '#C0C0C0',...
        'connected', '#008080', ...
        'unconnected', '#808080', ...
        'uninitialised', '#008888', ...
        'ready', '#00FF00', ...
        'running', '#FFA500', ...
        'error', '#A80000', ...
        'misc', '#FF66B2');
end


methods(Access=public)

function Debug(obj)
    keyboard;
end

function p = GetBaseParser(obj)
    % All device constructors can take the following arguments:
    % 'Required'    (logical, true)     whether to throw errors as errors or warnings
    % 'Handle'      (handle, [])        the handle to an existing session of that component type
    % 'ConfigStruct'(struct, [])        struct containing initialisation params - see
    %                                   ComponentProperties
    % 'SavePath'    (string, '')        the path to save outputs
    % 'Abstract'    (logical, false)    if false, does not attempt to initialise a
    %                                   session with hardware but retains access to class logic.
    % Initialise    (logical, true)     if true, session with hardware will be
    %                                   immediately started upon object creation.
    %                                   If false, can be initialised later using obj.Configure
    p = inputParser;
    strValidate = @(x) ischar(x) || isstring(x);
    handleValidate = @(x) (contains(class(x), obj.HandleClass)) || isempty(x);
    addParameter(p, 'Required', true, @islogical);
    addParameter(p, 'Handle', [], handleValidate);
    addParameter(p, 'ConfigStruct', []);
    addParameter(p, 'SavePath', '', strValidate);
    addParameter(p, 'Abstract', false, @islogical);
    addParameter(p, 'Initialise', true, @islogical);
    addParameter(p, 'ComponentID', false, @(x) ischar(x) || isstring(x) || islogical(x));
end

% Initialise the component. Will attempt to start a session with the hardware
function obj = Initialise(obj, params)
    obj.SavePath = params.SavePath;
    obj.SessionHandle = params.Handle;
    obj.Abstract = params.Abstract;
    obj.ConfigStruct = obj.GetConfigStruct(params.ConfigStruct);
    if all(~params.ComponentID)
        obj.ComponentID = obj.GetComponentID;
    else
        obj.ComponentID = params.ComponentID;
    end
end

function configStruct = GetDefaultConfigStruct(obj)
    configStruct = struct();
    fs = fields(obj.ComponentProperties);
    for i = 1:length(fs)
        attr = getfield(obj.ComponentProperties, fs{i});
        d = {attr.default};
        configStruct = setfield(configStruct, fs{i}, d{1});
    end
end

function configStruct = GetConfigStruct(obj, varargin)
    %Fill out a config struct with existing or default values.
    default = obj.GetDefaultConfigStruct();
    if isempty(varargin) || isempty(varargin{1})
        if isempty(obj.ConfigStruct)
            warning("No %s config provided. Using default setup", class(obj));
            configStruct = default; 
        else
            configStruct = obj.ConfigStruct;
        end
    else
        configStruct = varargin{1};
    end
    % fill in required fields with defaults.
    props = obj.ComponentProperties;
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

function status = GetStatus(obj)
% Gets current device status. 
% Possible statuses:
%   abstract        not associated with a device
%   unconnected     device session not initialised
%   uninitialised   (DAQs) - session connected, but no channels set.
%   connected       device session initialised; not ready to start trial
%   ready           device session initialised, trial loaded
%   running         currently running a trial
%   error           error encountered
    if obj.Abstract
        status = 'abstract';
    elseif isempty(obj.SessionHandle) || ~isvalid(obj.SessionHandle)
        status = 'unconnected';
    else
        status = obj.GetSessionStatus();
    end
    if isempty(status)
        status = 'unknown';
        %DEBUG: you should never get here.
        dbstack
        keyboard;
    end
end

function componentID = SanitiseComponentID(obj, componentID)
    spaceChars = '- ';
    illegalChars = '~`!#$%^&*()+=[]{}|\/?,.<>:";';
    for ci = 1:length(spaceChars)
        componentID = replace(componentID, spaceChars(ci), '_');
    end
    for ci = 1:length(illegalChars)
        componentID = erase(componentID, illegalChars(ci));
    end
end

function CreateStatusDisplay(obj)
    % Creates the status visualiser for the HardwareComponent. 
    % Assumes a smallish squareish GUI object for the parent
    % Assumes obj.statusPanel is set

    obj.statusPanel.Title = obj.ConfigStruct.ProtocolID;

    obj.statusHandles.grid = uigridlayout(obj.statusPanel, ...
        'RowHeight', {'1x', '1x'}, ...
        'ColumnWidth', {'0.2x', '1x'}, ...
        'Padding', [0 0 0 0], ...
        'RowSpacing', 2);
    obj.statusHandles.lamp = uilamp(obj.statusHandles.grid, ...
        'Layout', matlab.ui.layout.GridLayoutOptions( ...
            'Row', 1, ...
            'Column', 1));
    obj.statusHandles.label = uilabel(obj.statusHandles.grid, ...
        "Text", obj.GetStatus, ...
        'Layout', matlab.ui.layout.GridLayoutOptions( ...
            'Row', 1, ...
            'Column', 2), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'center');
end

function UpdateStatusDisplay(obj)
    status = obj.GetStatus;
    obj.statusHandles.label.Text = status;
    if ~isfield(obj.StatusColourMap, status)
        status = 'misc';
    end
    obj.statusHandles.lamp.Color = obj.StatusColourMap.(status);
end


% Updates the preview to move its target plot.
function UpdatePreview(obj, varargin)
    p = inputParser;
    addOptional(p, 'newPlot', []);
    parse(p, varargin{:});
    newPlot = p.Results.newPlot;
    restart = obj.Previewing;

    obj.StopPreview();
    if ~isempty(newPlot)
        obj.PreviewPlot = newPlot;
    end
    % pause(0.5); % TODO fix: temporary measure - wait for hardware to update.
    if restart
        obj.StartPreview();
    end
end

function obj = SetParam(obj, param, val)
    if ~isfield(obj.ComponentProperties, param)
        error("Invalid field: %s", param);
    elseif ~obj.ComponentProperties.(param).isValid(val)
        error("Invalid value for parameter %s", param);
    elseif ~obj.ComponentProperties.(param).dynamic
        warning("Changing param %s requires device restart. Restarting device...", param);
    else
        paramStruct = struct(param, val);
        obj.SetParams(paramStruct);
    end
end

% Save any additional device parameters to given savepath
% defaults to nothing - most hardware won't need this
function SaveAuxiliaryConfig(obj, filepath)
    return;
end

function CreateSoftwareTriggerTimer(obj, rate)
    % creates a timer that generates a single trigger signal at a given interval. 
    % Used when component is set to software-triggered or doesn't support pre-loading data.
    % NOTE: the timing for this will be much less reliable & consistent.
    if ~isempty(obj.TriggerTimer) && isvalid(obj.TriggerTimer)
        stop(obj.TriggerTimer);
        delete(obj.TriggerTimer);
    end
    period = 1/rate;
    obj.TriggerTimer = timer(...
            'StartDelay',       0, ...
            'Period',           period, ...
            'ExecutionMode',    'fixedRate', ...
            'TimerFcn',         @obj.SoftwareTrigger, ...
            'BusyMode',         'drop', ...
            'Name',             obj.ConfigStruct.ProtocolID); %NB TODO: QUEUE? 
end

function TrialMaintain(obj)
    % for components that may need to load additional data during a trial 
    % (e.g. serial components). By default, does nothing. 
end

function EndTrial(obj)
    % for components that may need additional data saved after a trial ends
    % - e.g. cameras that only write to file every 10 frames.
end

% get current device parameters for saving
function objStruct = GetParams(obj)
    objStruct = setfield(obj.ConfigStruct, 'ComponentID', obj.ComponentID);
end

function UpdateSavePath(obj)
    % Updates the component's savepath. Does nothing unless the component 
    % saves to a sub-folder within the experiment;
    % in that case make the subfolder. See CameraComponent
end

function fig = CreateConfigFigure(obj)
% CREATECONFIGFIGURE returns the handle to a figure providing
% additional config information. If no additional configuration is
% required, returns an empty handle.
fig = [];
end
end

methods
function set.SavePrefix(obj, val)
    obj.TrialPrefix = val;
    obj.UpdateSavePath;
end

function out = get.SavePrefix(obj)
    out = obj.TrialPrefix;
end

function out = get.HasAdditionalConfig(obj)
    % HASADDITIONALCONFIG returns whether the object has additional config
    % data to display in a separate figure.
    mObj = metaclass(obj);
    methodMeta = mObj.MethodList(strcmp({mObj.MethodList.Name}, 'CreateConfigFigure'));
    if strcmp(methodMeta.DefiningClass.Name, class(childObj))
        out = true;
    else
        out = false;
    end
end
end

methods(Static, Abstract, Access=public)
    % Complete reset. Clear device and all handles of device type.
    ClearAll()

    % Finds all available hardware components of the given type.
    components = FindAll(varargin)
end

methods (Abstract, Access=public)
% Initialise hardware session. By default, accepts two args:
% 'ConfigStruct'        (struct)    a struct of all device settings you want set
% 'KeepHardwareConfig'  (logical)   [TODO, LOGIC NOT IMPLEMENTED] determines behaviour for attributes 
%                                   not explicitly set with ConfigStruct.
%                                   If false, enforces default settings for
%                                   hardware configuration. If true,
%                                   retains the hardware's existing
%                                   settings
InitialiseSession(obj, varargin)

% Start device. WHEN CALLING: start the trigger device last
StartTrial(obj)

% Stop device during trial and flush any remaining data.
Stop(obj)

% Change device parameters
SetParams(obj, varargin)

% Dynamic visualisation of the object output
StartPreview(obj)

% Dynamic visualisation of the object output
StopPreview(obj)

% Print device information
PrintInfo(obj)

% Preload a single trial
LoadTrialFromParams(obj, componentTrialData, genericTrialData, preloadDevice)

% Close connection to the hardware session
Close(obj)
end

methods(Abstract, Access=protected)

% gets current device status
% Options: ready / running / error
status = GetSessionStatus(obj)

componentID = GetComponentID(obj)

SoftwareTrigger(obj, ~, ~)

end
end