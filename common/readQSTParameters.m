function [p,g,m] = readQSTParameters(filename,varargin)

m = [];

%% parse inputs
ip = inputParser;
addRequired(ip,'filename',...
    @(x)validateattributes(x,{'char'},{'nonempty'}))
addOptional(ip,'nThermodes',2,...
    @(x)validateattributes(x,{'numeric'},{'scalar','real','>',0,'<',5}));
parse(ip,filename,varargin{:});

%% read file
if ~exist(ip.Results.filename,'file')
    error('File not found: %s',ip.Results.filename)
end
fid   = fopen(ip.Results.filename);
lines = textscan(fid,'%s','Delimiter','\n','MultipleDelimsAsOne',1);
fclose(fid);
lines = lines{1};

%% remove comment lines
lines(cellfun(@(x) strcmp(x(1),'%'),lines)) = [];

%% define fieldnames for thermodes
fnThermodes = arrayfun(@(x) sprintf('thermode%s',64+x),...
	1:ip.Results.nThermodes,'UniformOutput',0);

%% define defaults
g = struct(...              % general parameters
    'dPause',               5,...
    'nProtRep',             1,...
    'randomize',            0);
tmp = struct(...            % thermodes
    'NeutralTemp',          32,...    
    'PacingRate',           ones(1,5) * 999,...
    'ReturnSpeed',          ones(1,5) * 999,...
    'SetpointTemp',         ones(1,5) * 32,...
    'SurfaceSelect',        true(1,5),...
    'dStimulus',            ones(1,5) * 1000,...
    'integralTerm',         1,...
    'nTrigger',             255,...
    'VibrationDuration',    0);
p = struct(...              % timing / repetitions / LED
    'Comments',             '',...
    'tPre',                 1000,...
    'tPost',                2000,...
	'nRepetitions',         1,...
    'ledDuration',          0,...
    'ledFrequency',         25,...
    'ledDutyCycle',         50,...
    'ledDelay',             0,...
    'piezoFreq',       0,... %added 2022.03.18
    'piezoStimNum',         0,... %added 2022.03.18
    'piezoDur',         0,... %added 2024.11.15 (for Aurora)
    'piezoAmp',             0); %added 2022.03.18
for fn = fnThermodes
    p.(fn{:}) = tmp;
end
p = repmat(p,1,1000);

%% parse general specs - on first line only
if regexpi(lines{1},'(nProtRep)|(randomize)|(dPause)')
    remain      = lines{1};
    [remain,~]  = strtok(remain,'%');
    remain      = strtrim(remain);
    while ~isempty(remain)
        [token,remain] = strtok(remain); %#ok<STTOK>
        tmp = regexpi(token,'^([a-z]+)(-?\d+)$','once','tokens');
        if ~isempty(tmp)
            val = str2double(tmp(2));
            switch lower(tmp{1})
                case 'nprotrep'
                    validateattributes(val,{'numeric'},{'positive'},...
                        mfilename,token)
                    g.nProtRep = val;
                    continue
                case 'randomize'
                    validateattributes(val,{'numeric'},{'nonnegative',...
                        '<=',2},mfilename,token)
                    g.randomize = val;
                    continue
                case 'dpause'
                    validateattributes(val,{'numeric'},{'nonnegative'},...
                        mfilename,token)
                    g.dPause = val;
                    continue
            end
        end
        error('Unknown parameter "%s"',token)
    end
    lines(1) = [];
end

