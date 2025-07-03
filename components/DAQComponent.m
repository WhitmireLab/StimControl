classdef (HandleCompatible) DAQComponent < HardwareComponent
% Generic wrapper class for DAQ objects

properties (Access = public)
end

properties (Access = protected)
    SessionInfo = struct();
    ChannelMap = struct();
    HandleClass = 'daq.interfaces.DataAcquisition';
    TrackedChannels = {};
end

methods (Access = public)
function obj = DAQComponent(varargin)
    p = obj.GetBaseParser();
    % add device-specific parameters here
    strValidate = @(x) isstring(x) || ischar(x);
    addParameter(p, 'ChannelConfig', '', strValidate);
    parse(p, varargin{:});
    params = p.Results;
    % extract device-specific parameters here
    obj = obj.CommonInitialisation(params);
    if ~params.Abstract
        obj = obj.Configure('ChannelConfig', params.ChannelConfig, ...
            'Struct', params.Struct);
    end
end

function obj = Configure(obj, varargin)
    % Initialise device. 
    %TODO STOP/START
    strValidate = @(x) ischar(x) || isstring(x);
    p = inputParser;
    addParameter(p, 'ChannelConfig', '', strValidate);
    addParameter(p, 'Struct', []);
    parse(p, varargin{:});
    params = p.Results;

    %---device---
    if isempty(obj.SessionHandle) || ~isvalid(obj.SessionHandle) || ~isempty(params.Struct)
        % if the DAQ is uninitialised or the params have changed
        daqStruct = obj.GetConfigStruct(params.Struct);
        if isempty(params.Struct) && isempty(obj.ConfigStruct)
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
    if isempty(params.ChannelConfig)
        warning("No DAQ Channel information provided. " + ...
            "Provide channel configuration via obj.Configure('ChannelConfig', filepath)");
    else
        obj = obj.CreateChannels(params.ChannelConfig);
    end
    
    %---display---
    if ~isempty(obj.SessionHandle.Channels)
        obj.PrintInfo();
    end
end

function status = GetStatus(obj)
    % Query device status. 
    %options: ready / acquiring / writing / error / stopped / empty
    %/ loading
    %TODO
end

% Start device
function Start(obj)
    %TODO startbackground?
    start(obj.SessionHandle);
end

%Stop device
function Stop(obj)
    stop(obj.SessionHandle);
end

% Change device parameters
function SetParams(obj, varargin)
    for i = 1:length(varargin):2
        set(obj.SessionHandle, varargin(i), varargin(i+1));
    end
end

function daqStruct = GetParams(obj)
    % Get current device parameters for saving. Generic.          
    daqs = daqlist().DeviceInfo;
    correctIndex = -1;
    for i = 1:length(daqs)
        if strcmpi(obj.SessionHandle.Vendor.ID, daqs(i).Vendor.ID)
            correctIndex = i;
        end
    end
    if correctIndex == -1
        warning("Unable to find DAQ in daqlist. " + ...
            "DAQ device settings not saved."); %note this should NEVER happen
    end
    d = daqs(correctIndex);
    daqStruct = struct();
    daqStruct.Vendor = d.Vendor.ID;
    daqStruct.Model = d.Model;
    daqStruct.ID = d.ID;
    daqStruct.Rate = obj.SessionHandle.Rate;
end

function channelData = GetChanParams(obj)
    % Get channel parameters for saving. DAQ-specific.
    channels = obj.SessionHandle.Channels;
    channelData = {'deviceID' 'portNum' 'channelName' 'ioType' ...
        'signalType' 'TerminalConfig' 'Range'};
    nChans = size(channels);
    nChans = nChans(2);
    for i = 1:nChans
        chan = channels(i);
        deviceID = chan.Device.ID;
        portNum = chan.ID;
        name = chan.Name;
        if contains(ch.Type, "Output")
            ioType = 'output';
        elseif contains(ch.Type, "Input")
            ioType = 'input';
        else
            ioType = 'bidirectional';
        end
        signalType = chan.MeasurementType;
        terminalConfig = chan.TerminalConfig;
        range = ['[' char(string(chan.Range.Min)) ' ' char(string(ch.Range.Max)) ']'];
        chanCell = {deviceID portNum name ioType signalType terminalConfig range};
        channelData(i+1,:) = chanCell;
    end
end

