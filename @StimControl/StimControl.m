classdef StimControl < handle
    
    properties (SetAccess = private)
        DAQ                         % DAQ Session
        serialPorts                 % serial port objects
        cameras                     % camera objects
    end
    
    properties %(Access = private)
        h           = []            % GUI handles
        p           = []            % stimulation parameters/protocol
        g           = []            % general protocol parameters
        idxStim     = []            % current stimulus index
        t                           % timer
        chAI
        chD
        cmdStack    = []
        name        = 'StimControl'
        pFile       = []
        dirData     = fullfile(getenv('UserProfile'),'Desktop','logs');
        isRunning   = false;
    end
    
    properties (Dependent)
        dirAnimal
        animalID
        nThermodes
   end
    
    methods
        function obj = StimControl(varargin)
            close all
            daqreset
            addpath(pwd)
            addpath(genpath(fullfile(pwd,'components')))
            clc
            disp('Welcome to StimControl')
            
            %% Create data directory
            if ~exist(obj.dirData,'dir')
                mkdir(obj.dirData)
            end

            %% Create figure and get things going
            createFigure(obj)
            
            %% battery timer
            obj.t = timer(...
                'StartDelay',       0, ...
                'Period',           300, ...
                'ExecutionMode',    'fixedRate', ...
                'StartFcn',         @obj.callbackTimer, ...
                'TimerFcn',         @obj.callbackTimer);
            start(obj.t)
            
            obj.p2GUI;
            obj.checkSync
        end
    end
    
    methods (Access = private)
        
        createFigure(obj)
        createPanelAnimal(obj,hPanel,~)
        createPanelProtocol(obj,hPanel,~)
        createPanelSingleRun(obj,hPanel,~)
        createPanelLED(obj,hPanel,~)
        createPanelThermode(obj,hPanel,~,idxThermode,nThermodes)
        createPlotThermode(obj,hAx)
        createPlotLED(obj,hAx)
        createDAQchannels(obj)
        
        callbackInitialise(obj)
        callbackFileOpen(obj,~,~)
        callbackFileClose(obj,hClose,~)
        callbackFileExit(obj,~,~)
        
        callbackDebugKB(obj,~,~)
        callbackDebugCB(obj,~,~)
        callbackDebugDelEmpty(obj,~,~)
        
        callbackThermodeToggle(obj,hEdit,src)
        callbackThermodeEdit(obj,hEdit,src)
        callbackThermodeSync(obj,hCheck,~)
        callbackThermodeITerm(obj,hCheck,~)
        
        callbackLEDEdit(obj,hEdit,src)
        
        callbackTimer(obj,~,~)
        
        callbackAnimalAdd(obj,hCtrl,~)
        updateAnimals(obj)
        
        callbackSingleRunStart(obj,hCtrl,~)
        
        callbackProtocolNstim(obj,hCtrl,src)
        callbackProtocolStart(obj,~,~)
        callbackProtocolStop(obj,~,~)
        
        enableThermodeEdit(obj,bool)
        p2serial(obj,p)
        p2GUI(obj)
        setAxesPadding(~,hax,padding)
        checkSync(obj)
        waitForNeutral(obj)
        setTitle(obj,string)
        stimulate(obj,filename)
        out = estimateTime(obj)
    end
    
    methods
        function out = get.dirAnimal(obj)
            out = fullfile(obj.dirData,obj.animalID);
        end
        
        function out = get.animalID(obj)
            tmp = obj.h.animal.listbox.id;
            out = tmp.String{tmp.Value};
        end
        
        function out = get.nThermodes(obj)
            out = length(obj.s);
        end
        
        function set.idxStim(obj,value)
            nStim = length(obj.p);
            validateattributes(value,{'numeric'},...
                {'scalar','integer','real','nonnegative','<=',nStim})
            obj.idxStim = value;
            
            obj.h.protocol.edit.nStim.String   = sprintf('%d/%d',value,nStim);
            obj.h.protocol.edit.Comment.String = obj.p(value).Comments;
            obj.h.ThermodeA.edit.vibDur.String = obj.p(value).ThermodeA.VibrationDuration;
            obj.h.ThermodeB.edit.vibDur.String = obj.p(value).ThermodeB.VibrationDuration;
            obj.h.ThermodeA.edit.vibDur.Value  = obj.p(value).ThermodeA.VibrationDuration;
            obj.h.ThermodeB.edit.vibDur.Value  = obj.p(value).ThermodeB.VibrationDuration;
            obj.h.LED.edit.ledDur.String       = obj.p(value).ledDuration;
            obj.h.LED.edit.ledFreq.String      = obj.p(value).ledFrequency;
            obj.h.LED.edit.ledDC.String        = obj.p(value).ledDutyCycle;
            obj.h.LED.edit.ledDelay.String     = obj.p(value).ledDelay;
            obj.h.LED.edit.ledDur.Value        = obj.p(value).ledDuration;
            obj.h.LED.edit.ledFreq.Value       = obj.p(value).ledFrequency;
            obj.h.LED.edit.ledDC.Value         = obj.p(value).ledDutyCycle;
            obj.h.LED.edit.ledDelay.Value      = obj.p(value).ledDelay;
            
            obj.p2serial(obj.p(value));
            obj.p2GUI
        end
    end
end