function callbackSelectAnimal(obj, src, event)
% CALLBACKSELECTANIMAL Set the program's active animal by selected ID, or create a new one
if src == obj.h.newAnimalBtn
    % create a new animal
    dPrompt = {'Enter animal ID'};
    pName = 'New animal';
    animalID = inputdlg(dPrompt,pName,1,{'New animal'});
    animalID = animalID{:};
elseif src == obj.h.animalSelectDropDown
    % choose an existing animal, write a new animal directly into the box, or browse
    if strcmpi(src.Value, 'Browse...')
        % let the user select a directory
        [file, location] = uigetfile([obj.path.dirData filesep '*.*']);
        filepath = [location file];
        if isempty(filepath) || ~any(filepath)
            return
        end
        obj.path.dirData = location;
        animalID = file;
    else
        animalID = src.Value;
    end
else
    dbstack
    error("Not implemented");
    return
end
obj.animalID = animalID;