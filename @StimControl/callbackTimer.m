function callbackTimer(obj,~,~)
% hardware status updates in a timer
persistent trialNums;
persistent nTrials;
persistent startTic;
persistent previousStatus; %todo this may cause issues with multiple sessions of different status? edge case
persistent pauseOffset;
persistent debugtic
% if isempty(debugtic)
%     debugtic = tic;
% end
% toc(debugtic);
% debugtic = tic;
if isempty(startTic)
    startTic = tic;
end
if isempty(pauseOffset)
    pauseOffset = 0;
end

if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup')
    % update GUI in setup tab
    for i = 1:height(obj.h.AvailableHardwareTable)
        component = obj.d.Available{i};
        obj.h.AvailableHardwareTable.Data.Status{i} = component.GetStatus;
    end
else
    % obj.h.TimerStatusLamp.Color = '#FFED29';
    % obj.h.TimerStatusLabel.Text = "Running";
    obj.h.TimerLastUpdatedLabel.Text = string(datetime);
    if isempty(previousStatus)
        previousStatus = obj.status;
    end
    if ~strcmpi(previousStatus, obj.status)
        % disp(obj.status);
        previousStatus = obj.status;
    end
    % state handling
    try
        switch obj.status
            case 'not initialised'
                % do nothing
            case 'no protocol loaded'
                %% No protocol loaded
                if obj.f.passive
                    startTic = tic;
                    obj.trialIdx = 1;
                    nTrials = Inf;
                    updatePassiveGuiTimer(obj, startTic, true);
                    obj.h.trialInformationScroller.Value = '';
                    obj.h.trialInformationScroller.FontColor = 'black';
                    StartPassiveTrial(obj);
                    obj.status = 'awaiting trigger';
                end
            case 'ready'
                %% Ready
                if obj.f.startTrial
                    % start the trial
                    startTic = tic;
                    nTrials = length(obj.g.sequence);
                    trialNums = obj.g.sequence;
                    if obj.f.runningExperiment
                        if trialNums(1) ~= obj.trialNum
                            obj.trialNum = trialNums(1);
                            obj.callbackLoadTrial([]);
                        end
                    else
                        trialNums = [obj.trialNum];
                        nTrials = 1;
                    end
                    obj.trialIdx = 1;
                    if isfield(obj.g, 'prePause') && obj.g.prePause
                        obj.f.startTrial = false;
                        obj.status = 'inter-trial';
                        return
                    end
                    updateGUITimers(obj, startTic, true);
                    startTrial(obj);
                    obj.f.startTrial = false;
                    obj.status = 'running';
                elseif obj.f.passive
                    startTic = tic;
                    obj.trialIdx = 1;
                    nTrials = Inf;
                    obj.h.trialInformationScroller.Value = '';
                    obj.h.trialInformationScroller.FontColor = 'black';
                    updatePassiveGuiTimer(obj, startTic, true);
                    StartPassiveTrial(obj); %TODO MAKE THIS SO THAT IT DOESN'T ACTIVELY START, E.G, DAQs
                    obj.status = 'running';
                end
            case 'stopping'
                %% Stopping a trial
                % stop the trial (interrupt)
                obj.f.stopTrial = false;
                obj.f.startTrial = false;
                obj.f.passive = false;
                for idx = 1:obj.d.nActive
                    component = obj.d.activeComponents{idx};
                    component.Stop();
                end
                obj.h.StatusCountdownLabel.Text = '-0:00';
                updateGUITimers(obj, tic, true);
                updateInteractivity(obj, 'on');
                if ~isempty(obj.p)
                    obj.trialNum = 1;
                    cellfun(@(c) c.Stop(), obj.d.activeComponents);
                end
                obj.f.runningExperiment = false;
                obj.status = 'no protocol loaded';
            case 'running'
                %% Trial running
                if obj.f.stopTrial
                    obj.status = 'stopping';
                elseif obj.f.trialFinished
                    % trial completed.
                    obj.f.trialFinished = false;
                    if obj.f.passive
                        startTic = tic;
                        updatePassiveGuiTimer(obj, startTic, false);
                        obj.trialIdx = obj.trialIdx + 1;
                        StartPassiveTrial(obj); % pre-loading
                        obj.status = 'awaiting trigger';
                    elseif obj.trialIdx >= nTrials
                        obj.status = 'ready';
                        obj.f.runningExperiment = false;
                    else
                        obj.trialIdx = obj.trialIdx + 1;
                        startTic = tic;
                        obj.status = 'inter-trial';
                        pauseOffset = 0;
                        obj.h.StatusCountdownLabel.Text = strcat('-', string(duration(seconds(obj.g.dPause)), 'mm:ss'));
                        updateGUITimers(obj, startTic, true);
                    end
                else
                    % monitor trial
                    if ~obj.f.passive
                        timeoutReached = updateGUITimers(obj, startTic, false);
                        if timeoutReached
                            % stop all devices 
                            cellfun(@(c) c.Stop(), obj.d.activeComponents);
                            obj.f.trialFinished = true;
                        end
                    else
                        updatePassiveGuiTimer(obj, startTic, false);
                    end
                    if ~any(cellfun(@(c) strcmpi(c.GetStatus(), 'running'), obj.d.activeComponents))
                        obj.f.trialFinished = true;
                        cellfun(@(c) c.EndTrial(), obj.d.activeComponents);
                    else
                        cellfun(@(c) c.TrialMaintain, obj.d.activeComponents); %
                    end
                end
            case 'awaiting trigger'
                %% Passive acquisition mode
                if any(cellfun(@(c) strcmpi(c.GetStatus(), 'running'), obj.d.activeComponents))
                    startTic = tic;
                    updatePassiveGuiTimer(obj, startTic, false);
                    obj.status = 'running';
                elseif obj.f.stopTrial
                    obj.status = 'stopping';
                else
                    updatePassiveGuiTimer(obj, startTic, false);
                end
            case 'inter-trial'
                %% Inter-trial
                if obj.f.pause
                    % pause inter-trial timer
                    pauseOffset = obj.g.dPause - (toc(startTic) + pauseOffset);
                    obj.status = 'paused';
                    obj.f.pause = false;    
                    obj.f.resume = false;
                elseif obj.f.stopTrial
                    obj.status = 'stopping';
                else
                    % update GUI
                    updateGUITimers(obj, startTic, false);
                    % additional logic for loading in with 10 sec left: toc(startTic) >= obj.g.dPause - (pauseOffset+10) ...
                    if ~obj.f.trialLoaded 
                        obj.callbackLoadTrial([]); % load next trial to memory
                        for i = 1:obj.d.nActive
                            component = obj.d.activeComponents{i};
                            if isempty(obj.p(obj.trialNum).params.(component.ConfigStruct.ProtocolID))
                                % not targeted by this trial
                                continue
                            end
                            component.LoadTrial([]);
                        end
                        obj.status = 'inter-trial'; %clear loading symbol
                        obj.f.trialLoaded = true;
                    end

                    % if inter-trial interval is finished, start next trial
                    if toc(startTic) >= obj.g.dPause - pauseOffset
                        startTic = tic;
                        startTrial(obj);
                        obj.status = 'running';
                    end
                end
            case 'paused'
                %% Paused
                if obj.f.resume
                    % resume inter-trial timer
                    obj.f.resume = false;
                    startTic = tic;
                    updateGUITimers(obj, startTic, true);
                    obj.status = 'inter-trial';
                elseif obj.f.stopTrial
                    obj.status = 'stopping';
                end
            case 'error'
                obj.status = 'stopping';
        end
    % update component status display
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        component.UpdateStatusDisplay;
    end
    % obj.h.TimerStatusLamp.Color = '#00FF00';

    % catch errors during protocol execution
    catch err
        fid = fopen(fullfile(obj.path.dirData, filesep,'error.log'),'a+');
        tmp = regexprep(err.getReport('extended','hyperlinks','off'),'\n','\r\n');
        fprintf(fid,'%s',tmp);
        fclose(fid);
        obj.f.passive = false;
        % errordlg('Protocol execution incomplete. See error.log for more information.')
        obj.errorMsg(tmp);
        obj.status = 'stopping';
        % obj.h.TimerStatusLamp.Color = '#FF0000';
        % obj.h.TimerStatusLabel.Text = "Error";
        keyboard % see what's going on
    end
    
