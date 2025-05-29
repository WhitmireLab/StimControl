function setTitle(obj,string)

if nargin<2
    string = '';
end

if isempty(obj.pFile)
    base = obj.name;
else
    [~,fn,ext] = fileparts(obj.pFile);
    base = sprintf('%s%s - %s',fn,ext,obj.name);
end

if isempty(string)
    obj.h.fig.Name = base;
else
    obj.h.fig.Name = sprintf('%s (%s)',base,string);
end