function callbackThermodeSync(obj,hCheck,~)

hEdit = obj.h.(['Thermode' hCheck.Tag(1)]).edit.(hCheck.Tag(2));
if hCheck.Value
    obj.callbackThermodeEdit(hEdit(1))
    set(hEdit(2:5),'Enable','off',...
        'String',hEdit(1).String,'Value',hEdit(1).Value)
else
    set(hEdit(2:5),'Enable','on')
end