function obj = LoadParams(obj, folderpath)
    % Load in a saved set of parameters from a file. Largely deprecated
    if contains(folderpath, "ChanParams")
        obj = obj.CreateChannels(folderpath);
    elseif contains(folderpath, "DaqParams")
        obj = obj.Configure(folderpath);
    else
        % assume a folder with both params in it.
        obj = obj.Configure([folderpath filesep "DaqParams.csv"]);
        obj = obj.CreateChannels([folderpath filesep "DaqChanParams.csv"]);
    end
end

function PrintInfo(obj)
    % Print device information.
    disp(' ');
    disp(obj.SessionHandle.Channels);
    disp(' ');
end

function Clear(obj)
    % Completely clear the component session.
    if isvalid(obj.SessionHandle) && obj.SessionHandle.Running
        obj.Stop();
    end
    daqreset;
end

%% TODO STARTS HERE
function VisualiseOutput(obj, varargin)
    % Dynamically visualise object output
    p = inputParser;
    p.addParameter("Plot", []);
    p.parse(varargin{:});
    target = p.Results.Plot;
    if isempty(obj.SessionHandle)
        return;
    end
end

% Load a full experimental protocol
function obj = LoadProtocol(obj, varargin)
    parser = inputParser;
    stringValidate = @(x) ischar(x) || isstring(x);
    intValidate = @(x) ~isinf(x) && floor(x) == x;
    addParameter(parser, 'idxStim', 1, intValidate);
    addParameter(parser, 'filepath', '', stringValidate);
    addParameter(parser, 'p', '', @isstruct);
    addParameter(parser, 'g','', @isstruct);
    parse(parser, varargin{:});

    if ~isempty(parser.Results.filepath)
        [p, g] = readParameters(parser.Results.filepath);
    elseif ~isempty(parser.Results.p) && ~isempty(parser.Results.g)
        p = parser.Results.p;
        g = parser.Results.g;
    else
        error("No protocol provided for DAQComponent. Provide a " + ...
            "protocol using LoadProtocol and defining either the " + ...
            "'filename' or 'p' and 'g' arguments.")
    end
    obj.SessionInfo.p = p;
    obj.SessionInfo.g = g;

    obj.LoadTrial('idxStim', parser.Results.idxStim);
end

function LoadTrial(obj, varargin)
    % Preload a trial.
    parser = inputParser;
    stringValidate = @(x) ischar(x) || isstring(x);
    intValidate = @(x) ~isinf(x) && floor(x) == x;
    addParameter(parser, 'idxStim', 1, intValidate);
    addParameter(parser, 'filepath', '', stringValidate);
    addParameter(parser, 'p', '', @isstruct);
    addParameter(parser, 'g','', @isstruct);
    addParameter(parser, 'oneOff', false, @islogical);
    parse(parser, varargin{:});
    idxStim = parser.Results.idxStim;
    if ~isempty(parser.Results.filepath)
        [p, g] = readProtocol(parser.Results.filepath);
    elseif ~isempty(parser.Results.p)
        p = parser.Results.p;
        g = parser.Results.g;
    else
        p = obj.SessionInfo.p;
        g = obj.SessionInfo.g;
    end

    % release session (in case the previous run was incomplete)
    if obj.SessionHandle.Running
        obj.SessionHandle.stop
    end
    % release(obj.SessionHandle)
    
    channels = obj.SessionHandle.Channels;
    
    if isempty(p) || parser.Results.oneOff %TODO
        % single stimulation: use default values for tPre (time before onset of
        % stimulus) and tPost (time after onset of stimulus). Obtain duration
        % of vibration from respective GUI fields.
    else
        % protocol run: use values from protocol structure
        tPre     = p(idxStim).tPre  / 1000;
        tPost    = p(idxStim).tPost / 1000;
        vibDur   = cellfun(@(x) p(idxStim).(x).VibrationDuration,IDtherm) / 1000;
        ledDur   = p(idxStim).ledDuration / 1000;
        ledFreq  = p(idxStim).ledFrequency;
        ledDC    = p(idxStim).ledDutyCycle;
        ledDelay = p(idxStim).ledDelay / 1000;
        piezoAmp = p(idxStim).piezoAmp * Aurorasf; piezoAmp = min([piezoAmp 9.5]);  %added a safety block here 2024.11.15
        piezoFreq= p(idxStim).piezoFreq;
        piezoDur = p(idxStim).piezoDur;
        piezoStimNum= p(idxStim).piezoStimNum;
    end

    obj.SessionHandle.ScansAvailableFcn = @obj.plotData;

    fs = 1000;
    tTotal  = tPre + tPost;

    fds = fields(p);
    unmatchedFields = 'No DAQ match found for protocol fields: ';
    unmatchedFound = false;
    for i = 1:length(fds)
        fieldName = fds{i};
        if contains(['tPre', 'tPost'], fieldName)
            continue
        elseif ~any(cellfun(@(x) contains(x, fieldName), fields(obj.ChannelMap)))
            % if fieldname doesn't match with any channel identifiers
            strcat(unmatchedFields, [fieldName ', '])
            unmatchedFound = true;
            continue
        else
            obj.TrackedChannels{length(matchedFields) + 1} = fieldName;
        end
    end
    if unmatchedFound 
        warning(unmatchedFields);
    end
    timeAxis = linspace(1/obj.SessionHandle.Rate,tTotal,tTotal*obj.SessionHandle.Rate)-tPre;
    % Preallocate all zeros
    out = zeros(numel(timeAxis), length(d.SessionHandle.Channels));
    for fieldName = matchedFields
        out = obj.FillChannelData(out, numel(timeAxis), p(fieldName), fieldName);
    end
