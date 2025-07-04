function stim = squareStim(l, params, rate)
%SquareStim generates a stim of length l, with params params and a daq rate of
% rate. Params takes the form of a struct:
% dig = struct( ...          
%     'delay',                0, ...
%     'dur',                  2, ...
%     'rep',                  0, ...
%     'repdel',               0);
onTicks = round(params.dur * rate / 1000);
offset = (params.delay * rate / 1000) + 1;
totalRepeats = params.rep + 1;
repeatDelay = round(params.repdel * rate / 1000);
maxRepeats = round((l-offset) / (repeatDelay + period * repeatsPerStim));

if totalRepeats == -1
    totalRepeats = maxRepeats;
end

stim = zeros(l);
for i = 1:totalRepeats
    stim(offset:offset+onTicks) = ones(onTicks);
    offset = offset + repeatDelay;
end
end

% % obtain sampling rate
% fs      = round(median(1./diff(tax)));
% 
% % create stimulus
% % t       = (0:duration*fs-1)/fs;
% npulses = duration*freq;
% stimseg = zeros(1,round(fs/freq));
% stimseg(1:numel(stimseg)*dc/100)=1;
% stim = repmat(stimseg,1,npulses);
% % stim    = square(2*pi*freq*t,dc)>0; %CW changed 2022.04.12 to eliminate
% % need for toolbox
% 
% % place stimulus
% dat     = false(size(tax));
% [~,t0]  = min(abs(tax-delay));
% dat(t0) = 1;
% stim    = [zeros(1,length(stim)) stim];
% dat     = conv(dat,stim,'same');
% 
