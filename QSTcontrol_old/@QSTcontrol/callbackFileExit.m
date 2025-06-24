function callbackFileExit(obj,~,~)

% delete the figure
delete(obj.h.fig)

% stop and delete timer
stop(obj.t)
delete(obj.t)

% if QSTcontrol was called via the batch file, also quit Matlab
if ~usejava('desktop')
    exit
end