%% parse stimulus definitions
for idxStim = 1:length(lines)
    remain = lines{idxStim};
    
    % clip comments (indicated by '%')
    [remain,tmp] = strtok(remain,'%');
    if ~isempty(tmp)
        p(idxStim).Comments = cell2mat(regexp(tmp,'^[\s%]*(.*?)\s*$','tokens','once'));
        remain = strtrim(remain);
    end
       
    while ~isempty(remain)
        % obtain the next token
        [token,remain] = strtok(remain); %#ok<STTOK>

        % check if token refers to thermode. If so, switch to subroutine
        if regexpi(token,'^(I[01]|[NT]\d{3}|C\d{4}|S[01]{5}|[VR]\d{5}|D\d{6}|VibDur\d*)[A-Z]?$','once')
            p = parseThermode(p,token,idxStim,fnThermodes);
            continue
        end
            
        % parse remaining tokens
        tmp = regexpi(token,'^([a-z]+)(-?\d+)$','once','tokens');
        if ~isempty(tmp)
            val = str2double(tmp(2));
            switch lower(tmp{1})
                case 'tpre'
                    validateattributes(val,{'numeric'},{'positive'},...
                        mfilename,token,idxStim)
                    p(idxStim).tPre  = val;
                    continue
                case 'tpost'
                    validateattributes(val,{'numeric'},{'positive'},...
                        mfilename,token,idxStim)
                    p(idxStim).tPost = val;
                    continue
                case 'ttact'
                    p(idxStim).tTactile = val;
                    continue
                case 'dtact'
                    validateattributes(val,{'numeric'},{'nonnegative'},...
                        mfilename,token,idxStim)
                    p(idxStim).dTactile = val;
                    continue
                case 'nrep'
                    validateattributes(val,{'numeric'},{'nonnegative'},...
                        mfilename,token,idxStim)
                    p(idxStim).nRepetitions = val;
                    continue
                case 'leddur'
                    validateattributes(val,{'numeric'},{'nonnegative'},...
                        mfilename,token,idxStim)
                    p(idxStim).ledDuration = val;
                    continue
                case 'ledfreq'
                    validateattributes(val,{'numeric'},{'positive'},...
                        mfilename,token,idxStim)
                    p(idxStim).ledFrequency = val;
                    continue
                case 'leddc'
                    validateattributes(val,{'numeric'},{'>=',0,'<=',100},...
                        mfilename,token,idxStim)
                    p(idxStim).ledDutyCycle = round(val);
                    continue
                case 'leddelay'
                    validateattributes(val,{'numeric'},{},...
                        mfilename,token,idxStim)
                    p(idxStim).ledDelay = val;
                    continue
                case 'piezofreq'%added 2022.03.18
                    validateattributes(val,{'numeric'},{},...
                        mfilename,token,idxStim)
                    p(idxStim).piezoFreq = val;
                    continue
                case 'piezoamp'%added 2022.03.18
                    validateattributes(val,{'numeric'},{},...
                        mfilename,token,idxStim)
                    p(idxStim).piezoAmp = val;
                    continue
                case 'piezodur'%added 2024.11.15
                    validateattributes(val,{'numeric'},{},...
                        mfilename,token,idxStim)
                    p(idxStim).piezoDur = val;
                    continue
                case 'piezostimnum'
                    validateattributes(val,{'numeric'},{},...
                        mfilename,token,idxStim)
                    p(idxStim).piezoStimNum = val;
                    continue
            end
        end

        % if the token was not recognized, throw an error
        error('Unknown parameter "%s" for stimulus #%d',token,idxStim)
    end
end
p(idxStim+1:end) = [];
[p, g] = ConvertToStimControlParameters(p, g);
end



function p = parseThermode(p,token,idxStim,fnThermodes)

% Read the parameter's value, define the fieldname and wether the parameter
% applies to multiple surfaces of the thermode
if ~isempty(regexpi(token,'vibdur'))
    fieldname = 'VibrationDuration';
    value     = cellfun(@str2double,regexpi(token,'vibdur(\d*)','tokens'));
    multiSurf = false;
else
    switch token(1)
        case 'N'
            fieldname = 'NeutralTemp';
            value     = readRangeThermode(token,2:4,[200 500],idxStim)/10;
            multiSurf = false;
        case 'S'
            fieldname = 'SurfaceSelect';
            value     = token(2:6)=='1';
            multiSurf = false;
        case 'C'
            fieldname = 'SetpointTemp';
            value     = readRangeThermode(token,3:5,[0 600],idxStim)/10;
            multiSurf = true;
        case 'V'
            fieldname = 'PacingRate';
            value     = readRangeThermode(token,3:6,[1 9990],idxStim)/10;
            multiSurf = true;
        case 'R'
            fieldname = 'ReturnSpeed';
            value     = readRangeThermode(token,3:6,[100 9990],idxStim)/10;
            multiSurf = true;
        case 'D'
            fieldname = 'dStimulus';
            value     = readRangeThermode(token,3:7,[10 99999],idxStim);
            multiSurf = true;
        case 'T'
            fieldname = 'nTrigger';
            value     = readRangeThermode(token,2:4,[0 255],idxStim);
            multiSurf = false;
        case 'I'
            fieldname = 'integralTerm';
            value     = token(2)=='1';
            multiSurf = false;
    end
