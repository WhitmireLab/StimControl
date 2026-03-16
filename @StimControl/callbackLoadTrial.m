function callbackLoadTrial(obj, src, ~)
% Sets trial number if changed, and preloads trial data into device memory. does not preload to devices.
obj.indicateLoading("Loading trial");
if src == obj.h.prevTrialBtn
    if obj.trialNum == 1
        obj.trialNum = length(obj.p);
    else
        obj.trialNum = obj.trialNum - 1;
    end
elseif src == obj.h.nextTrialBtn
    if obj.trialNum == length(obj.p)
        obj.trialNum = 1;
    else
        obj.trialNum = obj.trialNum + 1;
    end
elseif isfield(obj.g, 'sequence')
    obj.trialNum = obj.g.sequence(obj.trialIdx);
end

% Load a trial
if sum(obj.d.Active) == 0
    obj.errorMsg('please select at least one hardware component');
elseif isempty(obj.p) || isempty(obj.g)
    obj.errorMsg('please select a protocol');
end

trialData = obj.p(obj.trialNum);
genericTrialData = struct( ...
    'tPre', trialData.tPre, ...
    'tPost', trialData.tPost, ...
    'nRuns', trialData.nRuns);
warnIDs = {};
ct = fields(obj.d.componentTargets);
for cIdx = 1:length(ct)
    compID = ct{cIdx};
    component = obj.d.Available{obj.d.ProtocolIDMap(compID)};
    if ~isfield(trialData.params, compID) || isempty(trialData.params.(compID))
        warnIDs{end+1} = char(compID);
        continue
    end
    componentData = trialData.params.(compID);
    component.LoadTrialFromParams(componentData, genericTrialData, false);
end

if ~isempty(warnIDs)
    obj.warnMsg(sprintf("Component(s) connected but not targeted in trial%d:  " + ...
            "%s", trialData.trialIdx, strjoin(warnIDs, ', ')));
else
    % clear warning message
    obj.status = obj.status;
end

if src ~= obj.h.StartStopBtn
    obj.status = 'ready'; % prevent softlocks
end
obj.f.trialLoaded = true;
end