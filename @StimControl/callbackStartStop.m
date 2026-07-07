function callbackStartStop(obj, src, event)
% CALLBACKSTARTSTOP Starts or stops an experiment. 
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
        obj.g.sequence = RegenerateSequence();
        obj.f.runningExperiment = true;
        obj.trialIdx = 1;
    end
    obj.f.startTrial = true;
    
elseif src == obj.h.StartPassiveBtn
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
    obj.f.passive = true;
end


function seq = RegenerateSequence()
    tmp = arrayfun(@(x,y) {ones(1,x)*y},[obj.p.nRuns],1:length(obj.p));
    tmp = [tmp{:}];
    if obj.g.rand > 0
        if obj.g.rand == 2
            rng(0)
        else
            rng('shuffle')
        end
        seq = [];
        for ii = 1:obj.g.nProtRuns
            seq = [seq tmp(randperm(length(tmp)))]; %#ok<AGROW>
        end
    else
        seq = repmat(tmp,1,obj.g.nProtRuns);
    end
end
end