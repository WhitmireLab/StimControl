function callbackLoadProtocol(obj, src, event)
% Load a protocol file. Maps protocol inputs/outputs to hardware components.
% and updates GUI to allow trial start.
% eventually this will be more intelligent and able to handle ambiguity, but for now
% the mapping files need to be perfectly aligned to the protocol.
obj.indicateLoading('Loading protocol');

if src == obj.h.menuCheckStimulus
    % start protocolchecker app
    ProtocolCheckerGUI;
    return
elseif src ~= obj.h.protocolSelectDropDown
    % not implemented.
    return
end
if strcmpi(src.Value, 'Browse...')
    [filename, dir] = uigetfile([obj.path.protocolBase filesep '*.*'], 'Select protocol');
    if filename == 0
        src.Value = '';
        return
    end
    obj.path.SessionProtocolFile = [dir filename];
    experimentID = filename;
    obj.experimentID = experimentID;
    obj.path.protocolDirectories.(obj.experimentID) = dir;
elseif ~strcmpi(src.Value, '')
    obj.experimentID = src.Value;
    if ~isempty(obj.path.protocolDirectories) && isfield(obj.path.protocolDirectories, src.Value)
        pathBase = obj.path.SessionProtocolFile.(obj.experimentID);
    else
        pathBase = obj.path.protocolBase;
    end
        obj.path.SessionProtocolFile = [pathBase filesep src.Value];

elseif strcmpi(src.Value, '')
    obj.h.trialInformationScroller.Value = '';
    obj.h.trialInformationScroller.FontColor = 'black';
    if ~isempty(obj.p)
        obj.trialNum = 0;
    end
    return
end

if ~isfile(obj.path.SessionProtocolFile)
    obj.warnMsg('Protocol file not found. Passive mode enabled.');
    obj.status = 'no protocol loaded';
    return
end
try
    if contains(obj.path.SessionProtocolFile, '.qst')
        % legacy considerations
        [p, g, m] = readQSTParameters(obj.path.SessionProtocolFile);
    elseif contains(obj.path.SessionProtocolFile, '.stim')
        % current format
        [p, g, m] = readProtocol(obj.path.SessionProtocolFile);
    else
        error("Unsupported file format. Supported formats: .qst, .stim");
    end
catch exception
    obj.errorMsg(exception.message);
    return;
end

createChans = isempty(obj.p);
if createChans
    obj.MapConnectedHardware; % just in case it hasn't been hit yet.
end
allTargets = getAllTargets(p);
% Construct appropriate trial for each device
deviceTargets = [];
for di = 1:sum(obj.d.Active)
    deviceTargets.(obj.d.activeComponents{di}.ConfigStruct.ProtocolID) = [];
end
for fi = 1:length(allTargets)
    targetName = allTargets{fi};
    if ~isfield(obj.pids, targetName)
        obj.warnMsg(sprintf("No connected device found for stimulus target %s. It should either be a ProtocolID for a connected device, or defined as a DAQ channel. Passive mode enabled.", targetName));
        obj.status = 'no protocol loaded';
        return
    end
    componentIDs = obj.pids.(targetName);
    for ci = 1:length(componentIDs)
        componentID = componentIDs(ci);
        if ~isfield(deviceTargets, componentID)
            % not active for this session
            continue
        end
        deviceTargets.(componentIDs(ci)) = [deviceTargets.(componentIDs(ci)) string(targetName)];
    end
end
obj.d.componentTargets = deviceTargets;

ct = fields(obj.d.componentTargets);
componentData = [];
for i = 1:length(ct)
    componentData.(ct{i}) = [];
end
% fullComponentData = repmat(componentData, [1 length(obj.p)]);

% reorganise params to be per device.
for i = 1:length(p)
    trialComponentData = componentData;
    trialData = p(i);
    for cIdx = 1:length(ct)
        compID = ct{cIdx};
        targets = obj.d.componentTargets.(compID);
        componentData = [];
        for f = 1:length(targets)
            if isfield(trialData.params, targets{f})
                componentData.(targets{f}) = trialData.params.(targets{f});
            end
        end
        if isempty(componentData)
            continue
        end
        if length(fields(componentData)) == 1 && any(strcmpi(fields(componentData),compID))
            componentData = componentData.(compID);
        end
        trialComponentData.(compID) = componentData;
    end
    p(i).params = trialComponentData;
end

if createChans
    % first time loading a trial. Initialise.
    for i = 1:length(obj.d.Available)
        if ~obj.d.Active(i) || ~isa(obj.d.Available{i}, 'DAQComponent')
            continue
        end
        comp = obj.d.Available{i};
        obj.indicateLoading("Creating channels...");
        if ~isempty(obj.d.ActiveIDs)
            obj.d.Available{i} = comp.InitialiseSession('ActiveDeviceIDs', obj.d.ActiveIDs);
        else
            obj.d.Available{i} = comp.InitialiseSession('ActiveDeviceIDs', 'all');
        end
    end
end

% load to device
obj.p = p;
obj.g = g;
obj.trialIdx = 1;
obj.trialNum = 1;

obj.indicateLoading("Protocol load completed. Loading trial.");

% refresh information scroller
obj.h.trialInformationScroller.Value = '';

%% calculate estimated time + rest time
protocolTotalTimeSecs = (obj.g.dPause(1)*(obj.g.nProtRuns-1) + ((sum(([obj.p.tPre] + [obj.p.tPost]).*[obj.p.nRuns])))*obj.g.nProtRuns/1000);
protocolTimeMins = floor(protocolTotalTimeSecs/60);
protocolTimeSecs = ceil(protocolTotalTimeSecs - (60*protocolTimeMins));
obj.h.protocolTimeEstimate.Text = sprintf('0:00 / %d:%d', protocolTimeMins, protocolTimeSecs);
obj.h.trialInformationScroller.Value = '';
obj.h.trialInformationScroller.FontColor = 'black';

%% Update paths
obj.g.sequence = generateSequence(obj);

%% Load first trial
obj.callbackLoadTrial(src, event);

obj.status = 'ready';
end

function seq = generateSequence(obj)
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

%% Helpers
function targets = getAllTargets(p)
    targets = {};
    for i = 1:length(p)
        fds = fields(p(i).params);
        for j = 1:length(fds)
            if ~any(contains(targets, fds{j}))
                targets{end+1} = fds{j};
            end
        end
    end
end

function checkStimulus(obj)
    [filename, dir] = uigetfile([obj.path.protocolBase filesep '*.*'], 'Select protocol. WARNING: This will plot all trials at once. Isolate the trial you want to check within the file itself.');
    if filename == 0
        return
    end
    fpath = [dir filesep filename];
    if contains(fpath, '.stim')
        [p, g] = readProtocol(fpath, true);
    else
        error("Unsupported file format. Supported formats: .qst, .stim");
    end
end