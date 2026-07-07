classdef StimControl < handle

properties (Access = protected)
    path = [];
end

properties (Access = private)
    h           = []            % GUI handles
    d           = []            % HardwareComponent handles
    p           = []            % stimulation parameters/protocol
    g           = []            % general protocol parameters
    meta        = []            % protocol metadata
    idxStim     = []            % current stimulus index
    timerStateMachine = []      % State Machine Timer
    timerGui    = []            % GUI update timer
    t           = []            % timer flags
    pids        = []            % protocol id map
    chAI
    chD
    cmdStack    = []
    name        = 'StimControl'
    pFile       = []
    isRunning   = false;
    isPaused    = false;
    hardwareParams
    trialIdx    = 1;            % index of trial in trial sequence.
    tLastStatusChange = 0;      % for timers
    tOffset     = 0;            % for pausing
    taskPool    = [];
    f           = [];           % state machine flags
    createChans = true;         % whether to create DAQ channels when loading a protocol (set on channel creation, reset on in-program reload)

end

properties (Dependent, Access=private)
    animalID
    experimentID
    trialNum                    % number of trial as defined in protocol file
    dirAnimal
    dirExperiment
    status
end

methods
    function obj = StimControl(varargin)
        %% add necessary program paths.
        obj.path.base = mfilename('fullpath');
        endIdx = strfind(obj.path.base, [filesep '@StimControl']) - 1;
        obj.path.base = obj.path.base(1:endIdx);
        addpath(obj.path.base);
        addpath(genpath(fullfile(obj.path.base, 'components')))
        addpath(genpath(fullfile(obj.path.base, 'common')))
        addpath(genpath(fullfile(obj.path.base,'@StimControl', 'icons')))
        clc
        disp('Welcome to StimControl')

        %% Initialise component manager
        obj.d = ComponentManager();
        hFigs = findall(0,'type','figure');        
        if isempty(hFigs)
            % this is the only app running, resets can be safely run 
            % without messing with other apps.
            obj.d.ClearAll();
        end
        
        %% Initialise Path
        obj.path.dirData = fullfile(getenv('UserProfile'),'Desktop','logs');
        configBase = [obj.path.base filesep 'config'];
        obj.path.paramBase = [configBase filesep 'component_params'];
        obj.path.protocolBase  = [configBase filesep 'experiment_protocols'];
        obj.path.sessionBase = [configBase filesep 'session_presets'];
        obj.path.componentMaps = [configBase filesep 'component_protocol_maps'];

        %% Create data directory
        if ~exist(obj.path.dirData,'dir')
            mkdir(obj.path.dirData)
        end

        %% Reset state machine flags
        obj.f.stopTrial = false;
        obj.f.startTrial = false;
        obj.f.passive = false;
        obj.f.pause = false;
        obj.f.resume = false;
        obj.f.runningExperiment = false;
        obj.f.trialLoaded = false;
        obj.f.trialFinished = false;

        %% Find available hardware
        disp("Initialising Available Hardware...")
        obj.d = obj.d.FindAvailableHardware();
        %% Create figure and get things going
        disp("Creating figure...")
        createFigure(obj)
        
        %% timer flags
        obj.t = struct( "intervalElapsed",  0,      ...
                        "intervalTarget",   0,      ...
                        "experimentElapsed",   0,      ...
                        "experimentTarget",   0);

        %% state machine timer
        obj.timerStateMachine = timer(...
            'StartDelay',       0, ...
            'Period',           0.5, ...
            'ExecutionMode',    'fixedDelay', ...
            'StartFcn',         @obj.timerFcnStateMachine, ...
            'TimerFcn',         @obj.timerFcnStateMachine, ...
            'Name',             'timerStateMachine');
        start(obj.timerStateMachine);

        %% GUI timer
        obj.timerGui = timer(...
            'StartDelay',       0, ...
            'Period',           0.5, ...
            'ExecutionMode',    'fixedDelay', ...
            'StartFcn',         @obj.timerFcnGui, ...
            'TimerFcn',         @obj.timerFcnGui, ...
            'Name',             'timerGui');
        start(obj.timerGui)
        
        disp("loading previous session...");
        obj.loadDefaultSession;
        obj.MapConnectedHardware;
        % obj.p2GUI;
        % obj.checkSync
        % StartPreviews(obj);
        disp("Ready")
    end