end

% Does the parameter apply to individual surfaces of the thermode?
% Obtain logical index for respective surface(s) ...
if multiSurf
    idxSurface = readRangeThermode(token,2,[0 5],idxStim);
    if ~idxSurface, idxSurface = 1:5; end
end

% Should the values by applied to a specific thermode? Define the
% respective fieldnames ...
if isstrprop(token(end),'alpha')
    tmp = cellfun(@(x) x(end),fnThermodes);
    if ~ismember(token(end),tmp)
      	format = token;
        format(end) = 'X';
        error(['Faulty parameter "%s" for stimulus #%d (%s, valid ' ...
            'values for X: %s)'],token,idxStim,format,tmp)
    end
    thermodes = {['thermode' upper(token(end))]};
else
    thermodes = fnThermodes;
end

% Loop through the thermodes and assign the value
for thermode = thermodes
    if multiSurf
        if ~isfield(p(idxStim).(thermode{:}),fieldname)
            p(idxStim).(thermode{:}).(fieldname) = NaN(1,5);
        end
        p(idxStim).(thermode{:}).(fieldname)(idxSurface) = value;
    else
        p(idxStim).(thermode{:}).(fieldname) = value;

    end
end

end


function value = readRangeThermode(token,pos,range,idxStim)
value = str2double(token(pos));
if value<range(1) || value>range(2)
    x = sprintf('%%0%dd',max(arrayfun(@(x) length(num2str(x)),range)));
    format = subsasgn(token,struct('type','()','subs',{{pos}}),'X');
    error(['Faulty parameter "%s" for stimulus #%d (%s, valid ' ...
        'range for %s: ' x '-' x ')'],token,idxStim,format,...
        repmat('X',1,length(pos)),range(1),range(2))
end
end

