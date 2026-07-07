function callbackFileExit(obj,~,~)
% CAKLLBACKFILEEXIT safely exits the program, stopping timers and clearing
% hardware sessions

% stop and delete timers
try
    stop(obj.timerStateMachine);
    delete(obj.timerStateMachine);
    stop(obj.timerGui);
    delete(obj.timerGui);
catch err
    disp(err)
end

% close and clear connected hardware
try
    obj.d.CloseAll();
    obj.d.ClearAll();
catch err
    disp(err)
end

% delete the figure
delete(obj.h.fig)

% if QSTcontrol was called via the batch file, also quit Matlab
if ~usejava('desktop')
    exit
end