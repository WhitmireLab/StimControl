function checkSync(obj)

for ii = 1:obj.nThermodes
    IDthermode = ['Thermode' char(64+ii)];
    for IDparam = 'CVRD'
        hEdit  = obj.h.(IDthermode).edit.(IDparam);
        hCheck = obj.h.(IDthermode).check.(IDparam);
        isSync = all(~diff([hEdit.Value]));
       
        hCheck.Value = isSync;
        if isSync
            set(hEdit(2:end),'Enable','off');
        else
            set(hEdit(2:end),'Enable','on')
        end
    end
end