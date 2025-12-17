classdef StimGenerator

properties (Constant)
    % Constants for use in calculations. May change depending on specific
    % lab hardware.
    Aurorasf = 52;
end

% NOTE: for information on how the passed parameters are expected to be set
% up, see common/readProtocol. I don't want a bunch of comment redundancy
% while this is still in development (TODO: documentation once this has
% stopped being in development)

methods (Static, Access=public)

function stimTrain = GenerateStimTrain(componentTrialData, genericTrialData, sampleRate)
    % Generates a stimulus train given arguments
    seq = componentTrialData.sequence;
    delays = componentTrialData.delay;
    params = componentTrialData.params;
    secsPre = genericTrialData.tPre  / 1000;
    secsPost = genericTrialData.tPost / 1000;
    secsTotal = secsPre + secsPost;

    timeAxis = linspace(1/sampleRate,secsTotal,secsTotal*sampleRate)-secsPre;
    tPreLength = StimGenerator.MsToTicks(genericTrialData.tPre, sampleRate);

    % Preallocate all zeros
    stimTrain = zeros(numel(timeAxis), 1);
    if strcmpi(componentTrialData.params{1}.type, 'thermalpulse')
        stimTrain = ones(numel(timeAxis), 1);
        stimTrain = stimTrain * componentTrialData.params{1}.commands.NeutralTemp;
    end
    
    stimTicks = numel(timeAxis);
    startIdx = 0;
    
    for i = 1:length(componentTrialData.sequence)
        stimIdx = componentTrialData.sequence(i);
        preStimTicks = StimGenerator.MsToTicks(componentTrialData.delay(i), sampleRate);
        stimParams = componentTrialData.params(stimIdx);
        if iscell(stimParams)
            stimParams = stimParams{:};
        end
        startIdx = startIdx + preStimTicks;

        interimStim = StimGenerator.GenerateStim(stimParams, sampleRate, stimTicks-startIdx);
        stimTrain(startIdx+1:startIdx+length(interimStim)) = interimStim; 

        startIdx = startIdx + length(interimStim); 
    end
end

function stim = GenerateStim(params, rate, maxDur)
    % generates a single stim 
    generatorFcn = @(h) h('sampleRate', rate, 'totalTicks', maxDur, 'paramsStruct', params);
    generatorHandle = [];
    switch(lower(params.type))
        case 'pwm'
            generatorHandle = @StimGenerator.pwm;
        case 'digitalpulse'
            generatorHandle = @StimGenerator.digitalPulse;
        case 'omission'
            generatorHandle = @StimGenerator.omission;
        case 'analogpulse'
            generatorHandle = @StimGenerator.analogPulse;
        case 'sinewave'
            generatorHandle = @StimGenerator.sineWave;
        case 'analognoise'
            generatorHandle = @StimGenerator.analogNoise;
        case 'squarewave'
            generatorHandle = @StimGenerator.squareWave;
        case 'digitaltrigger'
            generatorHandle = @StimGenerator.digitalTrigger;
        case 'arbitrary'
            generatorHandle = @StimGenerator.arbitraryStim;
        case 'piezo'
            generatorHandle = @StimGenerator.piezoStim;
        case 'thermalpreview'
            generatorHandle = @StimGenerator.thermalPreview;
        case 'thermalpulse'
            generatorHandle = @StimGenerator.thermalPulsePreview;
        case 'qst'
            generatorHandle = @StimGenerator.thermalPreview;
        case 'serial'
            % trigger - special case. Hardcoded for now TODO
            stim = StimGenerator.serialTrigger( ...
                'sampleRate', rate, ...
                'totalTicks', maxDur, ...
                'duration', params.commands.dStimulus);
            return
        otherwise
            error("Unknown stimulus type: %s", params.type);
    end
    stim = generatorFcn(generatorHandle);
end

