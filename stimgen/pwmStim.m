function stim = pwmStim(l, params, rate)
%PWMSTIM generates a stim of length l, with params params and a daq rate of
% rate. Params takes the form of a struct:
% pwm  = struct( ...         
%     'dc',                   50,...
%     'freq',                 100,...
%     'dur',                  50,...
%     'delay',                0, ...
%     'rep',                  0, ...
%     'repdel',               0);
period = round(rate/params.freq); %in ticks
onTicks = round(period*(params.dc/100));
repeatsPerStim = round((params.dur * rate)/period);
offset = (params.delay * rate / 1000) + 1;
totalRepeats = params.rep;
repeatDelay = params.repdel * rate / 1000;
maxRepeats = round((l-offset) / (repeatDelay + period * repeatsPerStim));
if totalRepeats == -1 
    totalRepeats = maxRepeats;
end

stim = zeros(l);
for i = 1:totalRepeats
    for j = 1:repeatsPerStim
        stim(offset:offset+onTicks) = ones(onTicks);
        offset = offset + period;
    end
    offset = offset + repeatDelay;
end
end