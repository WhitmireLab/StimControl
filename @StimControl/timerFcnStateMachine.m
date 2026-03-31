function timerFcnStateMachine(obj,~,~)
% hardware status updates in a timer
% persistent trialNums;
persistent nTrials;
persistent startTic;
persistent previousStatus; %todo this may cause issues with multiple sessions of different status? edge case
persistent pauseOffset;
persistent timeoutReached;

if isempty(startTic)
    startTic = tic;
end
if isempty(pauseOffset)
    pauseOffset = 0;
end
if isempty(timeoutReached)
    timeoutReached = false;
end

% update GUI
UpdateGUI();
if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup')
    return
end
if isempty(previousStatus)
    previousStatus = obj.status;
end
if ~strcmpi(previousStatus, obj.status)
    previousStatus = obj.status;
end

% state handling
try
    switch obj.status
        case 'not initialised'
            % do nothing
        case 'no protocol loaded'
            % start a passive experiment if the button has been pushed.
            if obj.f.passive
                InitialisePassiveExperiment();
            end
        case 'ready'
            if obj.f.startTrial
                % if obj.f.runningExperiment
                %     trialNums = obj.g.sequence;
                % else
                %     trialNums = [obj.trialNum];
                % end
                InitialiseExperiment();
                StartTrial();
            elseif obj.f.passive
                InitialisePassiveExperiment();
            end
        case 'stopping'
            % Manually stop a trial
            ManualStop();
        case 'running'
            if obj.f.stopTrial
                obj.status = 'stopping';
            elseif obj.f.trialFinished
                FinishTrial();
            else
                MonitorTrial();
            end
        case 'awaiting trigger'
            % Passive acquisition mode
            if any(cellfun(@(c) strcmpi(c.GetStatus(), 'running'), obj.d.activeComponents))
                startTic = tic;
                updatePassiveGuiTimer(startTic, false);
                obj.status = 'running';
            elseif obj.f.stopTrial
                obj.status = 'stopping';
            else
                updatePassiveGuiTimer(startTic, false);
            end
        case 'inter-trial'
            if obj.f.pause
                Pause();
            elseif obj.f.stopTrial
                obj.status = 'stopping';
            else
                % additional logic for loading in with 10 sec left: toc(startTic) >= obj.g.dPause - (pauseOffset+10) ...
                if ~obj.f.trialLoaded 
                    UpdateComponentSavePaths();
                    LoadTrialToDisplay();
                    LoadTrialToComponents();
                    obj.status = 'inter-trial'; %clear loading symbol
                    obj.f.trialLoaded = true;
                end

                % if inter-trial interval is finished, start next trial
                if toc(startTic) >= obj.g.dPause - pauseOffset
                    startTic = tic;
                    StartTrial();
                    obj.status = 'running';
                end
            end
        case 'paused'
            %% Paused
            if obj.f.resume
                Resume();
            elseif obj.f.stopTrial
                obj.status = 'stopping';
            end
        case 'error'
            obj.status = 'stopping';
    end
catch err
    LogError(err);
    keyboard % see what's going on
    % if err is daq error, delete(daq.getDevices) then daqreset then reload.
end

%% HELPER FUNCTIONS

function InitialisePassiveExperiment()
    startTic = tic;
    obj.trialIdx = 1;
    nTrials = Inf;
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
    updatePassiveGuiTimer(startTic, true);
    StartPassiveTrial();
    obj.status = 'awaiting trigger';
end

function InitialiseExperiment()
    obj.updateDateTime;
    if ~isfolder(obj.dirExperiment)
        mkdir(obj.dirExperiment)
    end
    % copy protocol file to output directory
    [~,tmp1,tmp2] = fileparts(obj.path.SessionProtocolFile);
    copyfile(obj.path.SessionProtocolFile,fullfile(obj.dirExperiment,[tmp1 tmp2]))
    
    % save metadata to output directory
    metapath = [obj.dirExperiment filesep tmp1 '_meta.json'];
    metaStr = struct("metadata", {}, "hardwareConfig", []);
    for i = 1:length(obj.meta)
        m = obj.meta(i);
        metaStr.metadata{end+1} = m.PrintableMetadata;
    end
    metaStr.hardwareConfig = GetComponentData(obj, metapath);

    jsonData = jsonencode(metaStr);
    file = fopen([pBase filesep filename], 'w+');
    fprintf(file, '%s', jsonData);
    fclose(file);
    
    % initialise tics, flags, etc.
    startTic = tic;
    if obj.f.runningExperiment
        nTrials = length(obj.g.sequence);
        if obj.g.sequence(1) ~= obj.trialNum
            obj.trialNum = obj.g.sequence(1);
        end
    else
        nTrials = 1;
    end
    obj.trialIdx = 1;
    if isfield(obj.g, 'prePause') && obj.g.prePause
        obj.f.startTrial = false;
        obj.status = 'inter-trial';
        return
    end
    
    % send all this information elsewhere
    UpdateComponentSavePaths();
    LoadTrialToDisplay();
    LoadTrialToComponents();

    % reset GUI timers
    ResetGUITimers();