function stim = pwm(varargin)
    % Generates a PWM stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    %     rampUp     (double=0): duration of any up ramping (ms), must fall within total duration
    %     rampDown   (double=0): duration of any down ramping (ms), must fall within total duration
    %     frequency  (double=30): frequency of PWM signal (Hz)
    %     dutyCycle  (0<double<100 =50): the stimulus's maximum duty cycle, as a percentage
        
    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'rampUp', 0, @(x) isnumeric(x));
    addParameter(p, 'rampDown', 0, @(x) isnumeric(x));
    addParameter(p, 'frequency', 30, @(x) isnumeric(x));
    addParameter(p, 'dutyCycle', 50, @(x) isnumeric(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    if (params.duration > 0 && params.rampUp + params.rampDown > params.duration) ...
        || (params.duration == -1 && (params.rampUp + params.rampDown > StimGenerator.TicksToMs(params.totalTicks, params.sampleRate)))
        error('invalid parameters for stimulus: ramp duration must fit within overall duration');
    end

    durationTicks = length(stim);
    periodTicks = round(params.sampleRate/params.frequency); % period in ticks
    onTicks = round(periodTicks*(params.dutyCycle/100));
    totalPeriods = floor(durationTicks / periodTicks);
    if params.rampUp > 0 || params.rampDown > 0
        rampUpPeriods = round(StimGenerator.MsToTicks(params.rampUp, params.sampleRate) / periodTicks); %TODO SIMPLIFY
        rampDownPeriods = round(StimGenerator.MsToTicks(params.rampDown, params.sampleRate) / periodTicks); %TODO SIMPLIFY
    else
        rampUpPeriods = 0;
        rampDownPeriods = 0;
    end
    highPeriods = totalPeriods - (rampUpPeriods + rampDownPeriods);
    % generate stim
    jj = 1;
    for i = 1:periodTicks:length(stim)
        if jj <= rampUpPeriods
            numOnTicks = round(onTicks/(rampUpPeriods+1))*jj;
        elseif jj > totalPeriods-rampDownPeriods
            tmp = (1+totalPeriods)-jj;
            numOnTicks = round(onTicks/(rampDownPeriods+1))*tmp;
        else
            numOnTicks = onTicks;
        end
       stim(i:i+numOnTicks) = 1;
       jj = jj+1; 
    end
    stim = stim(1:durationTicks);
    if params.display
        StimGenerator.show(stim);
    end
end

function stim = digitalPulse(varargin)
    % Generates a digital pulse stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    p = inputParser();
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    if isfield(params, 'alignRight') && params.alignRight
        stim = StimGenerator.GetBase(params.totalTicks, -1, params.sampleRate);
        durTicks = StimGenerator.MsToTicks(params.duration, params.sampleRate);
        stim(end-durTicks:end) = 1;
    else
        stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
        stim = ones(length(stim), 1);
    end

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = omission(varargin)
    % Generates a digital pulse stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    p = inputParser();
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = analogPulse(varargin)
 % Generates an analog pulse stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    %     rampOn     (double=0): duration of any up ramping (ms), must fall within total duration
    %     rampOff   (double=0): duration of any down ramping (ms), must fall within total duration
    %     pulseAmp     (double=5): maximum amplitude of the pulse, V
    %     baseAmp     (double=0): baseline from which to pulse, V

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'rampOn', 0, @(x) isnumeric(x));
    addParameter(p, 'rampOff', 0, @(x) isnumeric(x));
    addParameter(p, 'baseAmp', 5, @(x) isnumeric(x));
    addParameter(p, 'pulseAmp', 0, @(x) isnumeric(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    if (params.duration > 0 && params.rampOn + params.rampOff > params.duration) ...
        || (params.duration == -1 && (params.rampOn + params.RampDown > StimGenerator.TicksToMs(length(stim), params.sampleRate)))
        error('invalid parameters for stimulus: ramp duration must fit within overall duration');
    end
    
    stim(:) = params.pulseAmp;
    rampUpTicks = StimGenerator.MsToTicks(params.rampOn, params.sampleRate);
    rampDownTicks = StimGenerator.MsToTicks(params.rampOff, params.sampleRate);
    stim(1:rampUpTicks) = linspace(params.baseAmp, params.pulseAmp, rampUpTicks);
    % stim(rampUpTicks+1:length(stim)-rampDownTicks) = params.pulseAmp;
    stim(1+end-rampDownTicks:end) = linspace(params.pulseAmp, params.baseAmp, rampDownTicks);

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = sineWave(varargin)
    % Generates an analog sinewave stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     amplitude  (double=5): peak-peak amplitude of the signal (V)
    %     frequency  (double=30): wave frequency
    %     phase      (double=0): phase shift, radians
    %     verticalShift (double or vector = 0): constant term over course of sample. 
    %                       Must be of length totalTicks or a double
    %     amplitudeMod (vector = 1): modifications for amplitude over the course of the sample. 
    %                       Must be of length totalTicks.

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'frequency', 30, @(x) isnumeric(x));
    addParameter(p, 'phase', 0, @(x) isnumeric(x));
    addParameter(p, 'amplitude', 5, @(x) isnumeric(x));
    addParameter(p, 'verticalShift', 0, @(x) isnumeric(x));
    addParameter(p, 'amplitudeMod', 1, @(x) isnumeric(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end
    
    if params.duration ~= -1
        N = params.duration/1000 * params.sampleRate;
        dur = params.duration / 1000;
    else
        N = params.totalTicks;
        dur = StimGenerator.TicksToMs(params.totalTicks, params.sampleRate) / 1000;
    end
    tax = linspace(0, dur, N);
    stim = sin(2*pi*params.frequency*tax + params.phase);
    stim = stim * params.amplitude;
    stim = stim + params.verticalShift;
    stim = stim .* params.amplitudeMod;

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = analogNoise(varargin)
    % Generate analog noise.
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     maxAmplitude  (double=5): maximum amplitude of the signal (V)
    %     minAmplitude  (double=-5): minimum amplitude of the signal (V)
    %     distribution  (string='uniform'): random distribution to use
    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'maxAmplitude', 5, @(x) isnumeric(x));
    addParameter(p, 'minAmplitude', -5, @(x) isnumeric(x));
    addParameter(p, 'distribution', 'uniform', @(x) ischar(x) || isstring(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end
    
    if params.duration ~= -1
        len = StimGenerator.MsToTicks(params.duration, params.sampleRate);
    else
        len = params.totalTicks;
    end

    switch params.distribution
        case 'normal'
            p = 6;
            stim = sum(rand(len,p),2)/p;
        case 'uniform'
            stim = rand([len 1]);
        otherwise
            error("Invalid distribution: %s", params.distribution);
    end
    mul = (params.maxAmplitude - params.minAmplitude);
    stim = stim * mul;
    stim = stim + params.minAmplitude;
    
    if params.display
        StimGenerator.show(stim);
    end
end

function stim = squareWave(varargin)
    % Generates a squarewave stim
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     frequency  (double=30): wave frequency (Hz)
    %     maxAmp     (double=5): maximum amplitude (V)
    %     minAmp     (double=-5): minimum amplitude (V)
    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'frequency', 30, @(x) isnumeric(x) && x>0);
    addParameter(p, 'maxAmp', 5, @(x) isnumeric(x));
    addParameter(p, 'minAmp', 0, @(x) isnumeric(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    pulseTicks = round(params.sampleRate/params.frequency);
    stim = stim+params.minAmp;
    for i = 1:pulseTicks:length(stim)
        stim(i:i+round(pulseTicks/2)) = params.maxAmp;
    end

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = digitalTrigger(varargin)
    % Generates a digital trigger stim
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     frequency  (double=30): wave frequency

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'frequency', 30, @(x) isnumeric(x) && x>0);
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end
    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    pulseTicks = round(params.sampleRate/params.frequency);

    for i = 1:pulseTicks:length(stim)
        stim(i:i+round(pulseTicks/2)) = 1;
    end

    if params.display
        StimGenerator.show(stim);
    end

end

function stim = arbitraryStim(varargin)
    % Generates a digital trigger stim
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     interpolate(logical=false): whether to interpolate or remove entries to match the totalTicks
    %     filename (string=''): the location of the file to read from
    %     display (logical=false): whether to display the output

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'interpolate', false, @(x) islogical(x));
    addParameter(p, 'filename', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = readmatrix(params.filename);
    if ~ismember('sampleRate', p.UsingDefaults) ...
        || ~ismember('totalTicks', p.UsingDefaults) ...
        || ~ismember('duration', p.UsingDefaults)
        if params.duration ~= -1
            expectedTicks = round(params.duration * params.sampleRate / 1000);
        else
            expectedTicks = params.totalTicks;
        end
        if length(stim) ~= expectedTicks
            if params.interpolate
                % warning("Given stimulus %s does not have an appropriate number of samples for %s ticks at %s rate. Interpolating...", params.filename, expectedTicks, params.sampleRate);
                % TODO INTERP1 https://au.mathworks.com/help/matlab/ref/double.interp1.html
                samplePoints = linspace(1, length(stim), length(stim));
                queryPoints = linspace(1, length(stim), expectedTicks);
                stim = interp1(samplePoints, stim, queryPoints);
            else
                durMs = expectedTicks * 1000 / params.sampleRate;

                error("Given stimulus %s does not have an appropriate number of samples for %d ms duration at %d rate, and interpolation was set to false. " + ...
                    "Allow interpolation using the Interp1 argument, or change the duration, rate, or stimulus. " + ...
                    "Appropriate number of ticks was %d but %d ticks were defined in the file..", ...
                    params.filename, durMs, params.sampleRate, expectedTicks, length(stim));
            end
        end
    end

    if params.display
        StimGenerator.show(stim);
    end
end

function stim = piezoStim(varargin)
    % Generates a digital trigger stim
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %                       When both are defined, duration will be limited to within totalTicks. 
    %     ramp      (double=20): stimulus ramp
    %     amplitude      (double=5): stimulus max amplitude (V)
    %     frequency      (double=20): frequency of stimulus (Hz)
    %     nStims      (double=1): how many times to run the stimulus in this block
    %     filename (string=''): the location of the file to read from
    %     display (logical=false): whether to display the output

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'ramp', 20, @(x) isnumeric(x));
    addParameter(p, 'amplitude', 5, @(x) isnumeric(x));
    % addParameter(p, 'duration', 20, @(x) isnumeric(x));
    addParameter(p, 'frequency', 20, @(x) isnumeric(x));
    addParameter(p, 'nStims', 1, @(x) isnumeric(x) && x>=0);
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    tax = linspace(1/params.sampleRate, length(stim)/params.sampleRate, length(stim));
    ramp = params.ramp;
    piezoAmp = params.amplitude * StimGenerator.Aurorasf; piezoAmp = min([piezoAmp 9.5]);  %added a safety block here 2024.11.15
    piezostimunitx = -ramp:ramp;
    piezostimunity = normpdf(piezostimunitx,0,3);
    piezostimunity = piezostimunity./max(piezostimunity);
    piezohold = ones(1,(params.duration - (2*ramp + 1)));
    piezostimunity = [piezostimunity(1:ramp) piezohold piezostimunity(ramp+1:end)];
    if params.nStims == 1
        stim = piezostimunity;
    elseif params.nStims>0 %legacy
        for pp = 1:params.nStims
            pos1 = (pp-1) .*(1/params.frequency) ; % in seconds
            tloc = find(tax>=pos1); tloc = tloc(1);
            stim(tloc:tloc+numel(piezostimunity)-1) = stim(tloc:tloc+numel(piezostimunity)-1)+piezostimunity;
        end
        stim = piezostim.*piezoAmp;
    end
end

function stim = thermalPreview(varargin)
    % Generates a thermal preview stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    %     display     (logical=false): whether to display the generated stimulus
    % PARAMS (THERMAL):
    %     paramsStruct   (struct): structure of parameters for thermal stimulus
    %        If provided, will override individual parameters (below)
    %     NeutralTemp (double=32): neutral temperature (°C)
    %     PacingRate  (double=300): pacing rate (ms)
    %     ReturnSpeed (double=300): return speed (ms)
    %     SetpointTemp (double=32): setpoint temperature (°C)
    %     SurfaceSelect (vector[1x5]=[1 1 0 0 0]): surface select (1=on, 0=off)
    %     dStimulus   (double=2000): stimulus duration (ms)
    %     integralTerm (double=1): integral term
    %     nTrigger    (double=1): number of triggers
    %     VibrationDuration (double=0): vibration duration (ms)

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x)); 
    addParameter(p, 'display', false, @(x) islogical(x));

    addParameter(p, 'NeutralTemp', 32, @(x) isnumeric(x));
    addParameter(p, 'PacingRate', 300, @(x) isnumeric(x));
    addParameter(p, 'ReturnSpeed', 300, @(x) isnumeric(x));
    addParameter(p, 'SetpointTemp', 32, @(x) isnumeric(x));
    addParameter(p, 'SurfaceSelect', [1 1 0 0 0], @(x) isnumeric(x) && isvector(x) && length(x) == 5);
    addParameter(p, 'dStimulus', 2000, @(x) isnumeric(x));
    addParameter(p, 'VibrationDuration', 0, @(x) isnumeric(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    % if ~isempty(params.paramsStruct)
    %     sampleRate = params.sampleRate;
    %     totalTicks = params.totalTicks;
    %     display = params.display;
    %     params = params.paramsStruct;
    %     params.sampleRate = sampleRate;
    %     params.totalTicks = totalTicks;
    %     params.display = display;
    % end
    
    if ~contains(p.UsingDefaults, 'totalTicks')
        stim = StimGenerator.GetBaseFromTicks(params.totalTicks);
    elseif params.duration ~= -1 
    stim = StimGenerator.GetBase(params.totalTicks, params.duration, params.sampleRate);
    elseif ~contains(p.UsingDefaults, 'paramsStruct')
        stim = StimGenerator.GetBase(params.totalTicks, max(params.paramsStruct.dStimulus), params.sampleRate);
    elseif ~contains(p.UsingDefaults, 'dStimulus')
        stim = StimGenerator.GetBase(params.totalTicks, max(params.dStimulus), params.sampleRate);
    else
        error('please specify either the total stimulus ticks or the stimulus duration')
    end

    fs = params.sampleRate;
        if ~isempty(params.paramsStruct)
        N = params.paramsStruct.NeutralTemp;
        C = params.paramsStruct.SetpointTemp;
        D = params.paramsStruct.dStimulus;
        V = params.paramsStruct.PacingRate;
        R = params.paramsStruct.ReturnSpeed;
        S = params.paramsStruct.SurfaceSelect;
    else
        N = params.NeutralTemp;
        C = params.SetpointTemp;
        D = params.dStimulus;
        V = params.PacingRate;
        R = params.ReturnSpeed;
        S = params.SurfaceSelect;
    end
    

    tax = linspace(1/fs, length(stim)/fs, length(stim));
    stim = ones(length(tax),5) * N;
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
        stim(t0+(1:tmp)-1,ii) = pulse(1:tmp);
    end

    %% TODO
    if params.display
        StimGenerator.show(stim);
    end
end

function stim = thermalPulsePreview(varargin)
    % Generates a thermal preview stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    %     display     (logical=false): whether to display the generated stimulus
    % PARAMS (THERMAL):
    %     paramsStruct   (struct): structure of parameters for thermal stimulus
    %        If provided, will override individual parameters (below)
    %     NeutralTemp (double=32): neutral temperature (°C)
    %     PacingRate  (double=300): pacing rate (ms)
    %     ReturnSpeed (double=300): return speed (ms)
    %     SetpointTemp (double=32): setpoint temperature (°C)
    %     SurfaceSelect (vector[1x5]=[1 1 0 0 0]): surface select (1=on, 0=off)
    %     dStimulus   (double=2000): stimulus duration (ms)
    %     integralTerm (double=1): integral term
    %     nTrigger    (double=1): number of triggers
    %     VibrationDuration (double=0): vibration duration (ms)

    p = inputParser();
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x)); 
    addParameter(p, 'display', false, @(x) islogical(x));

    addParameter(p, 'NeutralTemp', 32, @(x) isnumeric(x));
    addParameter(p, 'PacingRate', 300, @(x) isnumeric(x));
    addParameter(p, 'ReturnSpeed', 300, @(x) isnumeric(x));
    addParameter(p, 'SetpointTemp', 32, @(x) isnumeric(x));
    addParameter(p, 'SurfaceSelect', [1 1 0 0 0], @(x) isnumeric(x) && isvector(x) && length(x) == 5);
    addParameter(p, 'dStimulus', 2000, @(x) isnumeric(x));
    addParameter(p, 'VibrationDuration', 0, @(x) isnumeric(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;
    
    fs = params.sampleRate;
    outs = [];
    S = [];
    % legacy consideration nonsense
    for f = {"NeutralTemp", "SetpointTemp", "dStimulus", "PacingRate", "ReturnSpeed", "SurfaceSelect"}
        fname = f{:};
        if ~isempty(params.paramsStruct)
            if isfield(params.paramsStruct, 'commands')
                sln = params.paramsStruct.commands.(fname);
            else
                sln = params.paramsStruct.(fname);
            end
        else
            sln = params.(fname);
        end
        if strcmpi(fname, 'surfaceselect')
            S = sln;
        else
            outs(end+1) = sln;
        end
    end
    N = outs(1);
    C = outs(2);
    D = outs(3);
    V = outs(4);
    R = outs(5);
    stim = StimGenerator.GetBase(params.totalTicks, D, params.sampleRate);


    stim = ones(length(stim),1) * N;

    dP    = (D*fs/1000)-1;
    pulse = ones(dP,1);
    dV    = round(abs(C-N)/V*fs);
    dR    = round(abs(C-N)/R*fs);
    tmp   = linspace(0,1,dV)';
    pulse(1:min([dV dP])) = tmp((1:min([dV dP])));
    pulse = [pulse; linspace(pulse(end),0,dR)'] * (C-N) + N;
    
    % tmp   = min([round((params.totalTicks/params.sampleRate)*fs)+1 length(pulse)]);
    % stim = pulse(1:tmp);

    stim = pulse';
    % stim = stim';

    %% TODO
    if params.display
        StimGenerator.show(stim);
    end
end

function stim = serialTrigger(varargin)
    % Generates a serial trigger stim of given length
    % PARAMS:
    %     sampleRate (double=1000): sample rate of output array (Hz)
    %     duration   (double=1000): duration of output (ms)
    %     totalTicks (double=1000): duration of output in total ticks. Alternative to duration. 
    %         When both are defined, duration will be limited to within totalTicks. 
    %     nTriggers (double = 1): 
    %     stimDur   (double=1000): 
    % paramsStruct
    p = inputParser();
    addParameter(p, 'display', false, @(x) islogical(x));
    addParameter(p, 'sampleRate', 1000, @(x) isnumeric(x));
    addParameter(p, 'totalTicks', 1000, @(x) isnumeric(x));
    addParameter(p, 'duration', -1, @(x) isnumeric(x));
    addParameter(p, 'paramsStruct', [], @(x) isstruct(x));
    parse(p, varargin{:});
    params = p.Results;

    if ~isempty(params.paramsStruct)
        sampleRate = params.sampleRate;
        totalTicks = params.totalTicks;
        display = params.display;
        params = params.paramsStruct;
        params.sampleRate = sampleRate;
        params.totalTicks = totalTicks;
        params.display = display;
    end

    stim = StimGenerator.GetBase(params.totalTicks, params.duration(1), params.sampleRate);
    stim(1:length(stim)/2) = 1;

    if params.display
        StimGenerator.show(stim);
    end
end

%% HELPER METHODS
function out = MsToTicks(x, rate)
    out = round(x*rate/1000);
end

function out = TicksToMs(x, rate)
    out = x*1000/rate;
end

function out = GetBase(totalTicks, durationMs, sampleRate)
    % contains(p.UsingDefaults, 'totalTicks')
    if durationMs ~= -1
        out = zeros(round(StimGenerator.MsToTicks(durationMs, sampleRate)), 1);
    else
        out = zeros(totalTicks, 1);
    end
end

function p = show(stim)
    tax = linspace(1, length(stim), length(stim));
    p = plot(tax, stim);
    % p.YLim = [min(stim) max(stim)] + [-1 1]*max([range(stim)*.1 .5]);
end
end
end
