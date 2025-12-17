function [p,g] = readProtocol(filename,varargin)

% TODO validate hardware is not targeted by two functions simultaneously

%% parse function inputs
ip = inputParser;
addRequired(ip,'filename',...
    @(x)validateattributes(x,{'char'},{'nonempty'}));
addOptional(ip, 'verbose',  false, @islogical)
parse(ip,filename,varargin{:});
verboseMode = (isfield(ip.Results, 'verbose') && ip.Results.verbose);

%% read file
if ~exist(ip.Results.filename,'file')
    error('File not found: %s',ip.Results.filename)
end
pathBase = ip.Results.filename(1:find(ip.Results.filename == filesep, 1,'last'));
fid   = fopen(ip.Results.filename);
lines = textscan(fid,'%s','Delimiter','\n','MultipleDelimsAsOne',1);
fclose(fid);
lines = lines{1};

%% remove comment lines
lines(cellfun(@(x) strcmp(x(1),'%'),lines)) = [];

[g, defaultTrial, validTrialParams, validStimBlockParams, ...
    BaseStimStructs, validProtocolParams] = generateDefaults();
[splitIdxes, trialParams, stimDefinitions] = SplitFile(lines);
% establish constants
sepQuery = '&|>|(\|>)|(\|)|(\^\.\d?)';
sepPlusQ = ['(' sepQuery '|\s|\(|\)|^|$' ')'];

% if verboseMode, try/catch. Else error
try
    [g, defaultTrial] = ParseGeneral(splitIdxes, lines, g, defaultTrial);
    [stimuli, acquisitionTriggers, stimulusGroups] = ParseStimuli(stimDefinitions);
catch exception
    if verboseMode
        err = exception.message;
        return
    else
        rethrow(exception);
    end
end

trials = {};
for idxTrial = 1:length(trialParams)
    trialLine = trialParams{idxTrial};
    try
        [trial, parameters] = InitialiseTrial(trialLine, stimulusGroups, defaultTrial, idxTrial);
        trial = ParseTrial(trial, parameters, stimuli, validTrialParams, ...
            validStimBlockParams);
        trial.valid = true;
    catch exception
        if verboseMode
            trial.valid = false;
            trial.errorMsg = exception.message;
        else
            rethrow(exception)
        end
    end
    trials{end+1} = trial;
