function callbackSaveConfig(obj, src, event)
    [s, pcInfo] = system('vol');
    pcInfo = strsplit(pcInfo, '\n');
    pcID = pcInfo{2}(end-8:end);
    prompt = {'Enter filename:'};
    dlgtitle = 'Save config';
    if ~strcmpi(obj.h.SessionSelectDropDown.Value, 'Auto')
        tmp = split(obj.h.SessionSelectDropDown.Value, '.');
        defaultInput = tmp{1};
    else
        defaultInput = {[pcID '_default']};
    end
    filename = inputdlg('Enter filename:','Save config',[1 45],cellstr(defaultInput));
    if isempty(filename)
        return
    end
    filename = [filename{:} '.json'];
    % Save session
    pBase = obj.path.sessionBase;
    filepath = [pBase filesep filename];
    if isfile(filepath) % only overwrite relevant settings
        txt = fileread(filepath);
        saveData = jsondecode(txt);
    else
        saveData = [];
    end
    if iscell(obj.path.dirData)
        saveData.dirData = obj.path.dirData{:};
    else
        saveData.dirData = obj.path.dirData;
    end

    if ~isfield(saveData, 'hardwareTableData')
        saveData.hardwareTableData = [];
    end
    if ~isfield(saveData, 'hardwareSettings')
        saveData.hardwareSettings = {};
    end
    for ri = 1:height(obj.h.AvailableHardwareTable.Data)
        line = obj.h.AvailableHardwareTable.Data(ri,:);
        saveData.hardwareTableData.(line.('ID'){:}) = struct( ...
            'ProtocolID', line.('ProtocolID'){:}, ...
            'Enable', line.('Enable'), ...
            'Preview', line.('Preview'), ...
            'PRow', line.('PRow'){:}, ...
            'PColumn', line.('PColumn'){:});
    end
    % Save component params
    componentData = {};
    if ~isempty(saveData.hardwareSettings)
        if isstruct(saveData.hardwareSettings) % if you're only saving one kind of object matlab loads it as a struct, not a cell. Hrgh.
            saveData.hardwareSettings = num2cell(saveData.hardwareSettings);
        end
            existingComponentIDs = cellfun(@(x) x.ComponentID, saveData.hardwareSettings, 'UniformOutput', false);
    else
        existingComponentIDs = {};
    end

    for i = 1:length(obj.d.Available)
        component = obj.d.Available{i};
        params = component.GetParams;
        params.type = class(component);
        params.Active = logical(obj.d.Active(i));
        params.Previewing = component.Previewing;
        if any(contains(existingComponentIDs, component.ComponentID))
            saveData.hardwareSettings{contains(existingComponentIDs, component.ComponentID)} = params;
        else
            componentData{end+1} = params;
        end
        component.SaveAuxiliaryConfig(obj.path.paramBase);
    end
    if ~isempty(componentData)
        saveData.hardwareSettings = [saveData.hardwareSettings; componentData'];
    end
    jsonData = jsonencode(saveData);
    file = fopen([pBase filesep filename], 'w+');
    if file == -1
        obj.errorMsg(sprintf("Unable to create file %s", [pBase filesep filename]));
    end
    fprintf(file, '%s', jsonData);
    fclose(file);
    if ~any(contains(obj.h.SessionSelectDropDown.Items, filename))
        obj.h.SessionSelectDropDown.Items{end+1} = filename;
    end
    obj.h.SessionSelectDropDown.Value = filename;
end