end
end

function startTrial(obj)
    updateInteractivity(obj, 'off');
    obj.indicateLoading('Loading trial data');
    if ~obj.f.trialLoaded
        obj.callbackLoadTrial([]);
        for i = 1:obj.d.nActive
            component = obj.d.activeComponents{i};
            if isempty(obj.p(obj.trialNum).params.(component.ConfigStruct.ProtocolID))
                % component not targeted
                continue
            end
            component.LoadTrial([]);
        end
    end
    comment = obj.p(obj.trialNum).comment;
    obj.h.trialInformationScroller.Value{end+1} = ...
        char(sprintf("%d(%d): %s", obj.trialIdx, obj.trialNum, comment));
    scroll(obj.h.trialInformationScroller, 'bottom');
    
    % Set filepath params
    savePrefix = sprintf("%05d_stim%05d", obj.trialIdx, obj.trialNum);
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        component.SavePrefix = savePrefix;
    end
    updateInteractivity(obj, 'on');

    % COMPONENTS: ACTIVATE
    for ci = 1:obj.d.nActive
        component = obj.d.activeComponents{ci};
        component.StartTrial;
    end
    obj.f.trialLoaded = false;
end

function StartPassiveTrial(obj)
    updateInteractivity(obj, 'off');
    obj.updateDateTime;
    timeString = [obj.path.time(1:2) '-' obj.path.time(3:4) '-' obj.path.time(5:6)];
    obj.h.trialInformationScroller.Value{end+1} = ...
        char(sprintf("Trial %d started: %s", obj.trialIdx, timeString));
    
    % Set filepath params
    savePrefix = sprintf("%s_stim_passive_%s", num2str(obj.trialIdx, '%05.f'), obj.path.time);
    for i = 1:obj.d.nActive
        component = obj.d.activeComponents{i};
        component.SavePrefix = savePrefix;
    end
    updateInteractivity(obj, 'on');

    % COMPONENTS: ACTIVATE
    for ci = 1:obj.d.nActive
        component = obj.d.activeComponents{ci};
        component.StartTrial;
    end
end

function updateInteractivity(obj, state)
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

function updatePassiveGuiTimer(obj, startTic, reset)
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

function timeoutReached = updateGUITimers(obj, startTic, reset)
    persistent trialSecs;
    persistent intervalSecs;
    persistent experimentSecs;
    persistent experimentStartSecs;

    if reset || isempty(trialSecs)
        % initialise variables
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