end

methods (Access = private)
    % figure creation
    createFigure(obj)
    createPanelSetupControl(obj, hPanel, ~)
    createPanelComponentConfig(obj, hPanel, ~, component)
    createPanelSessionControl(obj, hPanel, ~)
    createPanelSessionHardware(obj, hPanel, ~)
    createPanelPreview(obj, hPanel, ~)

    % app control callbacks
    callbackChangeTab(obj, src, event)
    callbackDebug(obj, src, event)
    callbackReload(obj, src, event)
    callbackUpdateComponentTable(obj, src, event)
    
    % experiment control callbacks
    callbackLoadProtocol(obj, src, event)
    callbackLoadTrial(obj, src, event)
    callbackStartStop(obj, src, event)
    callbackPauseResume(obj, src, event)
    callbackNewTrial(obj, src, event)
    callbackSelectAnimal(obj, src, event)

    % file control callbacks
    callbackLoadConfig(obj, src, event)
    callbackSaveConfig(obj, src, event)
    callbackChangeSavePath(obj, src, event)

    % hardware control callbacks
    callbackEditComponentConfig(obj, ~, ~)

    % misc
    callbackFileExit(obj,~,~)
    
    % timers
    callbackTimer(obj, ~, ~)
    timerFcnStateMachine(obj, ~, ~)
    timerFcnGuiUpdate(obj, ~, ~)
end

