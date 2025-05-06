function callbackAnimalAdd(obj,~,~)

newID       = '';
while isempty(newID)
    newID	= inputdlg('New animal ID:','Add Animal ID',[1 50],{''});
    if isempty(newID)
        return
    end
    newID   = regexprep(newID{:},'[^A-Za-z0-9-_]','_');
    if ismember(newID,obj.h.animal.listbox.id.String)
        uiwait(errordlg('Please choose a unique animal ID.',...
            'ID not unique!','modal'))
        newID = '';
    end
end

obj.h.animal.listbox.id.String = ...
    sort([obj.h.animal.listbox.id.String; {newID}]);
obj.h.animal.listbox.id.Value = ...
    find(strcmp(obj.h.animal.listbox.id.String,newID));
mkdir(fullfile(obj.dirData,newID))