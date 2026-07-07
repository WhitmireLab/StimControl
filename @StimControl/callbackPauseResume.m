function callbackPauseResume(obj, src, event)
% CALLBACKPAUSERESUME set flags to pause or resume the inter-trial
% interval. See timerFcnStateMachine
if strcmpi(obj.status, 'paused')
    obj.f.resume = true;
else
    obj.f.pause = true;
end
end