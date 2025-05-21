classdef (HandleCompatible) DAQ < HardwareComponent
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Name
        SessionHandle
    end

    methods
        function obj = DAQ(varargin)
            % https://au.mathworks.com/help/matlab/ref/inputparser.html
            p = inputParser;
            addOptional(p, 'name', @isstring);
            addOptional(p, 'params', @isdictionary);

        end

        % Initialise device
        function Initialise(obj, varargin)
            
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
        function SaveParams(obj, folderpath, identifier)

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