function [trialData, protocolData] = ConvertToStimControlParameters(p, g)
% convert to StimControl parameters
% OUTPUTS:
% g(struct): a struct with fields
%       dPause: time between trials (s)
%       nRuns: number of times trial should be run in a single protocol run
%       rand: how to randomise trials within the experiment.
% t(1xn TrialData array): where n is the number of trials in the protocol.
%   TrialData has attributes:
%       data (1xm cell array where m is the number of StimulusBlocks in each trial (always 1 in this case))
%       tPre: time before stimulus start (ms)
%       tPost: time to record after stimulus start (ms)
%       nRuns: number of times trial should be run in a single protocol run
%       comment: if given, a descriptive comment for each trial
    trialData = cell(1, length(p));
    
    % update fieldnames in g
    g.nProtRuns = g.nProtRep;
    g = rmfield(g, 'nProtRep');
    g.rand = g.randomize;
    g = rmfield(g, 'randomize');
    protocolData = g;
    g.targets = {"AllDevices"};

    thermodeStruct = struct(...
        'NeutralTemp',          32,...    
        'PacingRate',           ones(1,5) * 999,...
        'ReturnSpeed',          ones(1,5) * 999,...
        'SetpointTemp',         ones(1,5) * 32,...
        'SurfaceSelect',        true(1,5),...
        'dStimulus',            ones(1,5) * 1000,...
        'integralTerm',         1,...
        'nTrigger',             255,...
        'VibrationDuration',    0);

    QSTStimStruct = struct( ...
        'identifier', 'QST', ....
        'type', 'serial', ...
        'targetDevices', ["QST"], ...
        'isAcquisitionTrigger', false, ...
        'commands', thermodeStruct);
    cameraTriggerStruct = struct( ...
        'identifier', 'cameraTrigger', ....
        'type', 'digitalTrigger', ...
        'targetDevices', ["Widefield1", "Widefield2"], ...
        'isAcquisitionTrigger', true, ...
        'frequency', 60, ...
        'duration', 0);
    acqStartStruct = struct( ...
        'identifier', '2PStart', ...
        'type', 'digitalPulse', ...
        'targetDevices', ["TwoPhotonStart"], ...
        'duration', 1, ...
        'isAcquisitionTrigger', true);
    acqStopStruct = struct( ...
        'identifier', '2PStop', ...
        'type', 'digitalPulse', ...
        'targetDevices', ["TwoPhotonStop"], ...
        'duration', 2, ...
        'isAcquisitionTrigger', true, ...
        'alignRight', true);
    nextFileStruct = struct( ...
        'identifier', '2PNext', ...
        'type', 'digitalPulse', ...
        'targetDevices', ["TwoPhotonNext"], ...
        'isAcquisitionTrigger', true, ...
        'duration', 1);

    analogPulseStruct = struct( ...
        'identifier', 'piezoStim', ....
        'type', 'analogPulse', ...
        'targetDevices', ["Aurora"], ...
        'isAcquisitionTrigger', false, ...
        'frequency', 0, ...
        'duration', 0, ...
        'baseAmp', 0, ...
        'pulseAmp', 0, ...
        'rampOn', 2, ...
        'rampOff', 2, ...
        'nStims', 0);   
    squarewaveStruct = struct( ...
        'type', 'squareWave', ...
        'identifier', 'Aurora', ...
        'targetDevices', ["Aurora"], ...
        'isAcquisitionTrigger', false, ...
        'duration', 0, ...
        'frequency', 20, ...
        'pulseWidth', 0.5, ...
        'maxAmp', 10, ...
        'minAmp', -10);

    for tNum = 1:length(p)
        % fill in new datastruct
        pt = p(tNum);
        qs = QSTStimStruct;
        qs.commands = pt.thermodeA;
        
        % scale piezo
        Aurorasf = 1/52; % (1V per 50mN as per book,20241125 measured as 52mN per 1 V PB)
        pt.piezoAmp = pt.piezoAmp * Aurorasf;
        pt.piezoAmp = min([pt.piezoAmp 9.5]);

        if pt.piezoStimNum <= 1
            ps = analogPulseStruct;
            ps.pulseAmp = pt.piezoAmp;
            ps.duration = pt.piezoDur;
            ps.rampOn = 2;
            ps.rampOff = 2;
            ps.nStims = pt.piezoStimNum;
        else
            ps = squarewaveStruct;
            ps.maxAmp = pt.piezoAmp;
            ps.minAmp = 0;
            ps.frequency = pt.piezoFreq;
            ps.duration = pt.piezoDur * pt.piezoStimNum;
            ps.pulseWidth = 0.9;
        end
        % TrialData init.
        td = TrialData;
        td.tPre = pt.tPre;
        td.tPost = pt.tPost;
        td.comment = pt.Comments;
        td.nRuns = pt.nRepetitions;
                                        

        cameraTriggerStruct.duration = pt.tPre + pt.tPost;
        
        s = {StimulusBlock('stimParams', cameraTriggerStruct), ...
            StimulusBlock('childIdxes', [1 3 4], 'childRel', 'sim'), ...
            StimulusBlock('stimParams', acqStartStruct), ...
            StimulusBlock('stimParams', nextFileStruct, 'startDelay', 2), ...
            StimulusBlock('childIdxes', [6 7 8], 'startDelay', td.tPre, 'childRel', 'sim'), ...
            StimulusBlock('stimParams', qs), ...
            StimulusBlock('stimParams', ps),...
            StimulusBlock('stimParams', acqStopStruct, 'startDelay', td.tPre + td.tPost - 5), ...
            StimulusBlock('childIdxes', [2 5], 'childRel', 'sim')}; % root node
        td.data = s;
        td.RootNodeIdx = 9;
        td.generateParamsSequence;
        % todo td.Validate here!!
        trialData{tNum} = td;
    end
    trialData = [trialData{:}]; %cursed but functional :)
end


% function checkRange(value,range,token,idxStim)
% if value<range(1) || value>range(2)
%     error(['Faulty parameter "%s" for stimulus #%d (expecting value ' ...
%         'to be within %d-%d)'],token,idxStim,range(1),range(2))
% end
% end