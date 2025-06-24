function callbackProtocolStop(obj,hButton,~)

obj.isRunning = false;
for ii = 1:obj.nThermodes
    obj.s(ii).query('A');
end
obj.DAQ.stop