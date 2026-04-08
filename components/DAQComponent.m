classdef (HandleCompatible) DAQComponent < HardwareComponent
% Generic wrapper class for DAQ objects
% https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.html
% https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.write.html

properties (Constant, Access = public)
    ComponentProperties = DAQComponentProperties;
end

properties (Access = protected)
    SessionInfo = struct();
    ChannelMap = []; % primary key of connected device
    PreviewChannels = []; 
    PreviewTimeAxis = [];
    OutChanIdxes = [];
    InChanIdxes = [];
    SaveFID = [];
    PreviewData = [];
    tiledLayout = [];
    tPrePost = [];
    idxData;
end

properties(Access = private)
    StackedPreview = [];
    triggerIdx = 1; % for on-demand DAQ write operations only.
    timeoutWait = 0;
    axHandles = {};
    pltHandles = {};
    anHandles = {};
    previewIdxes = [];
    nScans = 0;
    stopping = false;
    timeoutTic = [];
end

methods (Access = public, Static)
    function ClearAll()
        % Complete reset. Clear device.
        daqreset;
    end

    function components = FindAll(varargin)
        % Find all attached DAQs and initialise if desired.
        % ARGUMENTS: 
        %     Initialise (logical, true): whether to start each device's associated hardware session
        %     Params (struct, []): device parameters, used to pre-load device configurations
        % RETURNS:
        %     components (cell array): cell array of all detected Components.
        p = inputParser();
        addParameter(p, 'Initialise', false, @islogical);
        addParameter(p, 'Params', [], @(x) isstruct(x) || isempty(x));
        p.parse(varargin{:});
        components = {};
        daqs = daqlist();
        for i = 1:height(daqs)
            s = table2struct(daqs(i, :));
            % todo - only if there is no protocolID connected to device in config file
            protocolID = [DAQComponentProperties.ProtocolID.default char(string(i))];
            %todo - temp while I get above working
            if contains(s.Model, 'Sim')
                protocolID = 'SIM';
            elseif ~strcmpi(s.DeviceID, "Dev1")
                protocolID = char(s.DeviceID);
            else
                protocolID = 'TriggerDAQ';
            end
            initStruct = struct( ...
                'Vendor', s.VendorID, ...
                'ID', s.DeviceID, ...
                'Model', s.Model, ...
                'ProtocolID', protocolID);
            comp = DAQComponent('Initialise', p.Results.Initialise, ...
                'ConfigStruct', initStruct, 'ChannelConfig', false);
            % if component is in map file, set protocolID
            % if ~isempty(pids) && 
            %     comp.ProtocolID
            % end
            components{end+1} = comp;
        end
    end
end

methods (Access = public)
function obj = DAQComponent(varargin)
    p = obj.GetBaseParser();
    addParameter(p, 'ChannelConfig', '', @(x) isstring(x) | ischar(x) | islogical(x))
    parse(p, varargin{:});
    params = p.Results;

    obj = obj.Initialise(params);
    if contains(lower(obj.ComponentID), 'sim')
        obj.ConfigStruct.ProtocolID = 'Sim'; %TODO THIS IS NOT ROBUST - REMOVE
    end
    if params.Initialise && ~params.Abstract
        obj = obj.InitialiseSession('ConfigStruct', params.ConfigStruct, ...
            'ChannelConfig', params.ChannelConfig);
    end
end

function Debug(obj)
    keyboard
end

