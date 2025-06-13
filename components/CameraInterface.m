classdef (HandleCompatible) CameraInterface < HardwareComponent
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Name
        SessionHandle
        Required
        SessionInfo = struct();
    end

    methods
        function obj = CameraInterface(varargin)
            % https://au.mathworks.com/help/matlab/ref/inputparser.html
            p = inputParser;
            strValidate = @(x) ischar(x) || isstring(x);
            handleValidate = @(x) (contains(class(x), 'daq.interfaces.DataAcquisition')) || isempty(x);
            addParameter(p, 'Required', false, @islogical);
            addParameter(p, 'Config', '', strValidate);
            addParameter(p, 'ConfigFolder', '', strValidate);
            addParameter(p, 'Handle', [], handleValidate);
            addParameter(p, 'Struct', []);
            parse(p, varargin{:});
            params = p.Results;

            obj.Required = params.Required;
            obj.SessionHandle = params.Handle;
            obj = obj.Initialise('Config', params.Config, ...
                'ConfigFolder', params.ConfigFolder, 'Struct', params.Struct);
        end

        % Initialise device
        function Initialise(obj, varargin)
            strValidate = @(x) ischar(x) || isstring(x);
            p = inputParser;
            addParameter(p, 'Config', '', strValidate);
            addParameter(p, 'ConfigFolder', '', strValidate);
            addParameter(p, 'Struct', []);
            parse(p, varargin{:});
            params = p.Results;

            if (~isempty(params.Config) || ~isempty(params.ConfigFolder)) && ~isempty(params.Struct)
                warning("Camera should be configured via either a config filepath or a struct. " + ...
                    "Defaulting to struct config.");
            end
            
            if ~isempty(params.Struct)
                obj = obj.ConfigureDAQ('struct', params.Struct);
            elseif ~isempty(params.ConfigFolder)
                obj = obj.LoadParams(params.ConfigFolder);
            else
                obj = obj.ConfigureDAQ(params.DaqConfig);
            end
            if ~isempty(obj.SessionHandle.Channels)
                disp(' ')
                disp(obj.SessionHandle.Channels)
                disp(' ')
            end
        end

        % Close device
        function Close(obj)

        end
        
        % Start device
        function StartSession(obj)

        end

        %Stop device
        function StopSession(obj)

        end

        % Change device parameters
        function SetParams(obj, varargin)

        end

        % get current device parameters for saving
        function [objStruct, channelData] = GetParams(obj)

        end
        
        % Gets output since last queried
        function result = GetOutput(obj)

        end
        
        % Gets all output since session started
        function result = GetSessionOutput(obj)

        end
        
        % load in a saved set of parameters
        function LoadParams(obj, filename)

        end

        % Print device information
        function PrintInfo(obj)

        end

        function ClearAll(obj)

        end
    end
end