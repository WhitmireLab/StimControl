classdef (HandleCompatible) Component < HardwareComponent
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Name
        SessionHandle
        SavePath
        Required
        Status
    end

    methods
        function obj = Component(varargin)
            % https://au.mathworks.com/help/matlab/ref/inputparser.html
            % https://au.mathworks.com/help/matlab/ref/inputparser.html
            p = inputParser;
            strValidate = @(x) ischar(x) || isstring(x);
            handleValidate = @(x) (contains(class(x), 'daq.interfaces.DataAcquisition')) || isempty(x);
            addParameter(p, 'Required', true, @islogical);
            addParameter(p, 'Handle', [], handleValidate);
            addParameter(p, 'Struct', []);
            addParameter(p, 'SavePath', strValidate);
            parse(p, varargin{:});
            params = p.Results;
            
            obj.SavePath = params.SavePath;
            obj.Required = params.Required;
            obj.SessionHandle = params.Handle;

            obj = obj.Configure('Struct', params.Struct);
        end

        % Configure device
        function Configure(obj, varargin)
            %TODO STOP/START
            strValidate = @(x) ischar(x) || isstring(x);
            p = inputParser;
            addParameter(p, 'ChannelConfig', '', strValidate);
            addParameter(p, 'Struct', []);
            parse(p, varargin{:});
            params = p.Results;

            %---device---
            if isempty(obj.SessionHandle) || ~isempty(params.Struct)
                % if the component is uninitialised or the params have changed
                if isempty(params.Struct)
                    warning("No Component config provided. Using default settings");
                    
                else
                    
                end

                obj.SessionHandle = daq(name);
                obj.SessionHandle.Rate = rate;
            end
            
            %---display---
            if ~isempty(obj.SessionHandle)
                obj.PrintInfo();
            end
            
        end
        
        % Start device
        function Start(obj)

        end

        %Stop device
        function Stop(obj)

        end
        
        % Complete reset. Clear device
        function Clear(obj)

        end

        % Change device parameters
        function SetParams(obj, varargin)

        end

        % get current device parameters for saving
        function objStruct = GetParams(obj)
            
        end
        
        % gets current device status
        function status = GetStatus(obj)
            if obj.Status == "error" || obj.Status == "loading"
                status = obj.Status;
            elseif isempty(obj.SessionHandle)
                status = "empty";
            elseif isrunning(obj.SessionHandle)
                status = "ready";
                if toc(obj.LastAcquisition) > seconds(1)
                    status = "running";
                end
            else
                status = "ok";
            end

        end

        % Dynamic visualisation ofthe object output. Can target a specific
        % plot using the "Plot" param.
        function VisualiseOutput(obj, varargin)
            p = inputParser;
            p.addParameter("Plot", []);
            p.parse(varargin{:});
            target = p.Results.Plot;
            if isempty(obj.SessionHandle)
                return;
            end
        end

        % Print device information
        function PrintInfo(obj)
            disp(' ')
            disp(obj.SessionHandle)
            disp(' ')
        end

        function LoadProtocol(obj, varargin)

        end

    end
end