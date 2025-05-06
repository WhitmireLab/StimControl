function updateAnimals(app)

% get subdirectories
subDirs = dir(app.dirData);
subDirs = {subDirs([subDirs.isdir]).name};
subDirs = subDirs(cellfun(@isempty,regexp(subDirs,'^\.')));
if isempty(subDirs)
    subDirs = {''};
end

% set string
% obj.h.animal.listbox.id.String = subDirs;
app.h.animal.listbox.id.String = subDirs;

% select most recent
subDate = nan(size(subDirs));
for idxSub = 1:length(subDirs)
    tmp = rfind(fullfile(app.dirData,subDirs{idxSub}),'.','rmax',1);
    tmp = tmp(cellfun(@isempty,regexp({tmp.name},'^\.')));
    if ~isempty(tmp)
        % use the date of the newest file/folder within subDirs{idxSub}
        subDate(idxSub) = max(datenum({tmp.date}));
    else
        % if there are no contents, use the date of subDirs{idxSub} itself
        tmp = dir(fullfile(app.dirData,subDirs{idxSub}));
        subDate(idxSub) = datenum(tmp(1).date);
    end
end
[~,app.h.animal.listbox.id.Value] = max(subDate);