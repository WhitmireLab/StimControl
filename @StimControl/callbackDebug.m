function callbackDebug(obj, src, event)
% CALLBACKDEBUG - artificial breakpoint for accessing internal program
% information. Use with caution.
if src == obj.h.debugComponentBtn
    rowIndex = obj.h.AvailableHardwareTable.Selection;
    if isempty(rowIndex)
        return;
    end
    component = obj.d.Available{rowIndex};
    component.Debug;
    return
end
keyboard
end