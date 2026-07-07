function callbackChangeSavePath(obj, src, event)
    %CALLBACKCHANGESAVEPATH changes the core save directory for
    %StimControl, creating the folder if it does not exist.
    if src == obj.h.SavePathTextArea
        filepath = obj.h.SavePathTextArea.Value;
    elseif src == obj.h.BrowseSavePathBtn
        % let the user select a file
        if iscell(obj.path.dirData)
            dir = obj.path.dirData{:};
        else
            dir = obj.path.dirData;
        end
        filepath = uigetdir(dir);
        if isempty(filepath) || ~any(filepath)
            return
        end
    end %shouldn't be called from anywhere else
    if ~isfolder(filepath)
        try
            mkdir(filepath);
        catch exception
            obj.errorMsg(sprintf("Unable to create directory %s", filepath));
            rethrow(exception);
        end
    end
    obj.path.dirData = filepath;
    obj.h.SavePathTextArea.Value = {filepath};
end