function stimulate(obj,fnOut)

% release session (in case the previous run was incomplete)
if obj.DAQ.IsRunning
    obj.DAQ.stop
end
release(obj.DAQ);

% add listener for plotting/saving -- see function plotData() below
lh = addlistener(obj.DAQ,'DataAvailable',@plotData);

fs = 1000;
Aurorasf = 1/52; % (1V per 50mN as per book,20241125 measured as 52mN per 1 V PB)


IDtherm = arrayfun(@(x) {['Thermode' char(64+x)]},1:obj.nThermodes);
if isempty(obj.p)
    % single stimulation: use default values for tPre (time before onset of
    % stimulus) and tPost (time after onset of stimulus). Obtain duration
    % of vibration from respective GUI fields.
    tPre	 = 1;
    tPost 	 = 2;
    vibDur   = cellfun(@(x) obj.h.(x).edit.vibDur.Value,IDtherm) / 1000;
    ledDur   = obj.h.LED.edit.ledDur.Value / 1000;
    ledFreq  = obj.h.LED.edit.ledFreq.Value;
    ledDC    = obj.h.LED.edit.ledDC.Value;
    ledDelay = obj.h.LED.edit.ledDelay.Value / 1000;
    piezoAmp = 0;
    piezoFreq =0;
    piezoDur = 0;
    piezoStimNum = 0;
else
    % protocol run: use values from protocol structure
    tPre     = obj.p(obj.idxStim).tPre  / 1000;
    tPost    = obj.p(obj.idxStim).tPost / 1000;
    vibDur   = cellfun(@(x) obj.p(obj.idxStim).(x).VibrationDuration,IDtherm) / 1000;
    ledDur   = obj.p(obj.idxStim).ledDuration / 1000;
    ledFreq  = obj.p(obj.idxStim).ledFrequency;
    ledDC    = obj.p(obj.idxStim).ledDutyCycle;
    ledDelay = obj.p(obj.idxStim).ledDelay / 1000;
    piezoAmp = obj.p(obj.idxStim).piezoAmp * Aurorasf; piezoAmp = min([piezoAmp 9.5]);  %added a safety block here 2024.11.15
    piezoFreq = obj.p(obj.idxStim).piezoFreq;
    piezoDur = obj.p(obj.idxStim).piezoDur;
    piezoStimNum= obj.p(obj.idxStim).piezoStimNum;
end
tTotal  = tPre + tPost;
    
% prepare DAQ output (TTL TRIGGERS)
npreQSTtrig = 12;    %matches the number of entries outlined before QST and thermode triggers
tax = linspace(1/obj.DAQ.Rate,tTotal,tTotal*obj.DAQ.Rate)-tPre;
% out = zeros(numel(tax),npreQSTtrig+obj.nThermodes+1);	% preallocate with zeros
out = zeros(numel(tax),npreQSTtrig+obj.nThermodes+2);	% preallocate with zeros

%%%%% SCAN IMAGE TRIGGERS %%%%%
out(1,1)    = 1;                                    % TTL ScanImage: Acq start
% stimstart = find(tax>5); stimstart = stimstart(1);
% out(tPre*obj.DAQ.Rate + (0:2),2)  = 1;                                    % TTL ScanImage: Aux Trig
out(end-5:end-4,2)    = 1;                                    % TTL ScanImage: Acq end
out(1,3)    = 1;                                    % TTL ScanImage: Next File

%%%%% BASLER CAMERA TRIGGER %%%%%
framerate = 20;%20; % Hz - Basler Camera
framerate_unitstep = round(obj.DAQ.Rate/framerate);
for jjj = 1:round(framerate_unitstep/2)
    out(jjj:framerate_unitstep:end,4)    = 1;       % TTL Basler: Frame Trigger
    out(jjj:framerate_unitstep:end,5)    = 1;  
end

%%%%% Excitation Light Trigger %%%%% 
out(1:end-1,6) = 1;   % BLUE LED
out(1:end-1,7) = 1;   % GREEN LED (not used, green light is only used to take an image before functional recordings)

%%%%% Auditory Stimulus %%%%% 
out(1:end-1,8) = 1; % Speaker (NEEDS PARAMETERIZATION)

