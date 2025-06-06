function readHardwareParameters(filename)
    filename = 'C:\Users\labadmin\Documents\MATLAB\WidefieldImager\paramfiles\HardwareParams.json';
    jsonStr = fileread(filename);
    jsonData = jsondecode(jsonStr);
    for i = 1:length(jsonData)
        %TODO FIGURE OUT HOW TO STORE ALL THESE HANDLES??
        hStruct = jsonData{i};
        switch lower(hStruct.DEVICE)
            case 'camera'
                %TODO AYE
                continue
            case 'daq'
                hObj = DaqInterface('Struct', hStruct);
            otherwise
                disp("Unsupported hardware type. Come back later.")
        end
    end
    
end