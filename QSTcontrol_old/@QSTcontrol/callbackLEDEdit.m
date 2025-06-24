function callbackLEDEdit(obj,hEdit,~)

IDparam = hEdit.Tag;
value   = real(str2double(hEdit.String));

% set some parameters
switch IDparam
    case 'ledDur'
        lims    = [0 9999];   	% parameter limits
        formatI = '%d';         % format for GUI display
    case 'ledFreq'
        lims    = [0.1 floor(obj.DAQ.Rate/2)];
        formatI = '%0.1f';
    case 'ledDC'
        lims    = [0 100];
        formatI = '%d';
    case 'ledDelay'
        lims    = [-9999 9999];
        formatI = '%d';
end

% handle values that are invalid or out of bounds
if isempty(value) || isnan(value)
    value = hEdit.Value;
else
    value = max([value lims(1)]);
    value = min([value lims(2)]);
end

% format values
str   = sprintf(formatI,value);
value = str2double(str);

% set GUI elements
obj.h.LED.edit.(IDparam).String = str;
obj.h.LED.edit.(IDparam).Value  = value;

% update plots
obj.createPlotLED(obj.h.LED.axes)