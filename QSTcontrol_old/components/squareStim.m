function dat = squareStim(tax,duration,freq,dc,delay)

% obtain sampling rate
fs      = round(median(1./diff(tax)));

% create stimulus
% t       = (0:duration*fs-1)/fs;
npulses = duration*freq;
stimseg = zeros(1,round(fs/freq));
stimseg(1:numel(stimseg)*dc/100)=1;
stim = repmat(stimseg,1,npulses);
% stim    = square(2*pi*freq*t,dc)>0; %CW changed 2022.04.12 to eliminate
% need for toolbox

% place stimulus
dat     = false(size(tax));
[~,t0]  = min(abs(tax-delay));
dat(t0) = 1;
stim    = [zeros(1,length(stim)) stim];
dat     = conv(dat,stim,'same');