classdef StimControl < handle

properties (Access = protected)
    path = [];
end

properties (Access = private)
    h           = []            % GUI handles
    d           = []            % HardwareComponent handles
    p           = []            % stimulation parameters/protocol
    g           = []            % general protocol parameters
    idxStim     = []            % current stimulus index
    t                           % timer
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

end

properties (Dependent)
    animalID
    experimentID
    trialNum                    % number of trial as defined in protocol file
    dirAnimal
    dirExperiment
    status
end

methods
    function obj = StimControl(varargin)
        % close all
        % obj.path.base = pwd;
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
        obj.d = obj.d.FindAvailableHardware(); %TODO CHANGE THIS SO IT ONLY FINDS HARDWARE WITHOUT AN ACTVIE SESSION ELSEWHERE. Or at least doesn't initialise

        %% Create figure and get things going
        disp("Creating figure...")
        createFigure(obj)
        
        %% state machine timer
        obj.t = timer(...
            'StartDelay',       0, ...
            'Period',           0.25, ...
            'ExecutionMode',    'fixedDelay', ...
            'StartFcn',         @obj.callbackTimer, ...
            'TimerFcn',         @obj.callbackTimer, ...
            'Name',             'StateMachineTimer');
        start(obj.t)
        
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
    createPanelSetupPreview(obj, hPanel, ~)
    createPanelComponentConfig(obj, hPanel, ~, component)
    createPanelSessionControl(obj, hPanel, ~)
    createPanelSessionPreview(obj, hPanel, ~)
    createPanelSessionHardware(obj, hPanel, ~)

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

    % hardware control callbacks
    callbackEditComponentConfig(obj, ~, ~)

    % misc
    callbackFileExit(obj,~,~)
    callbackTimer(obj, ~, ~)
end

methods
    function restartTimer(obj, ~, ~)
        obj.t.stop;
        obj.t.start;
    end

    function filepath = get.dirAnimal(obj)
        filepath = fullfile(obj.path.dirData,obj.animalID);
        if ~exist(filepath,'dir')
            mkdir(filepath)
        end
    end

    function filepath = get.dirExperiment(obj)
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
        obj.updateDate;
        obj.updateTime;
    end

    function updateDate(obj)
        dt = datetime("now");
        dt.Format = "yyMMdd";
        obj.path.date = char(dt);
    end

    function updateTime(obj)
        dt = datetime("now");
        dt.Format  = "HHmmss";
        obj.path.time = char(dt);
    end

    function set.experimentID(obj, val)
        if ~contains(obj.h.protocolSelectDropDown.Items, val)
            obj.h.protocolSelectDropDown.Items{end+1} = val;
        end
        obj.h.protocolSelectDropDown.Value = val;
        % TODO UPDATE GUI HERE - trialnum, estimated time, etc.
    end

    function out = get.experimentID(obj)
        tmp = strsplit(obj.h.protocolSelectDropDown.Value, '.');
        if length(tmp) < 2
            out = tmp{:};
        else
            out = tmp{1};
        end
    end

    function set.animalID(obj, val)
        if ~ismember(obj.h.animalSelectDropDown.Items, val)
            obj.h.animalSelectDropDown.Items{end+1} = val;
        end
        obj.h.animalSelectDropDown.Value = val;
    end

    function out = get.animalID(obj)
        out = obj.h.animalSelectDropDown.Value;
    end

    function set.status(obj, val)
        % supported values: 
        % NOT INITIALISED / READY / RUNNING / INTER-TRIAL / PAUSED / ERROR
        % / STOPPING
        obj.h.loadingLabel.Visible = 'off';
        obj.h.statusLabel.Visible = 'on';
        obj.tLastStatusChange = tic;
        val = lower(val);
        if strcmpi(val, 'not initialised')
            obj.h.statusLabel.Text = 'Not Initialised';
            obj.h.statusLamp.Color = '#808080'; % dark grey
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
            error("Invalid status. Implement status here or it won't work.")
        end
    end

    function indicateLoading(obj, text)

        obj.h.statusLabel.Visible = 'off';
        obj.h.loadingLabel.Visible = 'on';
        if ~isempty(text)
            obj.h.loadingLabel.Text = text;
        else
            obj.h.loadingLabel.Text = 'Loading...';
        end
        obj.h.statusLamp.Color = '#FFFF00';
    end

    function val = get.status(obj)
        val = lower(obj.h.statusLabel.Text);
    end
    
    function set.trialNum(obj, value)
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
        obj.h.trialTimeEstimate.Text = sprintf('00:00 / %d:%d', trialMins, trialSecs);
        obj.h.trialNumDisplay.Value = value;   
        obj.h.totalTrialsLabel.Text = sprintf('/ %d', nTrials);
    end

    function val = get.trialNum(obj)
        val = obj.h.trialNumDisplay.Value;
    end

    function errorMsg(obj, message)
        %PHILL: COMMENT OUT FROM HERE
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
        %PHILL: COMMENT OUT DOWN TO HERE
    end

    function warnMsg(obj, message)
        %PHILL: COMMENT OUT FROM HERE
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
        %PHILL: COMMENT OUT TO HERE
    end

    function obj = loadDefaultSession(obj)
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