classdef (Abstract, HandleCompatible) HardwareComponent
    %Abstract class representing all hardware components

    properties (Access = private)
        Name
        SessionHandle
        SavePath
        Required
    end

    methods (Abstract)
        % Initialise device
        Configure(obj, varargin)
        
        % Start device
        Start(obj)

        % Stop device
        Stop(obj)
        
        % Complete reset. Clear device
        Clear(obj)

        % Change device parameters
        SetParams(obj, varargin)

        % get current device parameters for saving
        objStruct = GetParams(obj)
        
        % gets current device status
        % Options: ok / ready / running / error / empty / loading
        status = GetStatus(obj)
        
        % Dynamic visualisation ofthe object output. Can target a specific
        % plot using the "Plot" param.
        VisualiseOutput(obj, varargin)

        % Print device information
        PrintInfo(obj)

        % Preload an experimental protocol
        LoadProtocol(obj, varargin);
    end
end