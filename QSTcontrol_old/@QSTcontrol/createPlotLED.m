function createPlotLED(obj,hAx)

hParam  = obj.h.LED;

if isempty(obj.p)
    tPre	= 1;
    tPost 	= 2;
else
    tPre    = obj.p(obj.idxStim).tPre / 1000;
    tPost   = obj.p(obj.idxStim).tPost / 1000;
end
tTotal  = tPre + tPost;

fs 	 = obj.DAQ.Rate;                    % sampling rate (Hz)
dur  = hParam.edit.ledDur.Value/1000;  	% LED duration (s)
freq = hParam.edit.ledFreq.Value;       % LED frequency (Hz)
dc 	 = hParam.edit.ledDC.Value;         % LED duty cycle (%)
del  = hParam.edit.ledDelay.Value/1000; % LED delay (s)

tax	 = linspace(1/fs,tTotal,tTotal*fs)-tPre;
dat  = squareStim(tax,dur,freq,dc,del);

[xb,yb] = stairs(tax,dat);
cla(hAx)
obj.h.LED.plot  = fill(obj.h.LED.axes,[xb;xb(end)],[yb; yb(1)],'r','edgecolor','none');
hAx.XLim        = tax([1 end]);
hAx.YLim        = [0 1];
