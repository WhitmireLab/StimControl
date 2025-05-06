function callbackFileClose(obj,hClose,~)

obj.enableThermodeEdit(1)
obj.pFile = [];
obj.p     = [];
obj.g     = [];
obj.setTitle()

obj.h.protocol.edit.nStim.String = '';
set(obj.h.protocol.panel.main.Children,'Enable','off')

hClose.Enable = 'off';
obj.h.protocol.edit.Comment.String = '';