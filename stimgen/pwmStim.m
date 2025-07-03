function stim = pwmStim(l, params, rate)
%PWMSTIM generates a stim of length l, with params params and a daq rate of
% rate. Params takes the form of a struct:
% pwm  = struct( ...
%     'dc',                   50,...
%     'freq',                 100,...
%     'dur',                  2,...
%     'delay',                0);
period = round(rate/params.freq);
onTicks = round(period*(params.dc/100));
numRepeats = round((params.dur * rate)/period);
offset = (params.delay * rate) + 1;
stim = zeros(l);
for i = 1:numRepeats
    stim(offset:offset+onTicks) = ones(onTicks);
    offset = offset + period;
end
end