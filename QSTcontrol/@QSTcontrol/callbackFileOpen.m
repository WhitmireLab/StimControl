function callbackFileOpen(obj,~,~)

[fn,pn,~] = uigetfile({'*.qst;*.txt','QST Protocol (*.qst,*.txt)'},'Open');
if isempty(fn) || ~exist(fullfile(pn,fn),'file')
    return
end
obj.pFile       = fullfile(pn,fn);
[obj.p,obj.g]   = readParameters(obj.pFile);
obj.idxStim     = 1;
obj.setTitle;

%obj.p2serial(obj.p(1));
obj.enableThermodeEdit(0)

%obj.h.protocol.edit.Comment.String = obj.p(1).Comments;
set(obj.h.protocol.panel.main.Children,'Enable','on')
set(obj.h.protocol.push.stop,'Enable','off')

obj.h.menu.fileClose.Enable = 'on';
%obj.p2GUI