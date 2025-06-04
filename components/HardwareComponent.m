classdef (Abstract, HandleCompatible) HardwareComponent
    %Abstract class representing all hardware components

    properties (Access = private)
        Name
        SessionHandle
    end

    methods (Abstract)
        % Initialise device
        Initialise(obj)

        % Close device
        Close(obj)
        
        % Start device
        StartSession(obj)

        % Stop device
        StopSession(obj)
        
        % Complete reset. Clear device
        ClearAll(obj)

        % Change device parameters
        SetParams(obj, varargin)

        % get current device parameters for saving
        SaveParams(obj, folderpath, identifier)
        
        % Gets output since last queried
        result = GetOutput(obj)
        
        % Gets all output since session started
        result = GetSessionOutput(obj)
        
        % load in a saved set of parameters
        LoadParams(obj, filename)

        % Print device information
        PrintInfo(obj)

        % Preload outputs from file
        LoadProtocol(obj, filename);
    end
end