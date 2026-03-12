function callbackSaveConfig(obj, src, event)
    keyboard %YOU GOTTA TEST THIS BEFORE YOU OVERWRITE YOUR WORKING CONFIG    
    [s, pcInfo] = system('vol');
    pcInfo = strsplit(pcInfo, '\n');
    pcID = pcInfo{2}(end-8:end);
    prompt = {'Enter filename:'};
    dlgtitle = 'Save config';
    definput = {[pcID 'default']};
    filename = inputdlg('Enter filename:','Save config',[1 45],{[pcID '_default']});
    if isempty(filename)
        return
    end
    filename = [filename{:} '.json'];
    % Save session
    pBase = obj.path.sessionBase;
    saveData = [];
    saveData.activeHardware = obj.d.ActiveIDs;
    saveData.hardwareTableData = [];
    obj.h.AvailableHardwareTable.Data;
    for ri = 1:height(obj.h.AvailableHardwareTable.Data)
        line = obj.h.AvailableHardwareTable.Data(ri,:);
        saveData.hardwareTableData.(line.('Protocol ID'){:}) = struct( ...
            'Enable', line.('Enable'), ...
            'Preview', line.('Preview'), ...
            'PRow', line.('PRow'){:}, ...
            'PColumn', line.('PColumn'){:});
    end
    % Save component params
    componentData = {};
    for i = 1:length(obj.d.Available)
        component = obj.d.Available{i};
        params = component.GetParams;
        params.type = class(component);
        params.Active = logical(obj.d.Active(i));
        params.Previewing = component.Previewing;
        componentData{end+1} =params;
        component.SaveAuxiliaryConfig(obj.path.paramBase);
    end
    saveData.hardwareSettings = componentData;
    jsonData = jsonencode(saveData);
    file = fopen([pBase filesep filename], 'w+');
    if file == -1
        obj.errorMsg(sprintf("Unable to create file %s", [pBase filesep filename]));
    end
    fprintf(file, '%s', jsonData);
    fclose(file);
end