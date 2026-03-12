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
obj = LoadSessionConfig(obj, filepath);
end

%% LOAD SESSION CONFIG
function obj = LoadSessionConfig(obj, filepath)
    txt = fileread(filepath);
    data = jsondecode(txt);
    obj = loadSessionHelper(obj, data, 'componentParams', obj.path.paramBase, @LoadComponentConfig);
    obj = loadSessionHelper(obj, data, 'activeHardware', '', '');
    obj.indicateLoading("Loading Component Config...");
    obj.d = obj.d.LoadConfig(data.hardwareSettings);

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
    obj.status = obj.status;
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
    end
end

