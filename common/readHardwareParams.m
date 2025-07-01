function objs = readHardwareParams(filepath)
    if isempty(filepath)
        filepath = [pwd filesep 'StimControl' filesep 'paramfiles' filesep 'HardwareParams.json'];
    end
    jsonStr = fileread(filepath);
    jsonData = jsondecode(jsonStr);
    objs = struct();
    camCount = 1; daqCount = 1;
    for i = 1:length(jsonData)
        hStruct = jsonData{i};
        switch lower(hStruct.DEVICE)
            case 'camera'
                hObj = CameraComponent('Struct', hStruct);
                objs.(sprintf('camera%d', camCount)) = hObj;
                camCount = camCount + 1;
            case 'daq'
                hObj = DAQComponent('Struct', hStruct);
                objs.(sprintf('daq%d', daqCount)) = hObj;
                daqCount = daqCount +1;
            otherwise
                disp("Unsupported hardware type. Come back later.")
        end
    end
end