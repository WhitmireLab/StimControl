classdef (HandleCompatible) DAQInterface < HardwareComponent
    properties
        Name
        SessionHandle
        Required
    end

    methods
        function obj = DAQInterface(varargin)
            % https://au.mathworks.com/help/matlab/ref/inputparser.html
            p = inputParser;
            addParameter(p, 'Required', false, @isboolean);
            addParameter(p, 'ChannelConfig', '', @isstring);
            addParameter(p, 'DaqConfig','', @isstring);
            addParameter(p, 'ConfigFolder', '', @isstring);
            parse(p, varargin{:});
            params = p.Results;

            obj.Required = params.Required;
            Initialise(obj, 'ChannelConfig', params.ChannelConfig, ...
                'DaqConfig', params.DaqConfig, 'ConfigFolder', params.ConfigFolder);
        end

        % Initialise device
        function Initialise(obj, varargin)
            disp('Creating DAQ session ...')
            
            p = inputParser;
            addParameter(p, 'ChannelConfig', '', @isstring);
            addParameter(p, 'DaqConfig','', @isstring);
            addParameter(p, 'ConfigFolder', '', @isstring);
            parse(p, varargin{:});
            params = p.Results;
            
            if ~isempty(params.ConfigFolder)
                obj.LoadParams(params.ConfigFolder);
            else
                obj.ConfigureDAQ(params.DaqConfig);
                if ~isempty(params.ChannelConfig)
                    obj.LoadParams(params.ChannelConfig);
                else
                    obj.InitialiseChannelsDefault(1);
                end
            end
            
            disp(' ')
            disp(obj.SessionHandle.Channels)
            disp(' ')
        end

        % Close device
        function Close(obj)

        end
        
        % Start device
        function StartSession(obj)
            start(obj.SessionHandle);
        end

        %Stop device
        function StopSession(obj)
            stop(obj.SessionHandle);
        end

        % Change device parameters
        function SetParams(obj, varargin)
            
        end

        % get current device parameters for saving
        function SaveParams(obj, folderpath, identifier)
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
            daqData = {'VendorID' 'Model' 'DeviceID' 'Rate'};
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
            daqData{2,:} = {d.Vendor.ID d.Model d.ID obj.SessionHandle.Rate};

            if ~isempty(identifier)
                writecell(channelData, [folderpath filesep identifier '_DaqChanParams.csv']);
                writecell(daqData, [folderpath filesep identifier '_DaqParams.csv']);
            else
                % write to config folder
                writecell(channelData, [folderpath filesep 'DaqChanParams.csv']);
                writecell(daqData, [folderpath filesep 'DaqParams.csv']);
            end
        end
        
        % Gets output since last queried
        function result = GetOutput(obj)
            
        end
        
        % Gets all output since session started
        function result = GetSessionOutput(obj)
            
        end
        
        % load in a saved set of parameters
        function LoadParams(obj, folderpath)
            if contains(folderpath, "ChanParams")
                app.CreateChannels(folderpath);
            elseif contains(folderpath, "DaqParams")
                app.ConfigureDAQ(folderpath);
            else
                % assume a folder with both params in it.
                try
                    app.ConfigureDAQ([folderpath filesep "DaqParams.csv"]);
                catch exception
                    if obj.Required
                        throw(exception);
                    else
                        warning("Unable to load DAQ params.");
                    end
                end
                try
                    app.CreateChannels([folderpath filesep "DaqChanParams.csv"]);
                catch exception
                    if obj.Required
                        throw(exception);
                    else
                        warning("Unable to load DAQ channel params.");
                    end
                end
            end
        end

        % Print device information
        function PrintInfo(obj)
            disp(obj.SessionHandle.Channels);
        end

        function ClearAll(obj)
            if obj.SessionHandle.Running
                obj.StopSession();
            end
            obj.Close();
            daqreset;
        end

        function LoadProtocol(obj, filename)
            
        end

        %%% PRIVATE FUNCTIONS %%%

        function deviceID = FindDaq(obj, deviceID, vendorID, model)
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
                    ioType = line.("ioType"){1};
                    signalType = line.("signalType"){1};
                    terminalConfig = line.("TerminalConfig"){1};
                    range = line.("Range"){1};
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
                catch exception
                    % dbstack
                    % keyboard
                    message = ['Encountered an error reading channels config file on line ' ...
                            char(string(ii)) ': \n' exception.message '\n' ...
                             'Line skipped.'];
                    warning(message);
                end
            end
            if ~isMATLABReleaseOlderThan("R2024b")
                obj.SessionHandle.Channels = channelList;
            end
        end

        function obj = ConfigureDAQ(obj, filename)
            if isempty(filename)
                disp("No DAQ config file provided. Using default DAQ settings");
                name = FindDaq("Dev1", '', '');
                obj.SessionHandle = daq(name);
                return
            end
            tab = readtable(filename);
            s = size(tab);
            if s(1) > 1
                warning("Currently only one DAQ session at a time is supported. " + ...
                    "only the first DAQ in the config file will be used.") %TODO FIX THIS
            else
                line = tab(ii, :);
                % line.("deviceID") or line.(1);
                vendorID = line.("VendorID"){1};
                model = line.("Model"){1};
                deviceID = line.("DeviceID"){1};
                rate = str2double(line.("Rate"){1});
                daqName = obj.FindDaq(deviceID, vendorID, model);
                d = daq(daqName);
                d.Rate = rate;
                % for ii = 1:s(1)
                % 
                % end
                obj.SessionHandle = d;
            end
        end

        function obj = InitialiseChannelsDefault(obj, nThermodes)
            % Analog Input: Thermode Surfaces
            for ii = 1:nThermodes
                id  = char(64+ii);
                % manually edited to take away the 2nd QST probe options
                % ch  = obj.DAQ.addAnalogInputChannel('Dev1',(1:5)+(8*(ii-1)),'Voltage');
                ch  = obj.SessionHandle.addAnalogInputChannel('Dev1',(1:2),'Voltage');
                tmp = arrayfun(@(x) {['Surface ' id num2str(x)]},1:5);
                [ch.Name] = tmp{:};
                set(ch,...
                    'TerminalConfig',   'SingleEnded', ...
                    'Range',            [-5 5]);    
            end
            
            % Analog Input: Aurora Force OUT
            ch = obj.SessionHandle.addAnalogInputChannel('Dev1',3,'Voltage');
            set(ch,...
                'Name',             'Aurora Force OUT', ...
                'TerminalConfig',   'SingleEnded')
            
            % Analog Input: Aurora Length OUT
            ch = obj.SessionHandle.addAnalogInputChannel('Dev1',4,'Voltage');
            set(ch,...
                'Name',             'Aurora Length OUT', ...
                'TerminalConfig',   'SingleEnded')
            
            % Analog Input: DC Temperature Controller
            ch = obj.SessionHandle.addAnalogInputChannel('Dev1',0,'Voltage');
            set(ch,...
                'Name',             'DC Temperature Controller', ...
                'TerminalConfig',   'SingleEnded')
            
            % TTL Input: Stimulus Onset
            for ii = 1:nThermodes
                id = char(64+ii);
                ch = obj.SessionHandle.addDigitalChannel('Dev1',['port0/line' num2str(ii)],'InputOnly');
                ch.Name = ['TTL Thermode ' id ': Onset'];
            end
            
            % TTL Input: Galvo
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line20:21','InputOnly');
            ch(1).Name = 'TTL ScanImage: Res Galvo';
            ch(2).Name = 'TTL ScanImage: Y Galvo';
            
            % TTL Output: ScanImage
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line3','OutputOnly'); %gunk in board. had to change channels
            % ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line17:21','OutputOnly');
            ch(1).Name = 'TTL ScanImage: Acq Start';
            
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line5:6','OutputOnly');
            ch(1).Name = 'TTL ScanImage: Acq Stop';
            ch(2).Name = 'TTL ScanImage: Next File';
            
            % TTL Output: Widefield Imaging (Basler) %%CJW EDIT 2023.04.04
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line4','OutputOnly');
            ch(1).Name = 'TTL Basler: Frame Trigger';
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line23','OutputOnly');
            ch(1).Name = 'TTL Basler: UNUSED';
            
            % % TTL Output: Widefield Imaging (Basler) %%CJW ADD 2018.11.06
            % ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line22:23','OutputOnly');
            % ch(1).Name = 'TTL Basler: Frame Trigger';
            % ch(2).Name = 'TTL Basler: UNUSED';
            
            % TTL Output: LED Control %%CJW ADD 2018.11.07 %% CJW and PB changed on 2025.05.01
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line0','OutputOnly');
            % ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line24','OutputOnly');
            ch.Name = 'BLUE LED';
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line25','OutputOnly');
            ch.Name = 'GREEN LED';
            
            % TTL Output: Auditory Stimulus %%CJW ADD 2019.06.05
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line26','OutputOnly');
            ch(1).Name = 'Speaker';
            
            % TTL Output: Optical Stimulus (LED) %%CJW ADD 2019.06.05
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line27','OutputOnly');
            ch(1).Name = 'Optical Stimulus';
            
            % TTL Output: Hamamatsu Camera Drive %%CJW ADD 2019.06.05
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line28','OutputOnly');
            ch(1).Name = 'HamamatsuTrigger';
            
            % TTL Output: LED
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line29','OutputOnly');
            ch(1).Name = 'LED';
            
            % TTL Output: IR LED
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line30','OutputOnly');
            ch(1).Name = 'IRLED_BaslerImaging';
            
            
            % Digital Output: Vibration Motors
            for ii = 1:obj.nThermodes
                id = char(64+ii);
                ch = obj.SessionHandle.addDigitalChannel('Dev1',['port0/line' num2str(ii+1)],'OutputOnly');
                ch.Name = ['Vibration ' id];
            end
            
            % Digital Output: Thermode Trigger
            ch = obj.SessionHandle.addDigitalChannel('Dev1','port0/line7','OutputOnly');
            ch(1).Name = 'Thermode Trigger';
            
            % Analog Output: Piezo Driver %added 2022.03.18. edited port 2022.04.12
                        ch = obj.SessionHandle.addAnalogOutputChannel('Dev1',0,'Voltage');
                        set(ch,...
                            'Name',             'Aurora Force Command Voltage', ...
                            'TerminalConfig',   'SingleEnded', ...
                            'Range',            [0 10]);
        end
        % TODO function that only enables certain outputs without requiring
        % a full setup of params?

        function r = GetRangeFromString(obj, range)
            r0 = split(range);
            r0 = split(r0{1}, '[');
            r0 = r0{2};
            r0 = str2double(r0);
            r1 = split(range);
            r1 = split(r1{1}, ']');
            r1 = r1{2};
            r1 = str2double(r1);
            r = [r0 r1];
        end
    end
end