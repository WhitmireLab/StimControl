function saveHardwareParams(filepath, objs, identifier)
%% Save hardware parameters. 
% Filepath = folder in which to store parameters. 
% objs = array of objs to store. Objs must be a subclass of HardwareComponent
% or implement GetParams(obj) which returns a struct characterising the obj.
%TODO Figure out save file structure
structs = [];
for i = objs
    s = obj.GetParams();
    structs(i) = s;
    if contains(class(obj), 'DAQ')
        channelData = obj.GetChanParams();
        
    end
end
encoded = jsonencode(structs);
fid = fopen(filepath,'w');
fprintf(fid,'%s',encoded);
fclose(fid);
end

