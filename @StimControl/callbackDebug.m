function callbackDebug(obj, src, event)    
if src == obj.h.debugComponentBtn
    rowIndex = obj.h.AvailableHardwareTable.Selection;
    if isempty(rowIndex)
        return;
    end
    % selectedRow = obj.h.AvailableHardwareTable.Data(rowIndex,:);
    component = obj.d.Available{rowIndex};
    component.Debug;
    return
end
keyboard
end

function PlotSavedData()
    path = 'C:\Users\labadmin\Desktop\logs\debug\251112\251112_161302_TempandVibe';
    daqDataFile = '00011_stim00004.csv';
    daqChannelNames = 'TriggerDAQ_channelNames.csv';
end