end
p = [trials{:}];

    function [g, defaultTrial, validTrialParams, validStimBlockParams, ...
            BaseStimStructs, validProtocolParams] = generateDefaults()
    % Get defaults
    g = struct(...              % general parameters
        'dPause',               5,...
        'nProtRuns',            1,...
        'rand',                 0, ...
        'prePause',             0);
    defaultTrial = struct( ...
        'nRuns',                1, ...
        'tPre',                 1000, ...
        'tPost',                5000);
    
    validTrialParams = struct("tPre", false, ... % param and whether it's already been initialised
        "tPost", false, ...
        "nTrialRuns", false);
    
    validStimBlockParams = struct(...
        "OddDistr", false, ...
        "OddMinDist", false, ...
        "RepDel", false, ...
        "nStims", false, ...
        "StartDel", false);
    
    function st1 = addCommonFields(st1)
        % adds all fields and values in st2 to st1
        % if they are not already defined in st1
        standardStimStruct = struct( ...
            'type', '', ...
            'identifier', '', ...
            'targetDevices', [], ...
            'isAcquisitionTrigger', false, ...
            'duration', 0);
    
        fs = fields(standardStimStruct);
        for i = 1:length(fs)
            if ~isfield(st1, fs{i})
                st1.(fs{i}) = standardStimStruct.(fs{i});
            end
        end
    end
    
    BaseStimStructs = struct(...
        'qst', addCommonFields(struct( ...
            'identifier', 'QST', ....
            'type', 'serial', ...
            'targetDevices', ["QST"], ...
            'commands', struct(...
                'NeutralTemp',          32,...    
                'PacingRate',           ones(1,5) * 999,...
                'ReturnSpeed',          ones(1,5) * 999,...
                'SetpointTemp',         ones(1,5) * 32,...
                'SurfaceSelect',        true(1,5),...
                'dStimulus',            ones(1,5) * 1000,...
                'integralTerm',         1,...
                'nTrigger',             255,...
                'VibrationDuration',    0))), ...
        'serial', addCommonFields(struct( ...
            'type', 'serial', ...
            'isAcquisitionTrigger', false, ...
            'duration', 0, ...
            'commands', [])), ...
        'pwm', addCommonFields(struct( ...
            'type', 'PWM', ...
            'rampUp', 0, ...
            'rampDown', 0, ...
            'frequency', 25, ...
            'dutyCycle', 50)), ...
        'piezo', addCommonFields(struct( ...
            'identifier', 'piezoStim', ....
            'type', 'piezo', ...
            'targetDevices', ["Aurora"], ...
            'frequency', 0, ...
            'stimNum', 0, ...
            'amplitude', 0, ...
            'ramp', 20, ...
            'nStims', 1)), ...
        'digitaltrigger', addCommonFields(struct( ...
            'type', 'digitalTrigger', ...
            'frequency', 20)), ...
        'digitalpulse', addCommonFields(struct( ...
            'type', 'digitalPulse',...
            'alignRight', false)), ...
        'omission', addCommonFields(struct( ...
            'type', 'omission')), ...
        'analogpulse', addCommonFields(struct( ...
            'type', 'analogPulse', ...
            'rampOn', 0, ...
            'rampOff', 0, ...
            'baseAmp', 0, ...
            'pulseAmp', 10)), ...
        'sinewave', addCommonFields(struct( ...
            'type', 'sineWave', ...
            'amplitude', 0, ...
            'frequency', 30, ...
            'phase', 0, ...
            'verticalShift', 0, ...
            'amplitudeMod', 1)), ...
        'analognoise', addCommonFields(struct( ...
            'type', 'analogNoise', ...
            'maxAmplitude', 10, ...
            'minAmplitude', -10, ...
            'distribution', 'normal')), ... %either normal or uniform
        'arbitrary', addCommonFields(struct( ...
            'type', 'arbitrary', ...
            'filename', '', ...
            'interpolate', false)), ...
        'squarewave', addCommonFields(struct( ...
            'type', 'squareWave', ...
            'frequency', 20, ...
            'pulseWidth', 0.5, ...
            'maxAmp', 10, ...
            'minAmp', -10)), ... %TODO RAMP???
         'stimulusgroup', struct( ...
             'isAcquisitionTrigger', true, ...
             'type', 'stimulusGroup', ...
             'identifier', '', ...
             'line', [], ...
             'subtree', {})); 
    
    validProtocolParams = struct(... %fields: valid params in protocol file. values: associated internal struct params.
        'pwm', struct( ...
            'Dur', 'duration', ...
            'Freq', 'frequency', ...
            'DC', 'dutyCycle', ...
            'RampOnDur', 'rampUp', ...
            'RampOffDur', 'rampDown'), ...
        'piezo', struct(...
            'Dur', 'duration', ...
            'Freq', 'frequency', ...
            'stimNum', 'stimNum', ...
            'Amp', 'amplitude', ...
            'Ramp', 'ramp', ...
            'nStims', 'nStims'), ...
        'digitaltrigger', struct(  ...
            'Dur', 'duration', ...
            'Freq', 'frequency'), ...
        'digitalpulse', struct( ...
            'Dur', 'duration', ...
            'FromEnd', 'alignRight'), ...
        'omission', struct( ...
            'Dur', 'duration'), ...
        'analogpulse', struct(...
            'Dur', 'duration', ...
            'RampOnDur', 'rampOn', ...
            'RampOffDur', 'rampOff', ...
            'PulseAmp', 'pulseAmp', ...
            'BaseAmp', 'baseAmp'), ...
        'sinewave', struct(...
            'Dur', 'duration', ...
            'Amp', 'amplitude', ...
            'Freq', 'frequency', ...
            'Phase', 'phase', ...
            'VerticalShift', 'verticalShift', ...
            'AmpMod', 'amplitudeMod'), ... %nb special case? todo, low prio, just don't implement for now
        'analognoise', struct( ...
            'Dur', 'duration', ...
            'MaxAmp', 'maxAmplitude', ...
            'MinAmp', 'minAmplitude', ...
            'Distr', 'distribution'), ... 
        'arbitrary', struct( ...
            'Dur', 'duration', ...
            'Src', 'filename', ... %nb special case
            'Interp', 'interpolate'), ...
        'squarewave', struct( ...
            'Dur', 'duration', ...
            'MaxAmp', 'maxAmp', ...
            'MinAmp', 'minAmp', ...
            'Freq', 'frequency', ...
            'PW', 'pulseWidth'));
    end

    function [splitIdxes, trialParams, stimDefinitions] = SplitFile(lines)
    % splits trial into three sections
        splitIdxes = find(startsWith(lines, '~'));
        if length(splitIdxes) ~= 2
            error("Sections should be separated with a tilde (~) character on a new line. " + ...
                "Refer to the wiki for a full overview of formatting requirements: " + ...
                "https://github.com/WhitmireLab/StimControl/wiki/Protocols");
        end
        
        trialParams = lines(splitIdxes(1)+1:splitIdxes(2)-1);
        stimDefinitions = lines(splitIdxes(2)+1:end);
    end

    function [g, defaultTrial] = ParseGeneral(splitIdxes, lines, g, defaultTrial)
        % parse general specs
        if splitIdxes(1) > 1
            if splitIdxes(1) > 2
                error("General params should be defined in a single line.");
            end
            generalParams = lines{1:splitIdxes(1)-1};
            [generalParams,~]  = strtok(generalParams,'%');
            generalParams      = strtrim(generalParams);
            while ~isempty(generalParams)
                [token,generalParams] = strtok(generalParams); %#ok<STTOK>
                tmp = regexpi(token,'^([a-z]+)(-?\d+)$','once','tokens');
                if ~isempty(tmp)
                    val = str2double(tmp(2));
                    switch lower(tmp{1})
                        case 'nprotruns'
                            validateattributes(val,{'numeric'},{'positive'},...
                                mfilename,token)
                            g.nProtRuns = val;
                            continue
                        case 'rand'
                            validateattributes(val,{'numeric'},{'nonnegative',...
                                '<=',2},mfilename,token)
                            g.rand = val;   
                            continue
                        case 'dpause'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            g.dPause = val/1000; % ms to s
                            continue
                        case 'ntrialruns'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            defaultTrial.nRuns = val;
                            continue
                        case 'tpre'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            defaultTrial.tPre = val;
                            continue
                        case 'tpost'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            defaultTrial.tPost = val;
                            continue
                        case 'tpostonset'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            defaultTrial.tPost = val;
                            continue
                        case 'prepause'
                            validateattributes(val,{'numeric'},{'nonnegative'},...
                                mfilename,token)
                            g.prePause = logical(val);
                            continue
                    end
                end
                error('Unknown parameter "%s"',token)
            end
        end
    end

    function [stimuli, acquisitionTriggers, stimulusGroups] = ParseStimuli(stimDefinitions)
        % parse stimulus definitions
        stimuli = [];
        acquisitionTriggers = [];
        stimulusGroups = [];
        
        for idxStim = 1:length(stimDefinitions)
            line = stimDefinitions{idxStim};
            % todo support for targeting specific channels connected to the same defice (e.g. Widefield1_Trigger)
            % note - this is way harder than it sounds. We're gonna name our channels individually for now.
            tmp = regexpi(line, '([A-z])*\((\w)+\)\[((\w)(-\w)?,? ?)+\]: ?(.*)(%.*)?', 'tokens', 'once'); 
            % note to future devs: sorry about this ^. There are some regex testers out there that can help with reading this.
            % I've been using https://regexr.com/
            [stimID, stimType, targets, params, comment] = tmp{:};
            stimType = lower(stimType);
            if isfield(stimuli, stimID) || isfield(stimulusGroups, stimID)
                error("Stimulus defined twice: %s", stimID);
            end
            if ~contains(fields(BaseStimStructs), stimType)
                error("Unknown stimulus type: %s. Valid types: %s", stimType, GetListFromArray(fields(BaseStimStructs)));
            end
            % special cases
            switch lower(stimType)
                case 'qst'
                    stimStruct = ParseQST(params, BaseStimStructs.(stimType), stimID);
                case 'serial'
                    stimStruct = ParseSerial(params, BaseStimStructs.(stimType), stimID);
                case 'stimulusgroup'
                    %TODO: 
                    % check that all params within the stimulus group are defined.
                    % replace all tokens that map to another stimulus group with the text of that stimulus group
                    % check the stimulus group name doesn't cause logic problems (no other stimulusgroup contains this one's name in its entirety and vice versa)
                    stimulusGroups.(stimID) = params;
                otherwise
                    % standard cases
                    stimStruct = BaseStimStructs.(stimType);
                    while ~isempty(params)
                        [tok, remain] = strtok(params);
                        pv = regexpi(tok, '([A-z]*)(-?\d*.?\d*)', 'tokens', 'once');
                        [param, val] = pv{:};
                        if strcmpi(param, 'acquisitiontrigger')
                            stimStruct.isAcquisitionTrigger = true;
                            params = remain;
                            continue
                        elseif isempty(val) || isnan(str2double(val))
                            if strcmpi(stimType, 'arbitrary')
                                % probably the filename
                                param = 'Src';
                                val = tok;
                                if ~contains(val, filesep)
                                    % expand to full filepath
                                    val = [pathBase val];
                                end
                            else
                                error("No value provided for %s: %s", stimID, stimType);
                            end
                        elseif ~any(contains(fields(validProtocolParams.(stimType)), param))
                            error("Invalid parameter for %s: %s. Valid parameters are: %s", ...
                                stimID, param, GetListFromArray(fields(validProtocolParams.(stimType))));
                        end
                        val = ValidateParam(val, param, stimID);
                        stimStruct.(validProtocolParams.(stimType).(param)) = val;
                        params = strtrim(remain);
                    end
            end
            stimuli.(stimID) = stimStruct;
            if contains(targets, ',')
                targets = string(strtrim(split(targets, ',')))';
            end
            stimuli.(stimID).targetDevices = string(targets); % todo convert to array of strings if length > 1
            if stimuli.(stimID).isAcquisitionTrigger
                acquisitionTriggers.(stimID) = stimuli.(stimID);
            end
        end
    end

    function [trial, params] = InitialiseTrial(trialLine, stimulusGroups, defaultTrial, ...
            idxTrial)
        [params, comment] = strtok(trialLine, '%');
        params = strtrim(params);
        comment = strtrim(comment(2:end));
        
        % replace stimulus groups with definitions
        % todo optimise this is worst case O(n^2) at LEAST
        if ~isempty(stimulusGroups)
            sfs = fields(stimulusGroups);
            while any(contains(params, fields(stimulusGroups)))
                for sfi = 1:length(sfs)
                    sgFieldName = sfs{sfi};
                    idx = regexpi(params, [sepPlusQ '(' sgFieldName ')' sepPlusQ]);
                    if ~isempty(idx)
                        for idxi = idx
                            params = [params(1:idxi-1) ...
                                '(' stimulusGroups.(sgFieldName) ')' ...
                                params(length(sgFieldName)+idxi:end)];
                        end
                    end
                end
            end
        end
    
        % Sanitise line (add spaces around everything)
        [startIdxes, endIdxes] = regexpi(params, [sepQuery '|\)|\(']);
        for i = length(startIdxes):-1:1
            startIdx = startIdxes(i);
            endIdx = endIdxes(i);
            if endIdx ~= length(params) && ~strcmpi(params(endIdx + 1), ' ')
                params = insertAfter(params, endIdx, ' ');
            end
            if startIdx ~= 1 && ~strcmpi(params(startIdx - 1), ' ')
                params = insertBefore(params, startIdx, ' ');
            end
        end
    
        % initialise stack vars
        trial = TrialData( ...
            'tPre', defaultTrial.tPre, ...
            'tPost', defaultTrial.tPost, ...
            'nRuns', defaultTrial.nRuns, ...
            'comment', comment, ...
            'line', trialLine);
        trial.trialIdx = idxTrial;
    end

    function trial = ParseTrial(trial, params, stimuli, validTrialParams, ...
            validStimBlockParams)
        % Parse a single line of a trial.
        trialParamsTracker = validTrialParams;
        stack = java.util.Stack;
        tree = {StimulusBlock('childRel', 'sim', 'childIdxes', [2 3]), ...  % root node
            StimulusBlock('childRel', 'sim', 'parentIdx', 1), ...           % acquisition trigger node
            StimulusBlock('parentIdx', 1)};                                 % stimulus trigger node
        acquisitionIdx = 2;
        stimNodeIdx = 3;
        stack.push(stimNodeIdx); % push stim node index to stack
    
        paramTokens = split(params, ' ');
    
        % ENTER THE STACK ZONE
        for i = 1:length(paramTokens)
            token = paramTokens{i};
            if isempty(token)
                % probably a double space.
                continue
            end
            name = []; value = [];
            tmp = regexpi(token, '([A-z]*)(\d*)', 'tokens');
            if ~isempty(tmp)
                tmp = tmp{:};
                name = tmp{1};
                value = tmp{2};
                value = str2double(value);
            end
            currentParentIdx = stack.pop();
            currentParent = tree{currentParentIdx};
            % do the stuff that doesn't require parsing first because otherwise we'll throw an error
            if token == '('
                % Start of a new block. Make a new parent node.
                stack.push(currentParentIdx);
                tree{end+1} = StimulusBlock('parentIdx', currentParentIdx);
                currentParent.childIdxes(end+1) = length(tree);
                tree{currentParentIdx} = currentParent;
                stack.push(length(tree));
                continue
            elseif token == ')'
                % End of a block. Remove the parent's index from the stack and
                % update the next parent's child indices.
                newParentIdx = stack.pop();
                currentParent = tree{newParentIdx};
                currentParent.childIdxes(end+1) = currentParentIdx;
                currentParentIdx = newParentIdx;
            elseif regexpi(token, sepQuery)
                % Separator. Set parent's child relationship
                if token(1) == '&'
                    childRel = 'sim';
                elseif token(1) == '>'
                    childRel = 'seq';
                elseif token(1) == '|'
                    if strcmpi(token, '|>')
                        childRel = 'oddSeq';
                    else
                        childRel = 'oddRand';
                    end
                else % ^.X
                    childRel = 'odd';
                    currentParent.oddParams.swapRatio = str2double(['0.' token(3:end)]);
                end
                if ~isempty(currentParent.childRel) && ~strcmpi(currentParent.childRel, childRel)
                    error("Syntax error in trial line %d (%s): Only one relationship type may exist per stim block. " + ...
                        "In oddball paradigms with multiple oddballs, put all oddball " + ...
                        "stimuli into their own bracket block within the oddball block."+ ...
                        "(relationships defined: %s, %s)", ...
                        trial.trialIdx, trial.comment, currentParent.childRel, childRel); 
                else
                    currentParent.childRel = childRel;
                end
                % update parent in tree
                tree{currentParentIdx} = currentParent;
            elseif isfield(stimuli, token) || (~isempty(name) && isfield(stimuli, name))
                % leaf (stimulus) node. Create child node and push, add index to current parent
                % Unless acquisition trigger, in which case add to acquisitiontrigger node 
                if stimuli.(token).isAcquisitionTrigger
                    if ~strcmpi(currentParent.childRel, 'sim') && ~isempty(currentParent.childRel) % todo this doesn't check the whole way up. Document that isAcquisitionTrigger is separate
                        error("Syntax error in trial line %d (%s): " + ...
                            "Stimuli marked as AcquisitionTrigger cannot occur within sequential or oddball relationships",  ...
                            trial.trialIdx, trial.comment);
                    end
                    newNode = StimulusBlock('stimParams', stimuli.(token), ...
                        'parentIdx', acquisitionIdx);
                    acqNode = tree{acquisitionIdx};
                    tree{end+1} = newNode;
                    acqNode.childIdxes(end+1) = length(tree);
                    tree{acquisitionIdx} = acqNode;
                else
                    newNode = StimulusBlock('stimParams', stimuli.(token), ...
                        'parentIdx', currentParentIdx);
                    tree{end+1} = newNode;
                    currentParent.childIdxes(end+1) = length(tree);
                    tree{currentParentIdx} = currentParent;
                end
            elseif isfield(trialParamsTracker, name)
                % set trial data (and check it hasn't already been set)
                if strcmpi(name, 'tpostonset')
                    name = 'tPost';
                end
                if trialParamsTracker.(name)
                    error("Invalid syntax on trial line %d (%s): %s can only be defined once per trial.", ...
                        trial.trialIdx, trial.comment, name);
                end
                trialParamsTracker.(name) = true;
                trial.(name) = value; % todo check this works all the time, I think it does
            elseif isfield(validStimBlockParams, name)
                % params for current parent! set em.
                switch lower(name)
                    case 'odddistr'
                        % some syntax checking
                        if ~strcmpi(currentParent.childRel, 'odd')
                            % gotta be an oddball to use this
                            error("Invalid syntax on trial definition line %d (%s): " + ...
                                "OddDistrX is set, but the relationship for its stimulus block is not oddball (^.X)", trial.trialIdx, trial.comment);
                        end
                        if value == 0
                            currentParent.oddParams.distributionMethod = 'even';
                        elseif value == 1
                            currentParent.oddParams.distributionMethod = 'random';
                        elseif value == 2
                            if (~isfield(currentParent.oddParams, 'distributionMethod') || ...
                                currentParent.oddParams.distributionMethod(1) ~= 's') && ...
                                ~contains(lower(params), 'oddmindist')
                                    % can't set semirandom without also setting a minimum distance
                                    error("Invalid syntax on trial definition line %d (%s): " + ...
                                        "to make oddball distribution semirandom, you must also define the minimum distance between oddballs using OddMinDistX. " + ...
                                        "Add this parameter or change to another OddDistr (0=even, 1=random, 2=semirandom)", trial.trialIdx, trial.comment);
                            end
                        else
                            error("Invalid syntax on trial definition line %d (%s): " + ...
                                "OddDistrX accepts X values 0=even, 1=random, 2=semirandom", trial.trialIdx, trial.comment);
                        end
                    case 'oddmindist'
                        % some syntax checking.
                        if ~strcmpi(currentParent.childRel, 'odd')
                            % gotta be an oddball to use this
                            error("Invalid syntax on trial definition line %d (%s): " + ...
                                "OddMinDistX is set, but the relationship for its stimulus block is not oddball (^.X).", trial.trialIdx, trial.comment);
                        elseif isfield(currentParent.oddParams, 'distributionMethod')
                            % shouldn't be set! likely the wrong kind of oddball distribution method.
                            error("Invalid syntax on trial definition line %d (%s): " + ...
                                "OddMinDistX is set, but the OddDistr value for its stimulus block is not semirandom (OddDistr2).", trial.trialIdx, trial.comment);
                        end
                        currentParent.oddParams.distributionMethod = ['semirandom' char(string(value))];
                    case 'repdel'
                        currentParent.repeatDelay = value;
                    case 'nstims'
                        currentParent.nStimRuns = value;
                    case 'startdel'
                        currentParent.startDelay = value;
                end
                tree{currentParentIdx} = currentParent;
            else
                % crime detected!
                if iscell(name)
                    name = name{:};
                end
                 error("Invalid parameter on trial definition line %d (%s): %s. " + ...
                    "Parameters must be a stimulus defined in the stimulus section " + ...
                    "or one of the following: %s, StartDel, RepDel, nStims, OddDistr, OddMinDist," + ...
                    "Stimulus names should only contain characters - digits and underscores are not supported.", ...
                    trial.trialIdx, trial.comment, name, GetListFromArray(fields(validTrialParams)));
            end
            % put parent back on the stack
            stack.push(currentParentIdx);
        end
        % todo throw error if same thing is targeted multiple times simultaneously
        stimRoot = tree{stimNodeIdx};
        stimRoot.startDelay = stimRoot.startDelay + trial.tPre;
        tree{stimNodeIdx} = stimRoot;
        trial.data = tree;
        trial.RootNodeIdx = 1;
        trial = trial.Clean;
        trial.generateParamsSequence;
        trial.ValidateTree;
    end

function stimStruct = ParseQST(params, stimStruct, stimName)
    while ~isempty(params)
        [tok, remain] = strtok(params);
        switch tok(1)
            case 'N'
                fieldname = 'NeutralTemp';
                value     = readRangeThermode(tok,2:4,[200 500],stimName)/10;
            case 'S'
                fieldname = 'SurfaceSelect';
                value     = tok(2:6)=='1';
            case 'C'
                fieldname = 'SetpointTemp';
                value     = readRangeThermode(tok,3:5,[0 600],stimName)/10;
            case 'V'
                fieldname = 'PacingRate';
                value     = readRangeThermode(tok,3:6,[1 9990],stimName)/10;
            case 'R'
                fieldname = 'ReturnSpeed';
                value     = readRangeThermode(tok,3:6,[100 9990],stimName)/10;
            case 'D'
                fieldname = 'dStimulus';
                value     = readRangeThermode(tok,3:7,[10 99999],stimName);
            case 'T'
                fieldname = 'nTrigger';
                value     = readRangeThermode(tok,2:4,[0 255],stimName);
            case 'I'
                fieldname = 'integralTerm';
                value     = tok(2)=='1';
        end
        stimStruct.commands.(fieldname) = value;
        params = remain;
    end
end

function value = readRangeThermode(token,pos,range,stimName)
value = str2double(token(pos));
if value<range(1) || value>range(2)
    x = sprintf('%%0%dd',max(arrayfun(@(x) length(num2str(x)),range)));
    format = subsasgn(token,struct('type','()','subs',{{pos}}),'X');
    error(['Faulty parameter "%s" for stimulus #%d (%s, valid ' ...
        'range for %s: ' x '-' x ')'],token,stimName,format,...
        repmat('X',1,length(pos)),range(1),range(2))
end
end

function val = ValidateParam(val, paramName, stimName)
    if ~strcmpi(paramName, 'src')
        val = str2double(val);
    end
    switch lower(paramName)
    case 'dur'
        if ~val>0 && v~=-1
            error("Invalid duration for %s: %s. Duration should be a positive number of ms, or -1", stimName, val);
        end
    case 'freq'
        if ~val>0
            error("Invalid frequency for %s: %s. Frequency should be positive.", stimName, val);
        end
    case 'src'
        % check if filepath exists
        if ~isfile(val)
            error("Unable to find file %s for %s.", val, stimName);
        end
    case 'distr'
        if val == 1
            val = 'normal';
        elseif val == 0
            val = 'uniform';
        else
            error("Invalid distribution for %s: %d. Distribution can be 0 (uniform) or 1 (normal).", stimName, val);
        end
    end
end

function out = GetListFromArray(A)
    commas = repmat([", "], size(A));
    commas(end) = "";
    s = size(A);
    if s(1) == 1
        A = A';
        commas = commas';
    end
    arr = horzcat(A, commas);
    arr = append(arr(:,1), arr(:,2));
    out = strjoin(arr');
end
end



% function checkRange(value,range,token,idxStim)
% if value<range(1) || value>range(2)
%     error(['Faulty parameter "%s" for stimulus #%d (expecting value ' ...
%         'to be within %d-%d)'],token,idxStim,range(1),range(2))
% end
% end