function callbackThermodeToggle(obj,hButton,~)

idTherm = ['Thermode' hButton.Tag(1)];
nTherm  = int8(hButton.Tag(1))-64;

% send toggle status to device
s = obj.s(nTherm);
h = obj.h.(idTherm).toggle.S;
q = ['S' sprintf('%d',[h.Value])];
s.fprintfd(q,.001)

% update GUI according to device state
tmp = regexp(s.query('P'),'S([01]{5})','tokens','once');
tmp = num2cell(tmp{1}=='1');
[h.Value] = tmp{:};

% update plots
obj.createPlotThermode(obj.h.(idTherm).axes)

