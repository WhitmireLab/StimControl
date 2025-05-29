function callbackDebugDelEmpty(obj,~,~)

sub = dir(obj.dirData);
sub = sub([sub.isdir]);
sub = {sub(cellfun(@isempty,regexp({sub.name},'(^\.)'))).name};

for idxSub = 1:length(sub)
    tmp = fullfile(obj.dirData,sub{idxSub});
    if length(dir(tmp)) < 3
        rmdir(tmp)
    end
end

obj.updateAnimals()