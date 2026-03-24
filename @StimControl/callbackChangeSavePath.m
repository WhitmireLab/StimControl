function callbackChangeSavePath(obj, src, event)
    if src == obj.h.SavePathTextArea
        filepath = obj.h.SavePathTextArea.Value;
    elseif src == obj.h.BrowseSavePathBtn
        % let the user select a file
        filepath = uigetdir(obj.path.dirData{:});
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
    obj.path.dirData = {filepath};
    obj.h.SavePathTextArea.Value = filepath;
end