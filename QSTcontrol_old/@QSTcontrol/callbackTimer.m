function callbackTimer(obj,~,~)

if ~obj.DAQ.IsRunning && ~obj.isRunning
    for ii = 1:obj.nThermodes
        if obj.s(ii).existPort
            obj.h.(['Thermode' char(64+ii)]).battery.Value = ...
                obj.s(ii).battery;
        end
    end
end