function obj = InitialiseSession(obj, varargin)
    % Initialise device. 
    p = inputParser;
    addParameter(p, 'ChannelConfig', '', @(x) ischar(x) || isstring(x) || islogical(x));
    addParameter(p, 'ConfigStruct', []);
    addParameter(p, 'KeepHardwareSettings', []);
    addParameter(p, 'ActiveDeviceIDs', {}, @(x) iscellstr(x) || (ischar(x) && strcmpi(x, 'all')));
    parse(p, varargin{:});
    params = p.Results;

    %---device---
    if isempty(obj.SessionHandle) || ~isvalid(obj.SessionHandle) || ~isempty(params.ConfigStruct)
        % if the DAQ is uninitialised or the params have changed
        daqStruct = obj.GetConfigStruct(params.ConfigStruct);
        if isempty(params.ConfigStruct) && isempty(obj.ConfigStruct)
            name = obj.FindDaqName(daqStruct.ID, '', '');
        else
            deviceID = daqStruct.ID;
            vendorID = daqStruct.Vendor;
            model = daqStruct.Model;
            name = obj.FindDaqName(deviceID, vendorID, model);
        end
        obj.ConfigStruct = daqStruct;
        obj.SessionHandle = daq(name);
        obj.SessionHandle.Rate = daqStruct.Rate;
    end
    
    %---channels---
    if isempty(obj.ConnectedDevices)
        [s, pcInfo] = system('vol');
        pcInfo = strsplit(pcInfo, '\n');
        pcID = pcInfo{2}(end-8:end);
        filename = [pcID '_' obj.ComponentID '.csv'];
        if ~contains(obj.ConfigStruct.ChannelConfig, filename)
            if ~isfile(obj.ConfigStruct.ChannelConfig)
                if ~strcmpi(obj.ConfigStruct.ChannelConfig(end), filesep)
                    obj.ConfigStruct.ChannelConfig = [obj.ConfigStruct.ChannelConfig filesep filename];
                else
                    obj.ConfigStruct.ChannelConfig = [obj.ConfigStruct.ChannelConfig filename];
                end
            end
        end
        obj = obj.MapChannels(obj.ConfigStruct.ChannelConfig);
    end
    if (islogical(params.ChannelConfig) && params.ChannelConfig) || ...
            (~islogical(params.ChannelConfig) && ~isempty(params.ChannelConfig)) || ...
            ~isempty(params.ActiveDeviceIDs)
        % current value is default
        obj = obj.CreateChannels(obj.ConfigStruct.ChannelConfig, params.ActiveDeviceIDs);
    end
end

% Start device
function StartTrial(obj)
    obj.timeoutTic = []; % reset timeout tracker
    while obj.stopping % if it's stopping, don't hit start.
        pause(0.2)
    end
    obj.idxData = 1;
    % Starts device with a preloaded session. 
    if ~isempty(obj.SavePath) || length(obj.SavePath) ~= 0
        % save channel names
        filename = [obj.ConfigStruct.ProtocolID '_channelNames.csv'];
        channelNames = {obj.SessionHandle.Channels.Name};
        channelNames = [{"Time"} channelNames];
        filepath = [obj.SavePath filesep filename];
        writecell(channelNames, filepath);        
    end
    if ~isempty(obj.TriggerTimer) && isvalid(obj.TriggerTimer)
        % run stimulation on matlab timer
        start(obj.TriggerTimer);
        % try
        %     wait(obj.TriggerTimer)% wait for data acquisition
        % catch me
        %     warning(me.identifier,'%s',...      % rethrow timeout error as warning
        %         me.message);
        % end
    else
        % run stimulation on DAQ clock
        start(obj.SessionHandle);               % start data acquisition
    end
end

% Stop device
function Stop(obj)
    if obj.stopping % attempt to solve the crashing issue.
        disp("WAITING ON PREVIOUS STOP");
        return
    end
    obj.stopping = true;
    pause(0.1); % wait for the buffers to flush.
    if ~isempty(obj.SessionHandle) && obj.SessionHandle.Running
        stop(obj.SessionHandle);
    end
    if ~isempty(obj.TriggerTimer) && isvalid(obj.TriggerTimer) && strcmpi(obj.TriggerTimer.Running, 'on')
        stop(obj.TriggerTimer);
        delete(obj.TriggerTimer);
    end
    try
        flush(obj.SessionHandle);
        fclose(obj.SaveFID);
    catch
        %file already closed. Do nothing.
    end
    obj.stopping = false;
end

function Close(obj)
    % safely close the session
    Stop(obj);
    %todo disconnect?
end

