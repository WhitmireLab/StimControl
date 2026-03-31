function timerFcnGui(obj,~,~)
% state tracking and updating in a timer
persistent pauseOffset;
persistent intervalElapsed;
persistent protocolElapsed;
persistent pauseStart;
persistent previousStatus;

if isempty(pauseOffset); pauseOffset = 0; end
if isempty(previousStatus); previousStatus = obj.status; end
if isempty(intervalElapsed); intervalElapsed = 0; end
if isempty(protocolElapsed); protocolElapsed = 0; end

UpdateComponentStatus();

if strcmpi(obj.h.tabs.SelectedTab.Title, 'Setup') || obj.t.paused
    return; % nothing else to update.
end

if obj.status ~= previousStatus
    if strcmpi(previousStatus, 'paused')
        pauseOffset = pauseOffset + toc(pauseStart);
    else
        StatusChangeReset();
    end
    if strcmpi(obj.status, 'paused')
        pauseStart = tic;
    end
    previousStatus = obj.status;
end

obj.h.TimerLastUpdatedLabel.Text = string(datetime);
if ~obj.t.runClocks
    ProtocolChangeReset();
    return;
end

if obj.t.intervalTarget == 0
    UpdatePassive();
else
    UpdateActive();
end

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

function ProtocolChangeReset()
    StatusChangeReset();
    obj.h.protocolTimeEstimate.Text = "00:00 / 00:00";
    protocolElapsed = 0;
end

function StatusChangeReset()
    obj.h.StatusCountdownLabel.Text = "00:00";
    obj.h.trialTimeEstimate.Text = "00:00 / 00:00";
    protocolElapsed = protocolElapsed + intervalElapsed;
    intervalElapsed = 0;
    pauseOffset = 0;
end

function UpdatePassive()
    intervalElapsed = toc(obj.t.startTic);
    obj.h.StatusCountdownLabel.Text = string(duration(seconds(intervalElapsed), 'Format', 'mm:ss'));
    obj.h.protocolTimeEstimate.Text = string(duration(protocolElapsed + seconds(intervalElapsed), 'Format', 'mm:ss'));
end

function UpdateActive()
    intervalElapsed = toc(startTic);
    intervalTarget = obj.t.intervalTarget;
    protocolTarget = obj.t.protocolTarget;

    obj.h.StatusCountdownLabel.Text = sprintf("-%s",  ...
        string(duration(seconds(intervalTarget-intervalElapsed), 'Format', 'mm:ss')));
    
    obj.h.trialTimeEstimate.Text = sprintf("%s / %s",  ...
        string(duration(seconds(intervalElapsed), 'Format', 'mm:ss')), ...
        string(duration(seconds(intervalTarget), 'Format', 'mm:ss')));
    
    obj.h.protocolTimeEstimate.Text = sprintf("%s / %s",  ...
        string(duration(seconds(protocolElapsed+intervalElapsed), 'Format', 'mm:ss')), ...
        string(duration(seconds(protocolTarget), 'Format', 'mm:ss')));
end

end


