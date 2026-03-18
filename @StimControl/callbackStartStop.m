function callbackStartStop(obj, src, event)
% Starts or stops an experiment. 
% enables or disables relevant GUI elements for interactivity
if strcmpi(obj.status, 'running') || strcmpi(obj.status, 'paused') ...
    || strcmpi(obj.status, 'inter-trial') || strcmpi(obj.status, 'awaiting trigger')
    % Confirm stop experiment
    selection = uiconfirm(obj.h.fig, ...
        "Experiment is still running! Really stop? You will need to restart StimControl if the DAQ has been preloaded.","Confirm Stop", ...
        "Icon","warning");
    if ~strcmpi(selection, "OK")
        return
    end
    obj.f.stopTrial = true;
elseif src == obj.h.StartStopBtn || src == obj.h.StartSingleTrialBtn
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
    if src == obj.h.StartStopBtn
        obj.f.runningExperiment = true;
        obj.trialIdx = 1;
    end
    obj.f.startTrial = true;
    
elseif src == obj.h.StartPassiveBtn
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
    obj.f.passive = true;
end
end