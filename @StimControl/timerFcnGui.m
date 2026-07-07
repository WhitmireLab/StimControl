function timerFcnGui(obj,~,~)
% state tracking and updating in a timer. This timer deals with
% visualisation only.
persistent pauseOffset;
persistent intervalElapsed;
persistent experimentElapsed;
persistent pauseStart;
persistent previousStatus;
persistent updateTimers;
persistent startTic;

if isempty(pauseOffset); pauseOffset = 0; end
if isempty(intervalElapsed); intervalElapsed = 0; end
if isempty(experimentElapsed); experimentElapsed = 0; end

if ~isempty(startTic)
    intervalElapsed = toc(startTic) + pauseOffset;
end

UpdateComponentStatus();
UpdateFlags();

if strcmpi(obj.timerStateMachine.Running, 'on')
    obj.h.TimerLastUpdatedLabel.Text = string(datetime);
else
    obj.h.TimerLastUpdatedLabel.Text = 'STATE MACHINE ERROR';
end

if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup') || ~updateTimers
    return; % nothing else to update.
end

if obj.t.intervalTarget == Inf
    UpdatePassive();
else
    UpdateActive();
end

obj.t.experimentElapsed = experimentElapsed;
obj.t.intervalElapsed = intervalElapsed;

%% Helper functions
function UpdateComponentStatus()
    if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup')
        for i = 1:height(obj.h.AvailableHardwareTable)
            component = obj.d.Available{i};
            obj.h.AvailableHardwareTable.Data.Status{i} = component.GetStatus;
        end
    else
        for i = 1:obj.d.nActive
            component = obj.d.activeComponents{i};
            component.UpdateStatusDisplay;
        end
    end
end

function UpdateFlags()
    if ~strcmpi(obj.status, previousStatus) || isempty(previousStatus)
        tmpPrev = previousStatus;
        previousStatus = obj.status;
        switch obj.status
            case 'not initialised'
                updateTimers = false;
                pauseOffset = 0;
                experimentElapsed = 0;
                intervalElapsed = 0;
            case 'ready'
                updateTimers = false;
                pauseOffset = 0;
                experimentElapsed = 0;
                intervalElapsed = 0;
            case 'running'
                pauseOffset = 0;
                updateTimers = true;
                startTic = tic;
                experimentElapsed = round(experimentElapsed + intervalElapsed);
                intervalElapsed = 0;
            case 'inter-trial'
                if strcmpi(tmpPrev, 'paused')
                    pauseOffset = pauseOffset + toc(pauseStart);
                end
                experimentElapsed = round(experimentElapsed + intervalElapsed);
                intervalElapsed = 0;
                obj.t.intervalTarget = obj.g.dPause;
                updateTimers = true;
                startTic = tic;
            case 'paused'
                pauseStart = tic;
                updateTimers = false;
                experimentElapsed = round(experimentElapsed + intervalElapsed);
                intervalElapsed = 0;
                return
            case 'error'
                updateTimers = false;
                pauseOffset = 0;
                experimentElapsed = 0;
                intervalElapsed = 0;
            case 'stopping'
                updateTimers = false;
                pauseOffset = 0;
                experimentElapsed = 0;
                intervalElapsed = 0;
            case 'awaiting trigger'
                updateTimers = true;
                startTic = tic;
                experimentElapsed = round(experimentElapsed + intervalElapsed);
                intervalElapsed = 0;
            case 'no protocol loaded'
                updateTimers = false;
                experimentElapsed = 0;
                intervalElapsed = 0;
        end
        previousStatus = obj.status;
    end
end

function UpdatePassive()
    obj.h.StatusCountdownLabel.Text = string(duration(seconds(intervalElapsed), 'Format', 'mm:ss'));
    obj.h.protocolTimeEstimate.Text = string(duration(experimentElapsed + seconds(intervalElapsed), 'Format', 'mm:ss'));
end

function UpdateActive()
    intervalTarget = obj.t.intervalTarget;
    experimentTarget = obj.t.experimentTarget;

    obj.h.StatusCountdownLabel.Text = sprintf("-%s",  ...
        string(duration(seconds(intervalTarget-intervalElapsed), 'Format', 'mm:ss')));
    
    obj.h.trialTimeEstimate.Text = sprintf("%s / %s",  ...
        string(duration(seconds(intervalElapsed), 'Format', 'mm:ss')), ...
        string(duration(seconds(intervalTarget), 'Format', 'mm:ss')));
    
    obj.h.protocolTimeEstimate.Text = sprintf("%s / %s",  ...
        string(duration(seconds(experimentElapsed+intervalElapsed), 'Format', 'mm:ss')), ...
        string(duration(seconds(experimentTarget), 'Format', 'mm:ss')));
end
end