% Change device parameters TODO ALL OF THESE REQUIRE A RESTART I THINK
function SetParams(obj, paramsStruct)
    paramFields = fields(paramsStruct);
    for i = 1:length(paramFields)
        param = paramFields{i};
        val = paramsStruct.(param);
        if any(contains(fields(obj.ConfigStruct), param)) 
            if obj.ComponentProperties.(param).isValid(val) 
                obj.ConfigStruct = setfield(obj.ConfigStruct, param, val);
            else
                error("Invalid value provided for field %s: %s", param, val)
            end
        elseif ~strcmpi(param, 'SavePath')
            error("Could not set field %s. Valid fields are: %s, SavePath", param, getfields(obj.ConfigStruct));
        end
        switch param
            case "ProtocolID"
                obj.ConfigStruct.ProtocolID = val;
            case "Rate"
                obj.Stop();
                if ~isnumeric(val)
                    val = str2double(val);
                end
                if ~isempty(obj.SessionHandle) && isvalid(obj.SessionHandle)
                    obj.SessionHandle.Rate = val;
                end
                obj.ConfigStruct.Rate = val;
        end
    end
end

function PrintInfo(obj)
    % Print device information.
    disp(' ');
    disp(obj.SessionHandle.Channels);
    disp(' ');
end

function StartPreview(obj)
    % Dynamically visualise object output
    if isempty(obj.PreviewPlot) || isempty(obj.SessionHandle)
        return
    end
    %clear previous preview data, if any
    obj.StopPreview;
    if isempty(obj.PreviewData)
        obj.Previewing = true;
        obj.PreviewPlot.Visible = 'on';
        x = 400;
        y = 400;
        imshow(ones(x,y),[],'parent',obj.PreviewPlot);
        text(x/2,y/2, 'No data', ...
            'Parent', obj.PreviewPlot, 'FontSize', 16, 'FontWeight','bold', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Color', 'black');
        return
    end
    
    % construct labels
    obj.Previewing = true;
    names = {obj.SessionHandle.Channels.Name};
    names = cellfun(@(x) replace(x, '_', ' '), names, 'UniformOutput', false);
    ids = {obj.SessionHandle.Channels.ID};
    comb = {ids{:}; names{:}}';
    fmt = ['%s' ': ' '%s']; % prev newline
    displayLabels = compose(fmt, string(comb));
    displayLabels = displayLabels(obj.PreviewChannels);
    
    % set up plots
    obj.PreviewPlot.Visible = 'off';
    nPlots = sum(obj.PreviewChannels);
    obj.previewIdxes = find(obj.PreviewChannels);
    obj.PreviewPlot.Parent.RowHeight = repmat({'1x'}, [1 nPlots]);
    obj.PreviewPlot.Layout.Row = [1 nPlots];
    xLims = [obj.PreviewTimeAxis(1) obj.PreviewTimeAxis(end)];
    
    % clear plots
    if length(obj.PreviewPlot.Parent.Children) > 1
        delete(obj.PreviewPlot.Parent.Children(2:end));
        % obj.axHandles = gobjects([nPlots 1]); %this copies them :(((((
        % obj.pltHandles = gobjects([nPlots 1]);
        % obj.anHandles = gobjects([nPlots 1]);
    end    
    
    % create axes and plots
    for i = 1:nPlots
        ax = axes(obj.PreviewPlot.Parent);
        ax.Layout.Row = i;
        ax.Layout.Column = 1;

        plt = plot(ax, obj.PreviewTimeAxis, obj.PreviewData(:,obj.previewIdxes(i)));
        plt.YDataSource = sprintf('obj.PreviewData(:,obj.previewIdxes(%d))', i);
        % an = animatedline(ax, obj.PreviewTimeAxis, obj.PreviewData(:,obj.previewIdxes(i)));
        % an.Color = 'red';
        % datalink might be handy
        ax.XLim = xLims; %why does this sometimes work and sometimes not?
        axisTitle = displayLabels{i};
        if any(regexpi(axisTitle, "thermode"))
            ax.YLim = [-1 61];
        elseif any(regexpi(obj.SessionHandle.Channels(obj.previewIdxes(i)).Type, "digital"))
            ax.YLim = [-2 2];
        else
            ax.YLim = [-11 11];
        end
        ch = obj.SessionHandle.Channels(obj.previewIdxes(i));
        ax.Title = text(ax, 'String', displayLabels{i}, ...
            'HorizontalAlignment', 'left');
        ax.TitleHorizontalAlignment = 'left';
        % obj.axHandles(i) = ax;
        % obj.pltHandles(i) = plt;
        % obj.anHandles(i) = an;
    end
end

function StopPreview(obj)
    if isempty(obj.PreviewPlot) || isempty(obj.SessionHandle)
        return
    end
    if ~isempty(obj.PreviewPlot.Children)
        delete(obj.PreviewPlot.Children);
    end
    if ~isempty(obj.StackedPreview) && isvalid(obj.StackedPreview)
        delete(obj.StackedPreview);
        obj.PreviewPlot.Visible = 'on';
    end
    obj.Previewing = false;
end

function LoadTrial(obj, out)
    % Loads a trial from a matrix of size c x s where c is the number of
    % output channels and s is the number of samples in the trial.
    if isempty(out)
        out = obj.PreviewData(:,obj.OutChanIdxes);
    end
    % release session (in case the previous run was incomplete)
    if obj.SessionHandle.Running
        obj.SessionHandle.stop
    end
    flush(obj.SessionHandle);
    if obj.SessionHandle.Rate == 0 && any(contains({obj.SessionHandle.Channels.Type}, 'Output')) 
        % clocked sampling not supported - timer required for outputs.
        % todo - logic above isn't quite right. The actual logic (for a USB-6001) is 
        % (rate == 0 && any digital channels) or (rate == 0 and any analog channels and no clock input)
        % https://docs-be.ni.com/bundle/usb-6000-6001-6002-6003-features/raw/resource/enus/374259a.pdf
        obj.CreateSoftwareTriggerTimer(obj.ConfigStruct.Rate);

    elseif any(contains({obj.SessionHandle.Channels.Type}, 'Output'))
        % normal DAQ things hell yeah
        preload(obj.SessionHandle, out); 
    end
    obj.nScans = length(obj.PreviewData);
end

function LoadTrialFromParams(obj, componentTrialData, genericTrialData, preloadDevice)
    % load trial from params. Does not preload data to session handle
    rate = obj.SessionHandle.Rate;
    if rate==0
        % Software triggering required - only on-demand operations supported.
        rate = obj.ConfigStruct.Rate;
    end
    tPre     = genericTrialData.tPre  / 1000;
    tPost    = genericTrialData.tPost / 1000;
    tTotal   = tPre + tPost;
    obj.tPrePost = [genericTrialData.tPre genericTrialData.tPost];
    obj.timeoutWait = tTotal;

    % Add Listener 
    if ~obj.SessionHandle.Running
        obj.SessionHandle.ScansAvailableFcn = @obj.plotData;
    end

    fds = fields(componentTrialData);
    timeAxis = linspace(1/rate,tTotal,tTotal*rate)-tPre;
    obj.PreviewTimeAxis = timeAxis;
    stimLength = numel(timeAxis);
    tPreLength = round(genericTrialData.tPre * obj.SessionHandle.Rate/1000);
    % Preallocate all zeros
    previewOut = zeros(numel(timeAxis), length(obj.SessionHandle.Channels));
    out = zeros(numel(timeAxis), sum(contains({obj.SessionHandle.Channels.Type}, 'Output')));
    % if isempty(obj.ChannelMap)
    %     obj = obj.CreateChannels(obj.ConfigStruct.ChannelConfig, 'all');
    % end
    for i = 1:length(fds)
        fieldName = fds{i};
        % targetNames = fields(obj.ChannelMap);
        % find all channel indexes associated with the stimulus type.
        [chIdxes, labels] = obj.getDeviceChannelIdxes(fieldName);
        outIdxes = [];
        chIdxesToRemove = [];
        for i = 1:length(chIdxes)
            ci = chIdxes(i);
            outIdx = find(obj.OutChanIdxes == ci);
            if ~isempty(outIdx)
                outIdxes(end+1) = outIdx;
            else
                chIdxesToRemove = [chIdxesToRemove i];
            end
        end
        chIdxes(chIdxesToRemove) = [];
        if isempty(outIdxes)
            warning("[DAQCOMPONENT] No output channels assigned for stimulus %s in DAQ %s. Check the channel config file.", fieldName, obj.ComponentID);
            continue
        end
        % Generate Stimulus. Handle special cases.
        params = componentTrialData.(fieldName);
        %todo preloading PWM as special case
        % if strcmpi(lower(params.params.Type), 'pwm') && obj.ChannelMap
        if obj.SessionHandle.Rate == 0
            rate = obj.ConfigStruct.Rate;
        else
            rate = obj.SessionHandle.Rate;
        end
        stim = StimGenerator.GenerateStimTrain(componentTrialData.(fieldName), genericTrialData, rate);
        for idx = outIdxes
            if length(out) ~= length(stim)
                warning("[DAQCOMPONENT] Stim length mismatch for %s. Stim length was %d, but out length was %d. Output cropped.", fieldName, length(stim), length(out))
                stim = stim(1:length(out)); 
            end
            out(:,idx) = stim;
        end
        for idx = chIdxes
            previewOut(:, idx) = stim;
        end
    end
    obj.PreviewData = previewOut;
    if preloadDevice
        obj.LoadTrial(out);
    end
    if ~isempty(obj.PreviewPlot) % show preview data
        obj.StartPreview
    end
end

%% DEVICE-SPECIFIC FUNCTIONS
function obj = MapChannels(obj, filename)
    % fills out DAQ's connected devices
    if ~isfile(filename)
        return
    end
    tab = readtable(filename);
    s = size(tab);
    for rowIdx = 1:s(1)
        line = tab(rowIdx, :);
        deviceName = line.('Device'){:};
        if ~isempty(deviceName) && ...
            (isempty(obj.ConnectedDevices) || ~any(contains(obj.ConnectedDevices, deviceName)))
            obj.ConnectedDevices = [obj.ConnectedDevices string(deviceName)];
        end
    end
end

function info = deviceInfo(obj)
    if isempty(obj.SessionHandle)
        info = [];
        return
    end
    deviceID = obj.ConfigStruct.ID;
    daqs = daqlist;
    info = daqs(strcmpi(daqs.DeviceID, deviceID),:).DeviceInfo;

    channelNames = info.Subsystems.ChannelNames;
    % channelProperties = info.
end

function obj = CreateChannels(obj, filename, protocolIDs)
    % Create DAQ channels from filename and a list of active protocol IDs
    if isempty(obj.SessionHandle) || ~isvalid(obj.SessionHandle)
        error("DAQComponent %s has no valid session handle to attach channels to.", obj.ComponentID);
    end
    if isempty(filename)
        filename = obj.ConfigStruct.ChannelConfig;
    end
    if isempty(obj.PreviewPlot)
        progressfig = uifigure;
    else
        progressfig = obj.PreviewPlot.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent; %cursed but it's late on a friday.
    end
    progressdlg = uiprogressdlg(progressfig,'Title','Creating Channels...',...
        'Message','');
    % clear previous channels, if any
    % obj = obj.ClearChannels();
    % obj.SessionHandle.
    tab = readtable(filename);
    s = size(tab);
    % if ~isMATLABReleaseOlderThan('R2024b')
    %     channelList = daqchannellist;
    % end
    for ii = 1:s(1)
        try
            warning('');
            line = tab(ii, :); %TODO CHECK FOR BLANKS
            % line.('deviceID') or line.(1);
            if ~isempty(protocolIDs) && (~ischar(protocolIDs) || ~strcmpi(protocolIDs, 'all'))...
                && ~any(contains(protocolIDs, line.('Device'){:}))
                % skip channels that aren't required for this protocol.
                continue
            end
            tmp = strsplit(obj.ComponentID, '_');
            deviceID = tmp{1};
            portNum = line.('portNum'){1}; 
            channelID = [line.Device{:} '_' line.Label{:}];
            % channelID = [line.ProtType{:} line.ProtID{:}];
            ioType = line.('ioType'){1};
            signalType = line.('signalType'){1};
            terminalConfig = line.('TerminalConfig');
            if contains(class(terminalConfig), 'cell')
                terminalConfig = terminalConfig{1};
            end
            range = line.('Range');
            if contains(class(range), 'cell')
                range = range{1};
            end
            % if ~isMATLABReleaseOlderThan('R2024b')
            %     channelList = add(channelList, ioType, deviceID, portNum, signalType, TerminalConfig=terminalConfig, Range=range);
            % else
            switch ioType
                case 'input'
                    [ch, idx] = addinput(obj.SessionHandle,deviceID,portNum,signalType);
                    obj.InChanIdxes(end+1) = idx;
                case 'output'
                    [ch, idx] = addoutput(obj.SessionHandle,deviceID,portNum,signalType);
                    obj.OutChanIdxes(end+1) = idx;
                case 'bidirectional'
                    [ch, idx] = addbidirectional(obj.SessionHandle,deviceID,portNum,signalType);
                    obj.OutChanIdxes(end+1) = idx;
                    obj.InChanIdxes(end+1) = idx;
            end
            ch.Name = channelID;
            if ~isempty(terminalConfig) && ~contains(class(ch), 'Digital')
                ch.TerminalConfig = terminalConfig;
            end
            if ~isempty(range) && ~contains(class(ch), 'Digital')
                range = str2num(range);
                ch.Range = range;
            end
            obj.PreviewChannels(end+1) = logical(line.Preview);
            [warnMsg, warnId] = lastwarn;
            if ~isempty(warnMsg)
                message = ['Warning encountered loading DAQComponent channel information on line ' char(string(ii))];
                warning(message);
            end
            % end
            
            if ~isfield(obj.ChannelMap, line.Device{:})
                obj.ChannelMap.(line.Device{:}) = [];
            end
            obj.ChannelMap.(line.Device{:}).(line.Label{:}).idx = idx;
            obj.ChannelMap.(line.Device{:}).(line.Label{:}).ID = channelID;
            obj.ChannelMap.(line.Device{:}).(line.Label{:}).ioType = ioType;
            progressdlg.Message = sprintf("Created channel %d of %d (%s)", ii, s(1), channelID);
            progressdlg.Value = ii/s(1);
        catch exception
            message = ['Encountered an error reading channels config file on line ' ...
                    char(string(ii)) ': ' exception.message ' Line skipped.'];
            disp("")
            % todo pass warning messages back to StimControl so we can
            % display them good.
            warning(message);
        end
    end
    % if ~isMATLABReleaseOlderThan('R2024b')
    %     obj.SessionHandle.Channels = channelList;
    % end
    obj.PreviewChannels = logical(obj.PreviewChannels);
    delete(progressdlg);
end

function TrialMaintain(obj)
    % % manually stop the daq if it's finished
    h = obj.SessionHandle;
    if h.Running && h.NumScansAcquired == height(obj.PreviewData) && h.NumScansAvailable == 0 && isempty(obj.timeoutTic)
        obj.timeoutTic = tic;
    end
    if ~isempty(obj.timeoutTic) && toc(obj.timeoutTic) > 2
        % safeguard against premature stopping. Make sure the buffer is cleared.
        disp("[DAQCOMPONENT] attempting manual stop")
        obj.Stop();
        obj.timeoutTic = [];
    end
end

function obj = ClearChannels(obj)
        disp(message);
        % disp(exception.message)
        dbstack
        keyboard
        % if length(obj.SessionHandle.Channels) ~= 0
        %     removechannel(obj.SessionHandle, 1:length(obj.SessionHandle.Channels));
        % end
        % obj.ChannelMap = [];
        % obj.PreviewChannels = [];
        % obj.OutChanIdxes = [];
        % obj.InChanIdxes = [];
    end
end


%% Private Methods
methods (Access = protected)

function componentID = GetComponentID(obj)
    componentID = convertStringsToChars([obj.ConfigStruct.ID '-' obj.ConfigStruct.Vendor '-' obj.ConfigStruct.Model]);
    componentID = [componentID{:}];
    componentID = obj.SanitiseComponentID(componentID);
end

function SoftwareTrigger(obj, ~, ~)
    persistent triggerIdx;
    persistent t0;
    persistent tax;
    if isempty(triggerIdx)
        triggerIdx = 1; 
        t0 = tic;
        tax = zeros(length(obj.PreviewData), 1);
    end
    % nb using an incrementing IDX may lead to longer execution times.
    % could estimate the appropriate index based off execution time, but
    % that feels like overengineering.
    % disp(triggerIdx)
    if triggerIdx <= length(obj.PreviewData)
        write(obj.SessionHandle, obj.PreviewData(triggerIdx,obj.OutChanIdxes));
        readData = read(obj.SessionHandle);
        obj.PreviewData(triggerIdx, obj.InChanIdxes) = readData{:,:};
        tax(triggerIdx) = seconds(seconds(toc(t0)));
        triggerIdx = triggerIdx + 1;
        % update display? might be WAY too slow
        if ~mod(triggerIdx, 100)
            displayLabels = obj.StackedPreview.DisplayLabels;
            obj.StackedPreview.YData = obj.PreviewData(:,obj.PreviewChannels); %todo fix this it's VERY SLOW but I'm going to have to fix it by changing the plot function
            obj.StackedPreview.DisplayLabels = displayLabels;
        end
    else
        % write the whole thing at once
        if ~isfolder(obj.SavePath)
            mkdir(obj.SavePath)
        end
        tax = tax - tax(round(obj.tPrePost(1)*obj.ConfigStruct.Rate/1000));
        % scale data from thermodes, if relevant. TODO could be less hardcoded but this will do for now.
        if isfield(obj.ChannelMap, 'QST')
            if isfield(obj.ChannelMap.QST, 'thermodeA') && isfield(obj.ChannelMap.QST, 'thermodeB')
                qstIdxes = [obj.ChannelMap.QST.thermodeA.idx obj.ChannelMap.QST.thermodeB.idx];
                for i = qstIdxes
                    obj.PreviewData(:,i) = obj.PreviewData(:,i) * 12  - 2;
                end
            end
        end
        try
            writematrix([tax,obj.PreviewData(:,:)], ...
            strcat(obj.SavePath, filesep, obj.SavePrefix, '.csv'), ...
            'WriteMode', 'append');
        catch e
            keyboard;
            rethrow(e);
        end
        obj.Stop();
    end
end

function status = GetSessionStatus(obj)
    % get current device status.
    % STATUS:
    %   connected       device session initialised; not ready to start trial
    %   ready           device session initialised, trial loaded
    %   running         currently running a trial
    
    % persistent lastScanAcquired;
    status = '';
    if isempty(obj.SessionHandle.Channels)
        status = 'uninitialised'; %no channels loaded
    elseif obj.SessionHandle.Running 
        status = 'running'; % DAQ running
    elseif ~isempty(obj.TriggerTimer) && isvalid(obj.TriggerTimer) && strcmpi(obj.TriggerTimer.Running, 'on')
        status = 'running'; % Software triggered timer running
    elseif obj.SessionHandle.NumScansQueued ~= 0
        status = 'ready'; % ready for DAQ triggered run
    elseif ~isempty(obj.PreviewData) && ~isempty(obj.TriggerTimer) && isvalid(obj.TriggerTimer)
        status = 'ready'; % ready for software triggered run
    elseif ~isempty(obj.SessionHandle) && isvalid(obj.SessionHandle)
        status = 'connected';
    end
end

function name = FindDaqName(obj, deviceID, vendorID, model)
    % TODO shouldn't use this within StimControl but it's useful for other applications
    % Find available daq names
    % https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.html
    try
        daqs = daqlist().DeviceInfo;
    catch
        daqs = [];
    end
    if isempty(daqs)
        errorStruct.message = 'No data acquistion devices found or data acquisition toolbox missing.';
        errorStruct.identifier = 'DAQ:Initialise:NoDAQDevicesFound';
        error(errorStruct);
    end
    checker = false;
    for x = 1 : length(daqs)
        if (strcmpi(daqs(x).ID, deviceID) ...
                && isempty(vendorID) && isempty(model)) ||  ... %if only DAQ name is given
            (strcmpi(daqs(x).ID, deviceID) ...
                && strcmpi(daqs(x).Vendor.ID, vendorID) && isempty(model)) ||  ... %if only name and vendorID are given
            (strcmpi(daqs(x).ID, deviceID) ...
                && strcmpi(daqs(x).Vendor.ID, vendorID) ...
                && strcmpi(daqs(x).Model, model)) % if more info is given. todo check this logic is sound
            checker = true;
            correctIndex = x;
        end
    end
    if ~checker
        warning(['Could not find specified DAQ: ' deviceID ' - Using existing board ' daqs(x).ID ' instead.'])
        correctIndex = x;
    end
    name = daqs(correctIndex).Vendor.ID;
end

function [idxes, labels] = getDeviceChannelIdxes(obj, targetName)
    % get indexes of all 'out' channels for the device.
    if isempty(obj.ChannelMap)

    end
    chans = fields(obj.ChannelMap.(targetName));
    idxes = [];
    labels = [];
    for fidx = 1:length(chans)
        labelName = chans{fidx};
        idxes = [idxes obj.ChannelMap.(targetName).(labelName).idx];
        labels = [labels labelName];
    end
end


function plotData(obj, ~,event)
    % manage persistent variables
    persistent emptyCount
    eventData = read(event.Source);

    if obj.idxData > obj.nScans
        % cut off the end of the data? TODO CHECK THIS IS DESIRED BEHAVIOUR
        if ~isempty(eventData)
            disp("we have too much data??");
        end
        return
    end
    if ~isfolder(obj.SavePath)
        mkdir(obj.SavePath)
    end

    % check data exists.
    if ~isempty(eventData)
        targetIdx = obj.idxData:eventData.NumScans+obj.idxData-1;
        data = eventData.Data;
        % scale data from thermodes and aurora, if relevant. TODO could be less hardcoded but this will do for now.
        if isfield(obj.ChannelMap, 'QST')
            % % dat(:,idxData(1:2)) = dat(:,idxData(1:2)) * 17.0898 - 5.0176;
            qstIdxes = [obj.ChannelMap.QST.thermodeA.idx obj.ChannelMap.QST.thermodeB.idx];
            for i = qstIdxes
                data(:,i) = data(:,i) * 12  - 2; % PB 20241219
            end
        end
        % if isfield(obj.ChannelMap, 'Aurora')
        %     auroraIdxes = [obj.ChannelMap.Aurora.force.idx obj.ChannelMap.Aurora.length.idx];
        %     for i = auroraIdxes
        %         data(:,i) = data(:,i)*10 + 32;
        %     end
        % end
        % TODO DC TEMPERATURE CONTROLLER ALSO NEEDS CALIBRATION - FHC DC TEMPERATURE CONTROLLER
        obj.PreviewData(targetIdx, obj.InChanIdxes) = data;  

        % update plots
        for i = 1:length(obj.previewIdxes)
            % this is cursed but hey if it works. Still way quicker than StackedPlot.
            obj.PreviewPlot.Parent.Children(i+1).Children(1).YData(targetIdx) = obj.PreviewData(targetIdx, obj.previewIdxes(i));
        end

        try
            writematrix([eventData.Timestamps-obj.tPrePost(1),obj.PreviewData(targetIdx,:)], ...
            strcat(obj.SavePath, filesep, obj.SavePrefix, '.csv'), ...
            'WriteMode', 'append');
            % fwrite(obj.SaveFID,[data.Timestamps-obj.tPrePost(1),obj.PreviewData(targetIdx)'],'double');
        catch e
            keyboard;
            rethrow(e);
        end
        obj.idxData = obj.idxData + eventData.NumScans;
        emptyCount = 0;
    else
        if isempty(emptyCount)
            emptyCount = 1;
        else
            emptyCount = emptyCount + 1;
        end
    end
end

end
end