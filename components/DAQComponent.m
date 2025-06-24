classdef (HandleCompatible) DAQComponent < HardwareComponent
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name
        SessionHandle
        Required
        SessionInfo = struct();
        ChannelMap = struct();
        ChannelIdentifiers = struct();
        SavePath
    end

    methods
        function obj = DAQComponent(varargin)
            p = inputParser;
            strValidate = @(x) ischar(x) || isstring(x);
            daqValidate = @(x) (contains(class(x), 'daq.interfaces.DataAcquisition')) || isempty(x);
            addParameter(p, 'Required', true, @islogical);
            addParameter(p, 'ChannelConfig', '', strValidate);
            addParameter(p, 'Handle', [], daqValidate);
            addParameter(p, 'Struct', []);
            addParameter(p, 'SavePath', strValidate);
            parse(p, varargin{:});
            params = p.Results;
            
            obj.SavePath = params.SavePath;
            obj.Required = params.Required;
            obj.SessionHandle = params.Handle;
            obj = obj.Configure('ChannelConfig', params.ChannelConfig, ...
                'Struct', params.Struct);
        end

        % Initialise device
        function obj = Configure(obj, varargin)
            %TODO STOP/START
            strValidate = @(x) ischar(x) || isstring(x);
            p = inputParser;
            addParameter(p, 'ChannelConfig', '', strValidate);
            addParameter(p, 'Struct', []);
            parse(p, varargin{:});
            params = p.Results;

            %---device---
            if isempty(obj.SessionHandle) || ~isempty(params.Struct)
                % if the DAQ is uninitialised or the params have changed
                if isempty(params.Struct)
                    warning("No DAQ config provided. Using default DAQ settings");
                    daqStruct = getDefaultComponentStruct("daq");
                    name = obj.FindDaqName(daqStruct.ID, '', '');
                else
                    vendorID = params.Struct.Vendor;
                    deviceID = params.Struct.ID;
                    model = params.Struct.Model;
                    rate = params.Struct.Rate;
                    name = obj.FindDaqName(deviceID, vendorID, model);
                end
                obj.SessionHandle = daq(name);
                obj.SessionHandle.Rate = rate;
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

        % get current device parameters for saving
        function [daqStruct, channelData] = GetParams(obj)
            % save channels
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
            
            % save daq
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
            % daqData{2,:} = {d.Vendor.ID d.Model d.ID obj.SessionHandle.Rate};
            

            % if ~isempty(identifier)
            %     writecell(channelData, [folderpath filesep identifier '_DaqChanParams.csv']);
            %     writecell(daqData, [folderpath filesep identifier '_DaqParams.csv']);
            % else
            %     % write to config folder
            %     writecell(channelData, [folderpath filesep 'DaqChanParams.csv']);
            %     writecell(daqData, [folderpath filesep 'DaqParams.csv']);
            % end
        end
        
        % Gets output since last queried
        function result = GetOutput(obj)
            
        end
        
        % Gets all output since session started
        function result = GetSessionOutput(obj)
            
        end
        
        % load in a saved set of parameters
        function obj = LoadParams(obj, folderpath)
            if contains(folderpath, "ChanParams")
                obj = obj.CreateChannels(folderpath);
            elseif contains(folderpath, "DaqParams")
                obj = obj.ConfigureDAQ(folderpath);
            else
                % assume a folder with both params in it.
                try
                    obj = obj.ConfigureDAQ([folderpath filesep "DaqParams.csv"]);
                catch exception
                    if obj.Required
                        throw(exception);
                    else
                        warning(['Unable to load DAQ params: ' folderpath]);
                    end
                end
                try
                    obj = obj.CreateChannels([folderpath filesep "DaqChanParams.csv"]);
                catch exception
                    if obj.Required
                        throw(exception);
                    else
                        warning(['Unable to load DAQ channel params: ' folderpath]);
                    end
                end
            end
        end

        % Print device information
        function PrintInfo(obj)
            disp(' ');
            disp(obj.SessionHandle.Channels);
            disp(' ');
        end

        % Kill the whole thing
        function Clear(obj)
            if obj.SessionHandle.Running
                obj.Stop();
            end
            daqreset;
        end
        
        % Dynamic visualisation of object output
        function VisualiseOutput(obj, varargin)
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
            addParameter(parser, 'nThermodes', 1, intValidate);
            parse(parser, varargin{:});

            obj.SessionInfo.idxStim = parser.Results.idxStim;
            obj.SessionInfo.nThermodes = parser.Results.nThermodes; %TODO DEFAULT THERMODES BASED ON CHANNELS WITH THERMAL LABEL???
            if ~isempty(parser.Results.filepath)
                [p, g] = readParameters(parser.Results.filepath);
            else
                p = parser.Results.p;
                g = parser.Results.g;
            end
            obj.SessionInfo.p = p;
            obj.SessionInfo.g = g;

            obj.LoadTrial('idxStim', parser.Results.idxStim);
        end
        
        % Preload a trial
        function LoadTrial(obj, varargin)
            parser = inputParser;
            stringValidate = @(x) ischar(x) || isstring(x);
            intValidate = @(x) ~isinf(x) && floor(x) == x;
            addParameter(parser, 'idxStim', 1, intValidate);
            addParameter(parser, 'filepath', '', stringValidate);
            addParameter(parser, 'p', '', @isstruct);
            addParameter(parser, 'g','', @isstruct);
            addParameter(parser, 'h', '', @isstruct);
            addParameter(parser, 'nThermodes', 1, intValidate);
            addParameter(parser, 'oneOff', false, @islogical);
            parse(parser, varargin{:});
            idxStim = parser.Results.idxStim;
            nThermodes = parser.Results.nThermodes;
            if ~isempty(parser.Results.filepath)
                [p, g] = readParameters(parser.Results.filepath);
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
            
            IDtherm = arrayfun(@(x) {['Thermode' char(64+x)]},1:nThermodes);
            if isempty(p) || parser.Results.oneOff
                % single stimulation: use default values for tPre (time before onset of
                % stimulus) and tPost (time after onset of stimulus). Obtain duration
                % of vibration from respective GUI fields.
                tPre	 = 1;
                tPost 	 = 2;
                vibDur   = cellfun(@(x) obj.h.(x).edit.vibDur.Value,IDtherm) / 1000;
                ledDur   = h.LED.edit.ledDur.Value / 1000;
                ledFreq  = h.LED.edit.ledFreq.Value;
                ledDC    = h.LED.edit.ledDC.Value;
                ledDelay = h.LED.edit.ledDelay.Value / 1000;
                piezoAmp = 0;
                piezoFreq= 0;
                piezoDur = 0;
                piezoStimNum = 0;
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
            tTotal  = tPre + tPost;

            for i = 1:length(channels)
                switch channels(i).Name
                    %NB this is from stimulate.m 
                    
                end
            end
        end

        %%% PRIVATE FUNCTIONS %%%

        function name = FindDaqName(obj, deviceID, vendorID, model)
            % https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.html
            try
                daqs = daqlist().DeviceInfo;
            catch
                daqs = [];
            end
            if isempty(daqs)
                if obj.Required
                    errorStruct.message = "No data acquistion devices found or data acquisition toolbox missing.";
                    errorStruct.identifier = "DAQ:Initialise:NoDAQDevicesFound";
                    error(errorStruct);
                else
                    warning("DAQInterface: No data acquistion devices found or data acquisition toolbox missing.");
                end
                obj.SessionHandle = [];
                return
            end
            checker = false;
            for x = 1 : length(daqs)
                if (strcmpi(daqs(x).ID, deviceID) ...
                        && isempty(vendorID) && isempty(model)) ||  ... %if only DAQ name is given
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
            if isempty(obj.SessionHandle)
                %create a default DAQ session to attach channels to
                obj = obj.ConfigureDAQ('');
            end
            tab = readtable(filename);
            s = size(tab);
            if ~isMATLABReleaseOlderThan("R2024b")
                channelList = daqchannellist;
            end
            for ii = 1:s(1)
                try
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
                    channelID = line.(""){1};
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
                    end
                    set(obj.ChannelIdentifiers, channelID, ch);
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

        %%TODO!! STARTS HERE
        function preloadChannels(obj, name)

            % add listener for plotting/saving -- see function plotData() below
            lh = addlistener(obj.DAQ,'DataAvailable',@plotData);
            
            fs = 1000;
            Aurorasf = 1/52; % (1V per 50mN as per book,20241125 measured as 52mN per 1 V PB)
            
            
            IDtherm = arrayfun(@(x) {['Thermode' char(64+x)]},1:obj.nThermodes);
            if isempty(obj.p)
                % single stimulation: use default values for tPre (time before onset of
                % stimulus) and tPost (time after onset of stimulus). Obtain duration
                % of vibration from respective GUI fields.
                tPre	 = 1;
                tPost 	 = 2;
                vibDur   = cellfun(@(x) obj.h.(x).edit.vibDur.Value,IDtherm) / 1000;
                ledDur   = obj.h.LED.edit.ledDur.Value / 1000;
                ledFreq  = obj.h.LED.edit.ledFreq.Value;
                ledDC    = obj.h.LED.edit.ledDC.Value;
                ledDelay = obj.h.LED.edit.ledDelay.Value / 1000;
                piezoAmp = 0;
                piezoFreq= 0;
                piezoDur = 0;
                piezoStimNum = 0;
            else
                % protocol run: use values from protocol structure
                tPre     = obj.p(obj.idxStim).tPre  / 1000;
                tPost    = obj.p(obj.idxStim).tPost / 1000;
                vibDur   = cellfun(@(x) obj.p(obj.idxStim).(x).VibrationDuration,IDtherm) / 1000;
                ledDur   = obj.p(obj.idxStim).ledDuration / 1000;
                ledFreq  = obj.p(obj.idxStim).ledFrequency;
                ledDC    = obj.p(obj.idxStim).ledDutyCycle;
                ledDelay = obj.p(obj.idxStim).ledDelay / 1000;
                piezoAmp = obj.p(obj.idxStim).piezoAmp * Aurorasf; piezoAmp = min([piezoAmp 9.5]);  %added a safety block here 2024.11.15
                piezoFreq = obj.p(obj.idxStim).piezoFreq;
                piezoDur = obj.p(obj.idxStim).piezoDur;
                piezoStimNum= obj.p(obj.idxStim).piezoStimNum;
            end
            tTotal  = tPre + tPost;
                
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
end