function callbackLoadConfig(obj, src, event)
% Generic function for loading config files from various dropdowns in StimControl's Setup tab.
value = src.Value;
if strcmpi(src.Value, 'Auto')
    return
end

if src == obj.h.SessionSelectDropDown
    basePath = obj.path.sessionBase;
elseif src == obj.h.ComponentConfigDropDown
    basePath = obj.path.paramBase;
end

if strcmpi(src.Value, 'Browse...')
    % let the user select a file
    [file, location] = uigetfile([basePath filesep '*.json']);
    filepath = [location file];
    if isempty(filepath) || ~any(filepath)
        return
    end
else
    filepath = [basePath filesep src.Value];
end
    
if src == obj.h.SessionSelectDropDown
    obj = LoadSessionConfig(obj, filepath);
elseif src == obj.h.ComponentConfigDropDown
    obj = LoadComponentConfig(obj, filepath);
elseif src == obj.h.ComponentMapDropDown
    obj = MapComponents(obj, filepath);
end
end

%% LOAD COMPONENT CONFIG
function obj = LoadComponentConfig(obj, filepath)
    obj.indicateLoading("Loading Component Config...");
    if isempty(filepath) || ~any(filepath)
        return
    end
    jsonStr = fileread(filepath);
    jsonData = jsondecode(jsonStr);
    componentIDs = obj.d.componentIDs;
    for i = 1:length(jsonData)
        if length(jsonData) > 1
            hStruct = jsonData{i};
        else
            hStruct = jsonData;
        end
        if any(contains(componentIDs, hStruct.ComponentID))
            componentIdx = obj.d.cIdx(hStruct.ComponentID);
            component = obj.d.Available{componentIdx};
            Previewing = hStruct.Previewing;
            
            % activate or deactivate component if required
            if hStruct.Active ~= obj.h.AvailableHardwareTable.Data(componentIdx,:).Enable
                event = struct('Indices', [componentIdx, 5], ...
                    'NewData', hStruct.Active, ...
                    'PreviousData', obj.h.AvailableHardwareTable.Data(componentIdx,:).Enable);
                obj.h.AvailableHardwareTable.CellEditCallback(obj.h.AvailableHardwareTable, event);
            end
            if class(component) ~= hStruct.type
                obj.warnMsg(sprintf("Component %s not configured: type mismatch", hStruct.ComponentID));
                continue
            end

            % sanitise params struct and set params.
            hStruct = rmfield(hStruct, {'type', 'Previewing', 'Active'});
            component.SetParams(hStruct);
            
            % start preview
            if Previewing
                component.StartPreview;
            end
        else
            obj.warnMsg(sprintf("Component not found: %s", hStruct.ComponentID));
        end
    end
    obj.status = obj.status;
end

%% LOAD SESSION CONFIG
function obj = LoadSessionConfig(obj, filepath)
    txt = fileread(filepath);
    data = jsondecode(txt);
    obj = loadSessionHelper(obj, data, 'componentParams', obj.path.paramBase, @LoadComponentConfig);
    obj = loadSessionHelper(obj, data, 'activeHardware', '', '');
    obj = loadSessionHelper(obj, data, 'protocol', obj.path.sessionBase, '');
    
    %update availableHardwareTable
    if isfield(data, 'hardwareTableData')
        fs = fields(data.hardwareTableData);
        lineIds = {obj.h.AvailableHardwareTable.Data.('Protocol ID')};
        for i = 1:length(fs)
            lineIdx = cellfun(@(x)strcmpi(x, fs{i}), lineIds, 'UniformOutput', false);
            lineIdx = find(lineIdx{:});
            if isempty(lineIdx)
                % device not initialised in this session
                continue
            end
            line = obj.h.AvailableHardwareTable.Data(lineIdx,:);
            params = fields(data.hardwareTableData.(fs{i}));
            for pi = 1:length(params)
                param = params{pi};
                paramIdx = cellfun(@(x)strcmpi(x, param), line.Properties.VariableNames, 'UniformOutput', false);
                paramIdx = find([paramIdx{:}]);
                src = obj.h.AvailableHardwareTable;
                event = struct( ...
                    'Indices', [lineIdx paramIdx], ...
                    'PreviousData', line.(param), ...
                    'NewData', data.hardwareTableData.(fs{i}).(param));
                try
                    obj.h.AvailableHardwareTable.Data(lineIdx, paramIdx) = {data.hardwareTableData.(fs{i}).(param)};
                    obj.callbackUpdateComponentTable(src, event);
                catch err
                    obj.errorMsg("Unable to load saved session. Likely the automatically generated grid size is not compatible with" + ...
                        "saved parameters. Change the parameters manually, save the session, and try again.");
                end
            end
        end
    end
end

function obj = loadSessionHelper(obj, data, fieldName, defaultPath, fcnHandle)
    if ~isfield(data, fieldName) || all(strcmpi(data.(fieldName), 'none')) || all(strcmpi(data.(fieldName), ''))
        return
    end
    if strcmpi(fieldName, 'activeHardware')
        if length(data.activeHardware) == 1 && strcmpi(data.activeHardware{1}, 'all')
            obj.errorMsg("'All' as a value for active hardware in session param files is not currently implemented. Please list all hardware.");
        end
        obj.d.ActiveIDs = data.activeHardware;
    else
        if contains(data.(fieldName), filesep)
            filepath = data.(fieldName);
        else
            filepath = [defaultPath filesep data.(fieldName)];
        end
    
        if strcmpi(fieldName, 'protocol')
            %TODO UNTESTED
            obj.callbackLoadProtocol(obj.h.SessionSelectDropDown, filepath);
        else
            obj = fcnHandle(obj, filepath);
        end
    end
end