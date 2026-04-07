function timerFcnStateMachine(obj,~,~)
% hardware status updates in a timer
% persistent trialNums;
persistent nTrials;
if isempty(nTrials); nTrials = Inf; end

if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup')
    return
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
            if ComponentsRunning()
                obj.status = 'running';
            elseif obj.f.stopTrial
                obj.status = 'stopping';
            end
        case 'inter-trial'
            obj.t.intervalTarget = obj.g.dPause;
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
                    obj.f.trialLoaded = true;
                end

                % if inter-trial interval is finished, start next trial
                if IntervalTimeoutReached
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
    obj.t.intervalTarget = Inf;
    obj.t.experimentTarget = Inf;

    obj.trialIdx = 1;
    nTrials = Inf;
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
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
    metaStr = struct("trials", obj.meta, "hardware", GetComponentData(obj, metapath));
    
    jsonData = jsonencode(metaStr);
    file = fopen(metapath, 'w+');
    fprintf(file, '%s', jsonData);
    fclose(file);
    
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
    obj.t.intervalTarget = (obj.p(obj.trialNum).tPre + obj.p(obj.trialNum).tPost) / 1000;
    obj.t.experimentTarget = (obj.g.dPause(1)*(obj.g.nProtRuns-1) + ((sum(([obj.p.tPre] + [obj.p.tPost]).*[obj.p.nRuns])))*obj.g.nProtRuns/1000);

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
    obj.t.intervalTarget = Inf;
    obj.t.experimentTarget = Inf;
    obj.updateDateTime;

    savePrefix = sprintf("%s_stim_passive_%s", num2str(obj.trialIdx, '%05.f'), obj.path.time);

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
            obj.status = 'inter-trial';
        end
    end
end

function MonitorTrial()
    if ~obj.f.passive && IntervalTimeoutReached
        StopComponents()
        obj.f.trialFinished = true;
    end
    if ~ComponentsRunning()
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
    updateInteractivity('on');
    if ~isempty(obj.p)
        obj.trialNum = 1;
        cellfun(@(c) c.Stop(), obj.d.activeComponents);
    end
    obj.f.runningExperiment = false;
    obj.status = 'no protocol loaded';
end

function Pause()
    obj.status = 'paused';
    obj.f.pause = false;    
    obj.f.resume = false;
end

function Resume()
    obj.f.resume = false;
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

%% attribute-like helper functions
function out = IntervalTimeoutReached()
    if strcmpi(obj.status, 'inter-trial')
        out = obj.t.intervalElapsed >= obj.t.intervalTarget;
    else
        out = obj.t.intervalElapsed >= obj.t.intervalTarget + 5; %bit of grace to finish active
    end
end

function out = ComponentsRunning()
    out = any(cellfun(@(c) strcmpi(c.GetStatus(), 'running'), obj.d.activeComponents));
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

