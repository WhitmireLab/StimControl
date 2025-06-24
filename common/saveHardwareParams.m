function saveHardwareParams(filename, objs)
%SAVEHARDWAREPARAMS Summary of this function goes here
%   Detailed explanation goes here
structs = [];
for i = objs
    s = obj.GetParams();
    structs(i) = s;
end
encoded = jsonencode(structs);
fid = fopen(filename,'w');
fprintf(fid,'%s',encoded);
fclose(fid);
end