methods
    function filepath = get.dirAnimal(obj)
        % GET.DIRANIMAL returns the directory (string) of the current
        % animal, creating it if it does not exist.
        filepath = fullfile(obj.path.dirData,obj.animalID);
        if iscell(filepath)
            filepath = filepath{:};
        end
        if ~exist(filepath,'dir')
            mkdir(filepath)
        end
    end

    function filepath = get.dirExperiment(obj)
        % GET.DIREXPERIMENT returns the directory (string) of the current
        % experiment, creating it if it does not exist.
        if ~isfield(obj.path, 'date')
            obj.updateDateTime
        end
        tmpPath = [obj.dirAnimal filesep obj.path.date];
        if ~exist(tmpPath, 'dir')
            mkdir(tmpPath);
        end
        tmpPath = [tmpPath filesep obj.path.date '_' obj.path.time '_' obj.experimentID];
        if ~exist(tmpPath, 'dir')
            mkdir(tmpPath);
        end
        filepath = tmpPath;
    end

    function updateDateTime(obj)
        % UPDATEDATETIME updates the datetime prefix for saving outputs
        obj.updateDate;
        obj.updateTime;
    end

    function updateDate(obj)
        % UPDATEDATE updates the date prefix for saving outputs
        dt = datetime("now");
        dt.Format = "yyMMdd";
        obj.path.date = char(dt);
    end

    function updateTime(obj)
        % UPDATETIME updates the time prefix for saving outputs
        dt = datetime("now");
        dt.Format  = "HHmmss";
        obj.path.time = char(dt);
    end

    function set.experimentID(obj, val)
        % SET.EXPERIMENTID sets the identifier for the current experiment,
        % adding it to the protocol select dropdown and setting it as the
        % selected value if necessary.
        if ~contains(obj.h.protocolSelectDropDown.Items, val)
            obj.h.protocolSelectDropDown.Items{end+1} = val;
        end
        obj.h.protocolSelectDropDown.Value = val;
    end

    function out = get.experimentID(obj)
        % GET.EXPERIMENTID returns the ID of the current experiment (string, 
        % the filename minus the file extension)
        tmp = strsplit(obj.h.protocolSelectDropDown.Value, '.');
        if length(tmp) < 2
            out = tmp{:};
        else
            out = tmp{1};
        end
    end

    function set.animalID(obj, val)
        % SET.ANIMALID sets the current animal ID, adding it to the animal
        % select dropdown and setting it as the selected value if
        % necessary.
        if ~ismember(obj.h.animalSelectDropDown.Items, val)
            obj.h.animalSelectDropDown.Items{end+1} = val;
        end
        obj.h.animalSelectDropDown.Value = val;
    end

    function out = get.animalID(obj)
        % GET.ANIMALID returns (string) the ID of the currently selected
        % animal, as defined in the animal select dropdown.
        out = obj.h.animalSelectDropDown.Value;
    end

    function set.status(obj, val)
        % SET.STATUS sets the current status of StimControl, updating
        % appropriate labels, button functions, and active status of
        % relevant GUI elements. 
        % supported values: 
        % - NOT INITIALISED
        % - READY 
        % - RUNNING 
        % - INTER-TRIAL
        % - PAUSED 
        % - STOPPING 
        % - ERROR 
        % - AWAITING TRIGGER
        % - NO PROTOCOL LOADED

        obj.h.loadingLabel.Visible = 'off';
        obj.h.statusLabel.Visible = 'on';
        obj.tLastStatusChange = tic;
        val = lower(val);
        
        if strcmpi(val, 'not initialised')
            obj.h.statusLabel.Text = 'Not Initialised';
            obj.h.statusLamp.Color = '#808080'; 
            obj.h.StartStopBtn.Enable = 'off';
            obj.h.StartStopBtn.Text = 'START';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.StartSingleTrialBtn.Enable = 'off';

        elseif strcmpi(val, 'ready')
            obj.h.statusLabel.Text = 'Ready';
            obj.h.statusLamp.Color = '#00FF00';
            obj.h.StartStopBtn.Enable = 'on';
            obj.h.StartStopBtn.Text = 'START';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.StartPassiveBtn.Enable = 'on';
            obj.h.StartSingleTrialBtn.Enable = 'on';

        elseif strcmpi(val, 'running')
            obj.h.statusLabel.Text = 'Running';
            obj.h.statusLamp.Color = '#FFA500';
            obj.h.StartStopBtn.Enable = 'on';
            obj.h.StartStopBtn.Text = 'STOP';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.pauseBtn.Text = 'PAUSE';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.StartSingleTrialBtn.Enable = 'off';

        elseif strcmpi(val, 'inter-trial')
            obj.h.statusLabel.Text = 'Inter-trial';
            obj.h.statusLamp.Color = '#FFFFFF';
            obj.h.StartStopBtn.Enable = 'on';
            obj.h.StartStopBtn.Text = 'STOP';
            obj.h.pauseBtn.Enable = 'on';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.pauseBtn.Text = 'PAUSE';
            obj.h.StartSingleTrialBtn.Enable = 'off';

        elseif strcmpi(val, 'paused')
            obj.h.statusLabel.Text = 'Paused';
            obj.h.statusLamp.Color = '#008080';
            obj.h.StartStopBtn.Enable = 'on';
            obj.h.StartStopBtn.Text = 'STOP';
            obj.h.pauseBtn.Enable = 'on';
            obj.h.pauseBtn.Text = 'RESUME';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.StartSingleTrialBtn.Enable = 'off';

        elseif strcmpi(val, 'stopping')
            obj.h.statusLabel.Text = 'Stopping';
            obj.h.statusLamp.Color = '#A80000';
            obj.h.StartStopBtn.Enable = 'off';
            obj.h.StartStopBtn.Text = 'START';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.pauseBtn.Text = 'PAUSE';

        elseif strcmpi(val, 'error')
            obj.h.statusLabel.Text = 'Error';
            obj.h.statusLamp.Color = '#A80000';

        elseif strcmpi(val, 'awaiting trigger')
            obj.h.statusLabel.Text = 'Awaiting Trigger';
            obj.h.statusLamp.Color = '#008080';
            obj.h.StartStopBtn.Enable = 'on';
            obj.h.StartStopBtn.Text = 'STOP';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.pauseBtn.Text = 'PAUSE';
            obj.h.StartPassiveBtn.Enable = 'off';
            obj.h.StartSingleTrialBtn.Enable = 'off';
        
        elseif strcmpi(val, 'no protocol loaded')
            obj.h.statusLabel.Text = 'No Protocol Loaded';
            obj.h.statusLamp.Color = '#008080';
            obj.h.StartStopBtn.Enable = 'off';
            obj.h.StartStopBtn.Text = 'START';
            obj.h.pauseBtn.Enable = 'off';
            obj.h.pauseBtn.Text = 'PAUSE';
            obj.h.StartPassiveBtn.Enable = 'on';
            obj.h.StartSingleTrialBtn.Enable = 'off';

        else
            error("Invalid status. New statuses must be imlemented in set.status and stateMachineTimerFcn")
        end
    end

    function indicateLoading(obj, text)
        % INDICATELOADING updates GUI elements to indicate loading and
        % prevent invalid state input combinations. 
        obj.h.statusLabel.Visible = 'off';
        obj.h.loadingLabel.Visible = 'on';
        if ~isempty(text)
            obj.h.loadingLabel.Text = text;
        else
            obj.h.loadingLabel.Text = 'Loading...';
        end
        obj.h.statusLamp.Color = '#FFFF00';
    end

    function clearMessage(obj)
        % CLEARMESSAGE clears the message and warning colour on the text
        % next to the mouse.
        obj.h.statusLabel.Visible = 'on';
        obj.h.statusLabel.FontColor = 'black';
        obj.h.loadingLabel.Visible = 'off';
        switch obj.status
            case "no protocol loaded"
                obj.h.statusLabel.Text = 'No Protocol Loaded';
                obj.h.statusLamp.Color = '#008080';
            case "awaiting trigger"
                obj.h.statusLabel.Text = 'Awaiting Trigger';
                obj.h.statusLamp.Color = '#008080';
            case "paused"
                obj.h.statusLabel.Text = 'Paused';
                obj.h.statusLamp.Color = '#008080';
            case "error"
                obj.h.statusLabel.Text = 'Error';
                obj.h.statusLamp.Color = '#A80000';
            case "stopping"
                obj.h.statusLabel.Text = 'Stopping';
                obj.h.statusLamp.Color = '#A80000';
            case "inter-trial"
                obj.h.statusLabel.Text = 'Inter-Trial';
                obj.h.statusLamp.Color = '#FFFFFF';
            case "running"
                obj.h.statusLabel.Text = 'Running';
                obj.h.statusLamp.Color = '#FFA500';
            case "ready"
                obj.h.statusLabel.Text = 'Ready';
                obj.h.statusLamp.Color = '#00FF00';
            case "not initialised"
                obj.h.statusLabel.Text = 'Not Initialised';
                obj.h.statusLamp.Color = '#808080';
        end
        if obj.h.tabs.SelectedTab == obj.h.Setup.Tab
            target = obj.h.Setup.Message;
        elseif obj.h.tabs.SelectedTab == obj.h.Session.Tab
            target = obj.h.Session.Message;
        else
            error("clearMsg not implemented for this tab.")
        end
        if isempty(obj.d.Available)
            displayText = sprintf("Welcome to StimControl! \nNo devices found. Please check you have devices connected, then restart StimControl.");
        else
            displayText = "Welcome to StimControl!";
        end
        target.Text = displayText;
        target.FontColor = '#000000';
    end

    function val = get.status(obj)
        % GET.STATUS return (string, lower) the current status of
        % StimControl. Possible values outlined in the get.status function.
        val = lower(obj.h.statusLabel.Text);
    end
    
    function set.trialNum(obj, value)
        % SET.TRIALNUM sets the current trial number (defined by the line
        % number of the trial definition in the stimulus file), updating
        % relevant GUI elements. Setting val=0 resets all timer estimates, etc.
        nTrials = length(obj.p);
        totalNTrials = sum([obj.p.nRuns]) * obj.g.nProtRuns;
        validateattributes(value,{'numeric'},...
            {'scalar','integer','real','nonnegative','<=',nTrials});

        if value == 0
            obj.h.numTrialsElapsedLabel.Text = sprintf('Trial: %d/%d', value, nTrials);
            obj.h.trialNumDisplay.Value = 0;   
            obj.h.totalTrialsLabel.Text = "/ 0";
            obj.h.StatusCountdownLabel.Text = "-0:00";
            obj.h.numTrialsElapsedLabel.Text = "Trial 0 / 0";
            obj.h.trialTimeEstimate.Text = "00:00 / 00:00";
            obj.status = 'not initialised';
            return
        end
        tTrial = (obj.p(value).tPre + obj.p(value).tPost) / 1000;
        trialMins = floor(tTrial / 60);
        trialSecs = ceil(tTrial - (trialMins * 60));
        obj.h.StatusCountdownLabel.Text = sprintf('-%d:%d', trialMins, trialSecs);
        obj.h.numTrialsElapsedLabel.Text = sprintf('Trial %d / %d', obj.trialIdx, totalNTrials);
        if ~contains("running inter-trial paused awaiting trigger", obj.status)
            obj.h.trialTimeEstimate.Text = sprintf('00:00 / %d:%d', trialMins, trialSecs);
        end
        obj.h.trialNumDisplay.Value = value;   
        obj.h.totalTrialsLabel.Text = sprintf('/ %d', nTrials);
    end

    function val = get.trialNum(obj)
        % GET.TRIALNUM returns the current trial number, determined by the
        % line on which the currently selected trial is defined in the
        % stimulus file.
        val = obj.h.trialNumDisplay.Value;
    end

    function errorMsg(obj, message)
        % ERRORMSG displays an error message in the bottom right of the program.
        if obj.h.tabs.SelectedTab == obj.h.Setup.Tab
            target = obj.h.Setup.Message;
        elseif obj.h.tabs.SelectedTab == obj.h.Session.Tab
            target = obj.h.Session.Message;
        else
            error("errorMsg not implemented for this tab.")
        end
        
        try
            target.Text = ['ERROR: ' char(message)];
            target.FontColor = 'red';
            obj.status = 'error';
            dbstack
            error(message)
        catch % handle likely not initialised
            dbstack
            error(message)
        end
    end

    function warnMsg(obj, message)
        % WARNMSG displays a warning in the bottom right of the program.
        if obj.h.tabs.SelectedTab == obj.h.Setup.Tab
            target = obj.h.Setup.Message;
        elseif obj.h.tabs.SelectedTab == obj.h.Session.Tab
            target = obj.h.Session.Message;
        else
            error("warnMsg not implemented for this tab.")
        end
        try
            target.Text = ['WARNING: ' char(message)];
            target.FontColor = '#FFA500';
            warning(message)
        catch % handle likely not initialised
            warning(message)
        end
    end

    function clearMsg(obj, src, event)
        % CLEARMSG clears the current warning/error message, setting text
        % colour back to black.
        if obj.h.tabs.SelectedTab == obj.h.Setup.Tab
            target = obj.h.Setup.Message;
        elseif obj.h.tabs.SelectedTab == obj.h.Session.Tab
            target = obj.h.Session.Message;
        else
            error("clearMsg not implemented for this tab.")
        end
        if isempty(obj.d.Available)
            displayText = sprintf("Welcome to StimControl! \nNo devices found. Please check you have devices connected, then restart StimControl.");
        else
            displayText = "Welcome to StimControl!";
        end
        target.Text = displayText;
        target.FontColor = '#000000';
    end

    function obj = loadDefaultSession(obj)
        % LOADDEFAULTSESSION loads the default session file, including
        % hardware and display settings. 
        [s, pcInfo] = system('vol');
        pcInfo = strsplit(pcInfo, '\n');
        pcID = pcInfo{2}(end-8:end);
        filename = [pcID '_default.json'];
        filepath = [obj.path.sessionBase filesep filename];
        if ~isfile(filepath)
            return
        end
        obj.h.SessionSelectDropDown.Value = filename;
        obj.callbackLoadConfig(obj.h.SessionSelectDropDown, '');
    end

    function obj = MapConnectedHardware(obj)
       % MAPCONNECTEDHARDWARE maps connected hardware to its sub-systems.
       % returns a dict with subsystems as keys and device protocol IDs as
       % values.
        obj.pids = [];
        for i = 1:length(obj.d.Available)
            comp = obj.d.Available{i};
            cid = comp.ConfigStruct.ProtocolID;
            if ~isfield(obj.pids, cid)
                obj.pids.(cid) = string(cid);
            else
                obj.pids.(cid) = [obj.pids.(cid) string(cid)];
            end
            for j = 1:length(comp.ConnectedDevices)
                devName = comp.ConnectedDevices(j);
                if ~isfield(obj.pids, devName)
                    obj.pids.(devName) = string(cid);
                else
                    obj.pids.(devName) = [obj.pids.(devName) string(cid)];
                end
            end
        end
    end
end
end