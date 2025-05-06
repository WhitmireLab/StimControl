function callbackThermodeEdit(obj,hEdit,~)

idTherm = ['Thermode' hEdit.Tag(1)];
nTherm  = int8(hEdit.Tag(1))-64;
IDparam = hEdit.Tag(2:end);
value   = real(str2double(hEdit.String));

% set some parameters
switch IDparam(1)
    case 'N'
        lims    = [20 40];      % parameter limits
        valFact = 10;           % parameter factor
        formatI = '%.1f';       % format for GUI display
        formatQ = '%s%03d';     % format for serial query
    case 'C'
        lims    = [5 60];
        valFact = 10;
        formatI = '%.1f';
        formatQ = '%s%03d';
    case 'V'
        lims    = [0.1 999.0];
        valFact = 10;
        formatI = '%.1f';
        formatQ = '%s%04d';
    case 'R'
        lims    = [10.0 999.0];
        valFact = 10;
        formatI = '%.1f';
        formatQ = '%s%04d';
    case 'D'
        lims    = [10 99999];% [10 9999];% edited with updated QST parameters 2024.10.21
        valFact = 1;
        formatI = '%d';
        formatQ = '%s%05d';
        % formatQ = '%s%04d';
    case 'T'
        lims    = [0 255];
        valFact = 1;
        formatI = '%d';
        formatQ = '%s%03d';
    case 'X'
        lims    = [0 9999];
        valFact = 1;
        formatI = '%d';
end

% handle values that are invalid or out of bounds
if isempty(value) || isnan(value)
    value = hEdit.Value;
else
    value = max([value lims(1)]);
    value = min([value lims(2)]);
end

% take a shortcut for vibration
if strcmp(IDparam,'X')
    obj.h.(idTherm).edit.vibDur.String = num2str(value);
    obj.h.(idTherm).edit.vibDur.Value  = value;
    return
end

% send value to serial device
q = sprintf(formatQ,IDparam,round(value*valFact));
if ismember(IDparam(1),'CVRD')
    if obj.h.(idTherm).check.(IDparam(1)).Value
        q(2) = '0';
    end
end
obj.s(nTherm).fprintfd(q,.001)                      % send command

% get value from serial device
val = obj.s(nTherm).query('P');                   	% query parameters
val = regexp(val,[IDparam(1) '(\d*)'],'tokens'); 	% regexp specific param
val = cellfun(@(x) {str2double(x)/valFact},val); 	% convert to number
str = cellfun(@(x) {sprintf(formatI,x)},val);       % format into string

% set GUI elements
[obj.h.(idTherm).edit.(IDparam(1)).String] = str{:};
[obj.h.(idTherm).edit.(IDparam(1)).Value]  = val{:};

% update binary field for parameter T
if strcmp(IDparam(1),'T')
	obj.h.(idTherm).edit.Tbin.String = dec2bin(val{:},8);
end

% update plots
obj.createPlotThermode(obj.h.(idTherm).axes)