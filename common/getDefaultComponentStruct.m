function componentStruct = getDefaultComponentStruct(componentType)
    filename = [pwd filesep 'StimControl' filesep 'common' filesep 'SupportedHardwareParams.txt'];
    jsonStr = fileread(filename);
    jsonData = jsondecode(jsonStr);
    componentStruct = struct();
    componentData = getfield(jsonData, upper(componentType));
    fs = fields(componentData);
    for i = 1:length(fs)
        attr = getfield(componentData, fs{i});
        componentStruct = setfield(componentStruct, fs{i}, attr.default);
    end
end