%%%%% Optical stimulus (for ChR2) %%%%%
out(1,9) = 1; % Drive blue LED. (NEEDS PARAMETERIZATION)

%%%%% Hamamatsu Camera Trigger %%%%% 
out(1,10) = 1; %Trigger image acquisition with Hamamatsu. Need to see how to best achieve this.

% LED Stimulus
out(:,11) = squareStim(tax,ledDur,ledFreq,ledDC,ledDelay)';

% IRLED Illumination %% ADDED 2020.07.20
out(1:end-1,12) = 1;

%%%%% Vibration Stimulus %%%%% 
for kk = 1:obj.nThermodes
    if vibDur(kk)>0
        tmp           = (tPre*obj.DAQ.Rate) + (1:vibDur(kk)*obj.DAQ.Rate);
        out(tmp,npreQSTtrig+kk) = 1;
    end
end
out(tPre*obj.DAQ.Rate + (0:100),npreQSTtrig+kk+1) = 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% ADD ANALOG OUTPUT GENERATION %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ramp1 = 20;  % original was 15, trying with 2 on 13.12.2024 change 2 on 20250501
piezostimunitx = -ramp1:ramp1;
piezostimunity = normpdf(piezostimunitx,0,3);
piezostimunity = piezostimunity./max(piezostimunity);
piezohold = ones(1,piezoDur);
piezostimunity = [piezostimunity(1:ramp1) piezohold piezostimunity(ramp1+1:end)];

piezostim = zeros(size(tax ));
if piezoStimNum>0
    for pp = 1:piezoStimNum
        pos1 = (pp-1) .*(1/piezoFreq) ; % in seconds
        tloc = find(tax>=pos1); tloc = tloc(1);
        piezostim(tloc:tloc+numel(piezostimunity)-1) = piezostim(tloc:tloc+numel(piezostimunity)-1)+piezostimunity;
    end
    piezostim = piezostim.*piezoAmp;
else
   piezostim = zeros(size(tax )); 
end

out(:,npreQSTtrig+kk+2) = piezostim;





obj.DAQ.queueOutputData(out)            % queue data
prepare(obj.DAQ)                        % prepare data acquisition

% wait for thermodes to reach neutral temperature
obj.waitForNeutral

% open output file (if filename provided)
if nargin > 1
    output  = true;
    fid1    = fopen(fnOut,'w');
else
    output  = false;
end

% run stimulation
startBackground(obj.DAQ);               % start data acquisition
try
    wait(obj.DAQ,tTotal+1)          	% wait for data acquisition
catch me
    warning(me.identifier,'%s',...      % rethrow timeout error as warning
        me.message); 
end

% close output file
if output
    fclose(fid1);
end

% delete listener
delete(lh);


function plotData(~,event)
    
    % manage persistent variables
    persistent nTherm idTherm idxData
    if isempty(nTherm)
        nTherm = obj.nThermodes;
    end
    if isempty(idxData)
        idxData = 1:(4*nTherm);
    end
    if isempty(idTherm)
        idTherm = arrayfun(@(x) {['Thermode' char(64+x)]},1:nTherm);
    end
    
    % build indices for plotting
    a   = event.Source.NotifyWhenDataAvailableExceeds;
    b   = event.Source.ScansAcquired;
    idx = (1:a)+(b-a);
    
    % scale data from thermodes
    dat = event.Data;
    % dat(:,idxData(1:2)) = dat(:,idxData(1:2)) * 17.0898 - 5.0176;
    dat(:,idxData(1:2)) = dat(:,idxData(1:2)) * 12  - 2; % PB 20241219
    dat(:,idxData(3:4)) = (dat(:,idxData(3:4))*10 + 32) ;
    ylim([12 50])
    
    % plot data
    for ii = 1:5
        for jj = 1:nTherm
            obj.h.(idTherm{jj}).plot(ii).YData(idx) = dat(:,ii+(jj-1)*5);
        end
    end
    
    % save to disk (optional)
    if output
        fwrite(fid1,[event.TimeStamps-tPre,dat,out(idx,:)]','double');
    end
end
end