end

function UpdateComponentSavePaths()
    if obj.f.passive
        savePrefix = sprintf("%s_stim_passive_%s", num2str(obj.trialIdx, '%05.f'), obj.path.time);
        savePath = [obj.dirExperiment '_passive'];
    else
        % update save prefixes
        savePrefix = sprintf("%05d_stim%05d", obj.trialIdx, obj.trialNum);
        savePath = obj.dirExperiment;
    end

    for i = 1:obj.d.nActive
        % update save paths
        component = obj.d.activeComponents{i};
        if ~isfield(obj.p(obj.trialNum).params, component.ConfigStruct.ProtocolID) ...
            || isempty(obj.p(obj.trialNum).params.(component.ConfigStruct.ProtocolID))
            % component not targeted
            continue
        end
        component.SavePath = savePath;
        component.SavePrefix = savePrefix;
    end
end

function LoadTrialToDisplay()
    obj.callbackLoadTrial([]);
end

function LoadTrialToComponents()
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        if isempty(obj.p(obj.trialNum).params.(component.ConfigStruct.ProtocolID))
            % component not targeted
            continue
        end
        component.LoadTrial([]);
    end
end

function StartTrial()
    updateInteractivity('off');
    profile off;
    profile on;
    obj.indicateLoading('Loading trial data');
    
    comment = obj.p(obj.trialNum).comment;
    obj.h.trialInformationScroller.Value{end+1} = ...
        char(sprintf("%d(%d): %s", obj.trialIdx, obj.trialNum, comment));
    scroll(obj.h.trialInformationScroller, 'bottom');

    obj.f.startTrial = false;
    obj.f.trialLoaded = false;
    obj.status = 'running';

    % COMPONENTS: ACTIVATE
    for ci = 1:obj.d.nActive
        component = obj.d.activeComponents{ci};
        component.StartTrial;
    end
    updateInteractivity('on');
end

function StartPassiveTrial()
    updateInteractivity('off');
    obj.updateDateTime;
    timeString = [obj.path.time(1:2) '-' obj.path.time(3:4) '-' obj.path.time(5:6)];
    obj.h.trialInformationScroller.Value{end+1} = ...
        char(sprintf("Trial %d started: %s", obj.trialIdx, timeString));
    
    % Set filepath params
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        component.SavePrefix = savePrefix;
    end
    updateInteractivity('on');

    % COMPONENTS: ACTIVATE
    for ci = 1:obj.d.nActive
        component = obj.d.activeComponents{ci};
        component.StartTrial;
    end
end

function StopComponents()
    cellfun(@(c) c.Stop(), obj.d.activeComponents);
end

function FinishTrial()
    obj.f.trialFinished = false;
    if obj.f.passive
        startTic = tic;
        updatePassiveGuiTimer(startTic, false);
        obj.trialIdx = obj.trialIdx + 1;
        StartPassiveTrial(); % pre-loading
        obj.status = 'awaiting trigger';
    else
        StopComponents();
        if obj.trialIdx >= nTrials
            obj.status = 'ready';
            obj.f.runningExperiment = false;
        else
            obj.trialIdx = obj.trialIdx + 1;
            obj.trialNum = obj.g.sequence(obj.trialIdx);
            startTic = tic;
            obj.status = 'inter-trial';
            pauseOffset = 0;
            obj.h.StatusCountdownLabel.Text = strcat('-', string(duration(seconds(obj.g.dPause)), 'mm:ss'));
            ResetGUITimers();
        end
    end
end

function MonitorTrial()
    if ~obj.f.passive && timeoutReached
        StopComponents()
        obj.f.trialFinished = true;
    else
        updatePassiveGuiTimer(startTic, false);
    end
    if ~any(cellfun(@(c) strcmpi(c.GetStatus(), 'running'), obj.d.activeComponents))
        obj.f.trialFinished = true;
        cellfun(@(c) c.EndTrial(), obj.d.activeComponents);
    else
        cellfun(@(c) c.TrialMaintain, obj.d.activeComponents); 
    end
end

function ManualStop()
    % stop the trial (interrupt)
    obj.f.stopTrial = false;
    obj.f.startTrial = false;
    obj.f.passive = false;
    for idx = 1:obj.d.nActive
        component = obj.d.activeComponents{idx};
        component.Stop();
    end
    obj.h.StatusCountdownLabel.Text = '-0:00';
    ResetGUITimers();
    updateInteractivity('on');
    if ~isempty(obj.p)
        obj.trialNum = 1;
        cellfun(@(c) c.Stop(), obj.d.activeComponents);
    end
    obj.f.runningExperiment = false;
    obj.status = 'no protocol loaded';
end

function Pause()
    pauseOffset = obj.g.dPause - (toc(startTic) + pauseOffset);
    obj.status = 'paused';
    obj.f.pause = false;    
    obj.f.resume = false;
end

function Resume()
    obj.f.resume = false;
    startTic = tic;
    ResetGUITimers();
    obj.status = 'inter-trial';
end