end

function componentProperties = GetComponentProperties(obj)
    componentProperties = struct( ...
    ID = struct( ...
        default     = 'Dev1', ...
        allowable   = {daqlist().DeviceInfo.ID}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = ""), ...
    Rate = struct( ...
        default     = 1000, ...
        allowable   = {{}}, ... 
        validatefcn = @(x) isnumeric(x) && x > 0, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Sampling rate in Hz"), ...
    Vendor = struct( ...
        default     = 'ni', ...
        allowable   = {daqlist().DeviceInfo.Vendor.ID}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Used to initialise"), ...
    Model = struct( ...
        default     = '', ...
        allowable   = {daqlist().DeviceInfo.Model}, ... 
        validatefcn = @(x) true, ...
        dependencies= @(propStruct) true, ... 
        required    = @(propStruct) true, ...
        note        = "Distinguishes between multiple daqs with the same vendor") ...
   );
end
end

%% Private Methods
methods (Access = public)
function name = FindDaqName(obj, deviceID, vendorID, model)
    % Find available daq names
    % https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.html
    try
        daqs = daqlist().DeviceInfo;
    catch
        daqs = [];
    end
    if isempty(daqs)
        errorStruct.message = "No data acquistion devices found or data acquisition toolbox missing.";
        errorStruct.identifier = "DAQ:Initialise:NoDAQDevicesFound";
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

function obj = CreateChannels(obj, filename)
    % Create DAQ channels from filename.
    if isempty(obj.SessionHandle) || ~isvalid(obj.SessionHandle)
        %create a default DAQ session to attach channels to
        obj.Clear();
        obj = obj.Configure();
    end
    tab = readtable(filename);
    s = size(tab);
    if ~isMATLABReleaseOlderThan("R2024b")
        channelList = daqchannellist;
    end
    for ii = 1:s(1)
        try
            warning('');
            line = tab(ii, :); %TODO CHECK FOR BLANKS
            % line.("deviceID") or line.(1);
            deviceID = line.("deviceID"){1};
            portNum = line.("portNum"){1}; 
            channelName = line.("channelName"){1};
            if isempty(channelName)
                channelName = line.("Note"){1};
            end
            ioType = line.("ioType"){1};
            signalType = line.("signalType"){1};
            terminalConfig = line.("TerminalConfig"){1};
            range = line.("Range"){1};
            channelID = line.("ProtocolID"){1};
            if ~isMATLABReleaseOlderThan("R2024b")
                channelList = add(channelList, ioType, deviceID, portNum, signalType, TerminalConfig=terminalConfig, Range=range);
            else
                switch ioType
                    case "input"
                        ch = addinput(obj.SessionHandle,deviceID,portNum,signalType);
                    case "output"
                        ch = addoutput(obj.SessionHandle,deviceID,portNum,signalType);
                    case "bidirectional"
                        ch = addbidirectional(obj.SessionHandle,deviceID,portNum,signalType);
                end
                ch.Name = channelName;
                if ~isempty(terminalConfig) && ~contains(class(ch), "Digital")
                    ch.TerminalConfig = terminalConfig;
                end
                if ~isempty(range) && ~contains(class(ch), "Digital")
                    range = obj.GetRangeFromString(range);
                    ch.Range = range;
                end
                [warnMsg, warnId] = lastwarn;
                if ~isempty(warnMsg)
                    message = ['Warning encountered on line ' char(string(ii))];
                    warning(message);
                end
            end
            obj.ChannelMap.(channelID) =  ch;
        catch exception
            % dbstack
            % keyboard
            message = ['Encountered an error reading channels config file on line ' ...
                    char(string(ii)) ': ' exception.message ' Line skipped.'];
            warning(message);
        end
    end
    if ~isMATLABReleaseOlderThan("R2024b")
        obj.SessionHandle.Channels = channelList;
    end
end

function r = GetRangeFromString(obj, rString)
    % Get range from string. Used for parsing channel params.
    r0 = split(rString);
    r0 = split(r0{1}, '[');
    r0 = r0{2};
    r0 = str2double(r0);
    r1 = split(rString);
    r1 = split(r1{2}, ']');
    r1 = r1{1};
    r1 = str2double(r1);
    r = [r0 r1];
end

function out = FillChannelData(obj, out, chanLen, params, fieldName)
    chIdx = obj.ChannelMap.fieldName.Index;
    if regexpi(fieldName, '(Thermode)')
        % Thermode

    elseif regexpi(fieldName, '((Ana)|(Vib)|(Piezo))')
        % Analog / vibration / piezo
        
    elseif regexpi(fieldName, '(Dig)')
        % Digital
        
    elseif regexpi(fieldname, '((PWM)|(LED))')
        % PWM
        out(:,chIdx) =  pwmStim(chanLen, params, obj.SessionHandle.Rate);
    elseif regexpi(fieldname, '(Cam)')
        % Camera TODO LIGHTS
        framerate = 20; %Hz
        framerate_unitstep = round(obj.SessionHandle.Rate/framerate);
        for jj = 1:round(framerate_unitstep/2)
            out(jj:framerate_unitstep:end, chIdx) = 1;
        end
    else
        % arbitrary stimulus

    end
end

%%TODO!! STARTS HERE
function preloadChannels(obj, p, idxStim)
    % add listener for plotting/saving
    lh = addlistener(obj.SessionHandle,'DataAvailable',@plotData);
    fs = 1000;
    % Aurorasf = 1/52; % (1V per 50mN as per book,20241125 measured as 52mN per 1 V PB)
    tPre = p(idxStim).tPre / 1000;
    tPost = p(idxStim).tPost / 1000;
    fds = fields(p);
    for i = 1:length(fds)
        fieldName = fds{i};
        if contains(['tPre', 'tPost'], fieldName)
            continue
        end
        % if ~contains(obj.)
    end
    

    % prepare DAQ output (TTL TRIGGERS)
    npreQSTtrig = 12;    %matches the number of entries outlined before QST and thermode triggers
    tax = linspace(1/obj.DAQ.Rate,tTotal,tTotal*obj.DAQ.Rate)-tPre;
    % out = zeros(numel(tax),npreQSTtrig+obj.nThermodes+1);	% preallocate with zeros
    out = zeros(numel(tax),npreQSTtrig+obj.nThermodes+2);	% preallocate with zeros
    
    %%%%% SCAN IMAGE TRIGGERS %%%%%
    out(1,1)    = 1;                                    % TTL ScanImage: Acq start
    % stimstart = find(tax>5); stimstart = stimstart(1);
    % out(tPre*obj.DAQ.Rate + (0:2),2)  = 1;                                    % TTL ScanImage: Aux Trig
    out(end-5:end-4,2)    = 1;                                    % TTL ScanImage: Acq end
    out(1,3)    = 1;                                    % TTL ScanImage: Next File
    
    %%%%% BASLER CAMERA TRIGGER %%%%%
    framerate = 20;%20; % Hz - Basler Camera
    framerate_unitstep = round(obj.DAQ.Rate/framerate);
    for jjj = 1:round(framerate_unitstep/2)
        out(jjj:framerate_unitstep:end,4)    = 1;       % TTL Basler: Frame Trigger
        out(jjj:framerate_unitstep:end,5)    = 1;  
    end
    
    %%%%% Excitation Light Trigger %%%%% 
    out(1:end-1,6) = 1;   % BLUE LED
    out(1:end-1,7) = 1;   % GREEN LED (not used, green light is only used to take an image before functional recordings)
    
    %%%%% Auditory Stimulus %%%%% 
    out(1:end-1,8) = 1; % Speaker (NEEDS PARAMETERIZATION)
    
    %%%%% Optical stimulus (for ChR2) %%%%%
    out(1,9) = 1; % Drive blue LED. (NEEDS PARAMETERIZATION)
    
    %%%%% Hamamatsu Camera Trigger %%%%% 
    out(1,10) = 1; %Trigger image acquisition with Hamamatsu. Need to see how to best achieve this.
    
    % LED Stimulus
    out(:,11) = squareStim(tax,ledDur,ledFreq,ledDC,ledDelay)';
    
    % IRLED Illumination %% ADDED 2020.07.20
    out(1:end-1,12) = 1;
    
    %%%%% Vibration Stimulus %%%%% 
    for kk = 1:obj.nThermodes
        if vibDur(kk)>0
            tmp           = (tPre*obj.DAQ.Rate) + (1:vibDur(kk)*obj.DAQ.Rate);
            out(tmp,npreQSTtrig+kk) = 1;
        end
    end
    out(tPre*obj.DAQ.Rate + (0:100),npreQSTtrig+kk+1) = 1;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%% ADD ANALOG OUTPUT GENERATION %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ramp1 = 20;  % original was 15, trying with 2 on 13.12.2024 change 2 on 20250501
    piezostimunitx = -ramp1:ramp1;
    piezostimunity = normpdf(piezostimunitx,0,3);
    piezostimunity = piezostimunity./max(piezostimunity);
    piezohold = ones(1,piezoDur);
    piezostimunity = [piezostimunity(1:ramp1) piezohold piezostimunity(ramp1+1:end)];
    
    piezostim = zeros(size(tax ));
    if piezoStimNum>0
        for pp = 1:piezoStimNum
            pos1 = (pp-1) .*(1/piezoFreq) ; % in seconds
            tloc = find(tax>=pos1); tloc = tloc(1);
            piezostim(tloc:tloc+numel(piezostimunity)-1) = piezostim(tloc:tloc+numel(piezostimunity)-1)+piezostimunity;
        end
        piezostim = piezostim.*piezoAmp;
    else
       piezostim = zeros(size(tax )); 
    end
    
    out(:,npreQSTtrig+kk+2) = piezostim;
    
    
    
    
    
    obj.DAQ.queueOutputData(out)            % queue data
    prepare(obj.DAQ)                        % prepare data acquisition
    
    % wait for thermodes to reach neutral temperature
    obj.waitForNeutral
    
    % open output file (if filename provided)
    if nargin > 1
        output  = true;
        fid1    = fopen(fnOut,'w');
    else
        output  = false;
    end
    
    % run stimulation
    startBackground(obj.DAQ);               % start data acquisition
    try
        wait(obj.DAQ,tTotal+1)          	% wait for data acquisition
    catch me
        warning(me.identifier,'%s',...      % rethrow timeout error as warning
            me.message); 
    end
    
    % close output file
    if output
        fclose(fid1);
    end
    
    % delete listener
    delete(lh);
end


function plotData(~,event)
    
    % manage persistent variables
    persistent nTherm idTherm idxData
    if isempty(nTherm)
        nTherm = obj.nThermodes;
    end
    if isempty(idxData)
        idxData = 1:(4*nTherm);
    end
    if isempty(idTherm)
        idTherm = arrayfun(@(x) {['Thermode' char(64+x)]},1:nTherm);
    end
    
    % build indices for plotting
    a   = event.Source.NotifyWhenDataAvailableExceeds;
    b   = event.Source.ScansAcquired;
    idx = (1:a)+(b-a);
    
    % scale data from thermodes
    dat = event.Data;
    % dat(:,idxData(1:2)) = dat(:,idxData(1:2)) * 17.0898 - 5.0176;
    dat(:,idxData(1:2)) = dat(:,idxData(1:2)) * 12  - 2; % PB 20241219
    dat(:,idxData(3:4)) = (dat(:,idxData(3:4))*10 + 32) ;
    ylim([12 50])
    
    % plot data
    for ii = 1:5
        for jj = 1:nTherm
            obj.h.(idTherm{jj}).plot(ii).YData(idx) = dat(:,ii+(jj-1)*5);
        end
    end
    
    % save to disk (optional)
    if output
        fwrite(fid1,[event.TimeStamps-tPre,dat,out(idx,:)]','double');
    end
end

%TODO!! ENDS HERE
end
end