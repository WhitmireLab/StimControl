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
    obj.indicateLoading("Loading Component Config...");
    obj.d = obj.d.LoadConfig(data.hardwareSettings);
    
    obj.indicateLoading("Loading Display Settings...");
    % update availableHardwareTable
    if isfield(data, 'hardwareTableData')
        fs = fields(data.hardwareTableData);
        lineIds = {obj.h.AvailableHardwareTable.Data.('ID')};
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
                if (strcmpi(param, 'PRow') && any(str2num(event.NewData) > numel(obj.h.PreviewGrid.RowHeight))) ...
                    || (strcmpi(param, 'PColumn') && any(str2num(event.NewData) > numel(obj.h.PreviewGrid.ColumnWidth)))
                    % don't try to assign to a grid position that doesn't exist.
                    continue
                end
                obj.h.AvailableHardwareTable.Data(lineIdx, paramIdx) = {data.hardwareTableData.(fs{i}).(param)};
                obj.callbackUpdateComponentTable(src, event);
            end
        end
    end
    obj.status = obj.status;
end