function updateInteractivity(state)
    allUI = findobj(obj.h.Session.Tab);
    for ii = 1:length(allUI)
        uiObj = allUI(ii);
        if contains(class(uiObj), 'matlab.ui.control') ...
                && uiObj ~= obj.h.menuDebug ...
                && isprop(uiObj, "Enable") ...
                && ~contains(class(uiObj), 'Lamp') ...
                && ~contains(class(uiObj), 'Label') ...
                && uiObj ~= obj.h.trialInformationScroller
            uiObj.Enable = state;
        end
    end
end

function timeoutReached = UpdateGUI()
    % generic
    timeoutReached = false;
    obj.h.TimerLastUpdatedLabel.Text = string(datetime);

    % setup tab
    if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup')
        for i = 1:height(obj.h.AvailableHardwareTable)
            component = obj.d.Available{i};
            obj.h.AvailableHardwareTable.Data.Status{i} = component.GetStatus;
        end
        return
    end
    
    % session tab
    switch obj.status
        case 'running'
            if ~obj.f.stopTrial && ~obj.f.trialFinished
                if obj.f.passive
                    updatePassiveGuiTimer(false);
                else
                    timeoutReached = UpdateGUITimers(false);
                end
            end
        case 'inter-trial'
            if ~obj.f.resume && ~obj.f.stopTrial
                UpdateGUITimers(false);
            end
    end

    % update component status
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        component.UpdateStatusDisplay;
    end
end

function ResetGUITimers()
    UpdateGUITimers(true);
end

function updatePassiveGuiTimer(startTic, reset)
    persistent totalSecs;
    
    if isempty(totalSecs) || reset
        totalSecs = 0;
    end
    tElapsed = toc(startTic);
    obj.h.StatusCountdownLabel.Text = sprintf("+%s",  ...
        string(duration(seconds(tElapsed), 'Format', 'mm:ss')));
    obj.h.protocolTimeEstimate.Text = sprintf("%s / 00:00",  ...
        string(duration(totalSecs + seconds(tElapsed), 'Format', 'mm:ss')));
end

function timeoutReached = UpdateGUITimers(reset)
    persistent trialSecs;
    persistent intervalSecs;
    persistent experimentSecs;
    persistent experimentStartSecs;

    if reset || isempty(trialSecs)
        % initialise variables
        startTic = tic;
        totalTimeLabel = strip(split(obj.h.trialTimeEstimate.Text, '/'));
        trialSecs = seconds(duration(totalTimeLabel{2}, 'InputFormat', 'mm:ss'));
        experimentTimeLabel = strip(split(obj.h.protocolTimeEstimate.Text, '/'));
        if length(sscanf(experimentTimeLabel{1}, "%d:%d:%d")) == 3
            inputFormat = 'hh:mm:ss';
        else
           inputFormat = 'mm:ss';
        end
        experimentSecs = seconds(duration(experimentTimeLabel{2}, 'InputFormat', inputFormat));
        experimentStartSecs = seconds(duration(experimentTimeLabel{1}, 'InputFormat', inputFormat));
        intervalSecs = seconds(duration(obj.h.StatusCountdownLabel.Text(2:end), ...
                'InputFormat', 'mm:ss'));
    end

    tElapsed = toc(startTic);

    obj.h.StatusCountdownLabel.Text = sprintf("-%s",  ...
        string(duration(seconds(intervalSecs-tElapsed), 'Format', 'mm:ss')));
    if strcmpi(obj.status, 'running')
        obj.h.trialTimeEstimate.Text = sprintf("%s / %s",  ...
            string(duration(seconds(tElapsed), 'Format', 'mm:ss')), ...
            string(duration(seconds(trialSecs), 'Format', 'mm:ss')));
    end
    if obj.f.runningExperiment
        % called from full experiment - update full experiment timer.
        obj.h.protocolTimeEstimate.Text = sprintf("%s / %s",  ...
        string(duration(seconds(experimentStartSecs+tElapsed), 'Format', 'mm:ss')), ...
        string(duration(seconds(experimentSecs), 'Format', 'mm:ss')));
    end

    timeoutReached = tElapsed > trialSecs + 5; %2 second buffer
end

function LogError(err)
    fid = fopen(fullfile(obj.path.dirData, filesep,'error.log'),'a+');
    tmp = regexprep(err.getReport('extended','hyperlinks','off'),'\n','\r\n');
    fprintf(fid,'%s \n %s', string(datetime), tmp);
    fclose(fid);
    % reset flags.
    obj.f.passive = false;
    obj.status = 'ready';
    obj.f.startTrial = false;
    % errordlg('Protocol execution incomplete. See error.log for more information.')
    obj.errorMsg(tmp);
    obj.status = 'stopping';
end
end

function componentData = GetComponentData(obj, metaPath)
    componentData = {};
    for i = 1:length(obj.d.Available)
        component = obj.d.Available{i};
        params = component.GetParams;
        params.type = class(component);
        params.Active = logical(obj.d.Active(i));
        params.Previewing = component.Previewing;
        componentData{end+1} = params;
        component.SaveAuxiliaryConfig(metaPath);
    end
end

