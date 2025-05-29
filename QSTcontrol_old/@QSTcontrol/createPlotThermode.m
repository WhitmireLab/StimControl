function createPlotThermode(obj,hAx)

idTherm = ['Thermode' hAx.Tag];
hParam  = obj.h.(idTherm);

if isempty(obj.p)
    tPre	= 1;
    tPost 	= 2;
else
    tPre    = obj.p(obj.idxStim).tPre / 1000;
    tPost   = obj.p(obj.idxStim).tPost / 1000;
end
tTotal  = tPre + tPost;

fs 	= obj.DAQ.Rate;               	% sampling rate (Hz)
N  	= hParam.edit.N.Value;       	% neutral temperature (°C)
C 	= [hParam.edit.C.Value];       	% target temperatures (°C)
D 	= [hParam.edit.D.Value]/1E3;  	% pulse durations (s)
V 	= [hParam.edit.V.Value];      	% ramp slope (onset, °C/s)
R 	= [hParam.edit.R.Value];       	% ramp slope (offset, °C/s)
S  	= [hParam.toggle.S.Value];      % surface select

tax    = linspace(1/fs,tTotal,tTotal*fs)-tPre;
dat    = ones(length(tax),5) * N;
[~,t0] = min(abs(tax));

for ii = find(S)
    dP    = D(ii)*fs-1;
    pulse = ones(dP,1);
    dV    = round(abs(C(ii)-N)/V(ii)*fs);
    dR    = round(abs(C(ii)-N)/R(ii)*fs);
    tmp   = linspace(0,1,dV)';
    pulse(1:min([dV dP])) = tmp((1:min([dV dP])));
    pulse = [pulse; linspace(pulse(end),0,dR)'] * (C(ii)-N) + N;
    
    tmp   = min([round(tPost*fs)+1 length(pulse)]);
    dat(t0+(1:tmp)-1,ii) = pulse(1:tmp);
end

cla(hAx)
obj.h.(idTherm).plot = plot(hAx,tax,dat);
hAx.XLim    = tax([1 end]);
tmp         = [N C(find(S))]; %#ok<FNDSB>
hAx.YLim    = [min(tmp) max(tmp)] + [-1 1]*max([range(tmp)*.1 .5]);
