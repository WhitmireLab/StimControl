classdef (Abstract, HandleCompatible) HardwareComponent
    %Abstract class representing all hardware components

    properties (Access = private)
        Name
        Params
        SessionHandle
    end

    methods (Abstract)
        % Initialise device
        Initialise(obj) 

        % Close device
        Close(obj)
        
        % Start device
        StartSession(obj)

        %Stop device
        StopSession(obj)

        % Change device parameters
        SetParams(obj, varargin)

        % get current device parameters for saving
        result = GetSaveableParams(obj)
        
        % Gets output since last queried
        result = GetOutput(obj)
        
        % Gets all output since session started
        result = GetSessionOutput(obj)
        
        % load in a saved set of parameters
        GetParamsFromFile(obj, filename)

        % Print device information
        PrintInfo(obj)
    end
end