classdef ComponentManager < handle
properties
    Available
    Active
    ProtocolIDMap
    IDComponentMap

    ActiveIDs
    componentTargets
    trialParams
    trialNum
end

properties(Dependent)
    activeComponents
    nAvailable
    nActive
    protocolIDs
    componentIDs
    targetedComponents
end

methods
    function obj = ComponentManager()
    end

    function obj = FindAvailableHardware(obj)
        %% Find available hardware
        obj.Available = {};
        obj.Active = [];
        obj.IDComponentMap = configureDictionary('string', 'uint32');
        obj.ProtocolIDMap = configureDictionary('string', 'uint32');

        warning('off', 'MATLAB:JavaEDTAutoDelegation'); % suppress auto delegation warnings bc they're annoying
        tmpPlur = ["", "s"];
        pluralStr = @(input) tmpPlur(double(length(input)~=1)+1);
        daqs = DAQComponent.FindAll();
        fprintf("\t Found %d DAQ%s\n", length(daqs), pluralStr(daqs));
        cameras = CameraComponent.FindAll();
        fprintf("\t Found %d camera%s\n", length(cameras), pluralStr(cameras));
        serials = SerialComponent.FindAll();
        fprintf("\t found %d serial device%s\n", length(serials), pluralStr(serials));
        components = [cameras serials daqs]; %daqs on the end because they're activated together too
        warning('off', 'MATLAB:JavaEDTAutoDelegation'); % turn em back on
    
        for ci = 1:length(components)
            comp = components{ci};
            obj.IDComponentMap(comp.ComponentID) = ci;
            obj.ProtocolIDMap(comp.ConfigStruct.ProtocolID) = ci;
            obj.Available{end+1} = comp;
            obj.Active(end+1) = true;
        end
    end

    function obj = LoadConfig(obj, jsonData)
        if isempty(jsonData)
            % no config information
            return
        end
        for i = 1:length(jsonData)
            if length(jsonData) > 1
                if isstruct(jsonData)
                    hStruct = jsonData(i); % matlab does this awesome thing where it converts from cells to structs in text representations (read: json) without telling you sometimes.
                else
                    hStruct = jsonData{i};
                end
            else
                hStruct = jsonData;
            end
            if any(contains(obj.componentIDs, hStruct.ComponentID))
                componentIdx = obj.cIdx(hStruct.ComponentID);
                component = obj.Available{componentIdx};
                Previewing = hStruct.Previewing;
                
                if class(component) ~= hStruct.type
                    warning("Component %s not configured: type mismatch", hStruct.ComponentID);
                    continue
                end

                % sanitise params struct and set params.
                hStruct = rmfield(hStruct, {'type', 'Previewing', 'Active', 'ComponentID'});
                component.SetParams(hStruct);
                
                % start preview
                if Previewing
                    component.StartPreview;
                end
            else
                warning("Component not found: %s (%s)", hStruct.ComponentID, hStruct.ProtocolID);
            end
        end
        % refresh maps
        for ci = 1:length(obj.Available)
            comp = obj.Available{ci};
            obj.IDComponentMap(comp.ComponentID) = ci;
            obj.ProtocolIDMap(comp.ConfigStruct.ProtocolID) = ci;
        end
    end

    function Initialise(obj)
        for i = 1:length(obj.Available)
            if obj.Active{i}
                obj.Available{i}.InitialiseSession();
            end
        end
    end

    function StartPreviews(obj)
        for i = 1:length(obj.Available)
            obj.Available{i}.StartPreview();
        end
    end

    function CloseAll(obj)
        if ~isempty(obj.Available)
            for i = 1:obj.nAvailable
                comp = obj.Available{i};
                comp.Close();
            end
        end
    end

    function ClearAll(obj)
        warning('off', 'MATLAB:JavaEDTAutoDelegation'); % suppress auto delegation warnings bc they're annoying
        obj.CloseAll();
        CameraComponent.ClearAll();
        SerialComponent.ClearAll();
        DAQComponent.ClearAll();
        warning('on', 'MATLAB:JavaEDTAutoDelegation');
    end

    function activeComponents = get.activeComponents(obj)
        activeComponents = obj.Available(obj.Active == 1);
    end

    function componentIDs = get.componentIDs(obj)
        componentIDs = {};
        for i = 1:length(obj.Available)
            comp = obj.Available{i};
            componentIDs{end+1} = comp.ComponentID;
        end
    end

    function protocolIDs = get.protocolIDs(obj)
        protocolIDs = {};
        for i = 1:length(obj.Available)
            comp = obj.Available{i};
            protocolIDs{end+1} = comp.ConfigStruct.ProtocolID;
        end
    end

    function protIdx = pIdx(obj, protocolID)
        protIdx = 0;
        for i = 1:length(obj.Available)
            comp = obj.Available{i};
            if strcmpi(comp.ConfigStruct.ProtocolID, protocolID)
                protIdx = i;
            end
        end
    end

    function componentIdIdx = cIdx(obj, componentID)
        componentIdIdx = 0;
        for i = 1:length(obj.Available)
            comp = obj.Available{i};
            if strcmpi(comp.ComponentID, componentID)
                componentIdIdx = i;
            end
        end
    end

    function out = get.nAvailable(obj)
        out = length(obj.Available);
    end

    function out = get.nActive(obj)
        out = sum(obj.Active);
    end

    function out = get.targetedComponents(obj)
        out = {};
        if isempty(obj.trialParams) || isempty(obj.trialNum)
            return
        end
        out = cellfun(@(x) isfield(obj.trialParams(obj.trialNum) && x.Active, x.ProtocolID), obj.Available);
    end
end
end