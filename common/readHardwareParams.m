function objs = readHardwareParams(filepath)
    jsonStr = fileread(filepath);
    jsonData = jsondecode(jsonStr);
    objs = [];
    for i = 1:length(jsonData)
        hStruct = jsonData{i};
        switch lower(hStruct.DEVICE)
            case 'camera'
                hObj = CameraInterface('Struct', hStruct);
            case 'daq'
                hObj = DaqInterface('Struct', hStruct);
            otherwise
                disp("Unsupported hardware type. Come back later.")
        end
        objs(i) = hObj;
    end
end