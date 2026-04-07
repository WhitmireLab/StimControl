function callbackFileExit(obj,~,~)

% stop and delete timer
try
    stop(obj.timerStateMachine);
    delete(obj.timerStateMachine);
    stop(obj.timerGui);
    delete(obj.timerGui);
catch err
    disp(err)
end
    
try
    obj.d.CloseAll();
    obj.d.ClearAll();
catch err
    disp(err)
end

% delete the figure
delete(obj.h.fig)

% remove parallel pool sessions
delete(gcp('nocreate'))

% if QSTcontrol was called via the batch file, also quit Matlab
if ~usejava('desktop')
    exit
end