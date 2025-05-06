function enableThermodeEdit(obj,bool)

enable = {'off','on'};
enable = enable{bool+1};
for ii = 1:obj.nThermodes
    IDthermode = ['Thermode' char(64+ii)];
    set(struct2array(obj.h.(IDthermode).edit),'Enable',enable);
    set(struct2array(obj.h.(IDthermode).check),'Enable',enable);
    set(struct2array(obj.h.(IDthermode).toggle),'Enable',enable);
    if bool
        for tmp = 'CVRD'
            callbackThermodeSync(obj,obj.h.(IDthermode).check.(tmp))
        end
    end
end