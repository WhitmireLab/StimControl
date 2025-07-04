function [p,g] = readProtocol(filename,varargin)
%% DEBUG
if isempty(filename)
    filename = [pwd filesep 'StimControl' filesep 'protocolfiles' filesep 'TempandVibe.stim'];
end

%% parse inputs
ip = inputParser;
addRequired(ip,'filename',...
    @(x)validateattributes(x,{'char'},{'nonempty'}));
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

%% define defaults
g = struct(...              % general parameters
    'dPause',               5,...
    'nProtRep',             1,...
    'randomize',            0, ...
    'nTherm',               0,...
    'nAna',                 0,...
    'nDig',                 0,...
    'nPwm',                 0,...
    'nCam',                 0,...
    'nArb',                 0);
thrm = struct(...           % thermodes
    'NeutralTemp',          32,...    
    'PacingRate',           ones(1,5) * 999,...
    'ReturnSpeed',          ones(1,5) * 999,...
    'SetpointTemp',         ones(1,5) * 32,...
    'SurfaceSelect',        true(1,5),...
    'dStimulus',            ones(1,5) * 1000,...
    'integralTerm',         1,...
    'nTrigger',             255,...
    'VibrationDuration',    0);
dig = struct( ...           %basic digital output
    'delay',                0,...
    'dur',                  2, ...
    'rep',                  0, ...
    'repdel',               0);
pwm  = struct( ...          %PWM digital output
    'dc',                   50,...
    'freq',                 100,...
    'dur',                  50,...
    'delay',                0, ...
    'rep',                  0, ...
    'repdel',               0);
ana  = struct( ...          %basic analog output
    'amp',                  5,...
    'dur',                  50,...
    'delay',                0,...
    'freq',                 100, ...
    'rep',                  0, ...
    'repdel',               0); %TODO FREQ RELEVANT?
cam  = struct(...           % cameras
    'light',                111,...
    'enable',               1);
general = struct(...        % timing / repetitions
    'Comments',             '',...
    'tPre',                 1000,...
    'tPost',                2000,...
	'nRepetitions',         1);
arb = struct( ...           % arbitrary outputs
    'type',                 'analog',... %analog/digital
    'filename',             '', ...
    'data',                 []);
p = struct();

%% Count and initialise with names
%TODO maybe only do this if nTherm nAna nDig nPwm nCam and nArb are
%undefined?
regexSuffix = '[A-Z]*(-?\d*)[A-Z]?'; %TODO VIBRATION IS DIGITAL!! Piezo IS analog
regexTherm = 'V\d{5}[A-Z]?';
regexTherm = '(I[01]|[NT]\d{3}|C\d{4}|S[01]{5}|[VR]\d{5}|D\d{6})[A-Z]?';
regexAna = ['((Ana)|(Vib)|(Piezo))', regexSuffix];
regexDig = ['(Dig)', regexSuffix]; 
regexPwm = ['((PWM)|(LED))', regexSuffix];
regexCam = ['(Cam)', regexSuffix];
regexArb = '[A-Z]*\:([A-Z]+\/*)+\.((txt)|(csv)|(astim))';
regexStrings = {regexTherm, regexAna, regexDig, regexPwm, regexCam, regexArb};
for regexString = regexStrings
    occs = cellfun(@(x) regexpi(x, regexString, 'match'), lines);
    if ~any(~isempty(horzcat(occs{:})))
        continue
    end
    if strcmp(regexString, regexTherm)
        % specific thermode parsing
        occs = cellfun(@(x) regexpi(x, '(?<=\d+)[A-Z]?', 'match'), ...
            horzcat(occs{:}), 'UniformOutput', false);
        ids = unique(horzcat(occs{:}));
        if length(ids) <= 1 && any(cellfun(@(x) ~isempty(x), occs))
            % only one thermode
            p.('Thermode') = thrm;
            g.('nTherm') = 1;
            continue
        end
    elseif strcmp(regexString, regexArb)
        % specific arbitrary stimulus parsing
        occs = cellfun(@(x) regexpi(x, '[A-Z]+(?=\:)', 'match'), ...
            horzcat(occs{:}), 'UniformOutput', false);
        ids = unique(horzcat(occs{:}));
    else
        % parsing for everything else
        minireg = regexString{1}(1:end-length(regexSuffix));
        occs = cellfun(@(x) strcat(regexpi(x, [minireg, '(?=[A-Z]+[a-z]+\d+)'], 'match'), x(end)), ...
                unique(horzcat(occs{:})), 'UniformOutput', false);
        occs = cellfun(@(x) regexpi(x, '[A-Z]*', 'match'), unique(horzcat(occs{:})), 'UniformOutput', false);
        ids = unique(horzcat(occs{:}));  %TODO this currently treats, e.g. AnaB and Anab as two different things. Might be fine?
    end 
    for n = 1:length(ids)
        skip = false;
        if strcmp(regexString, regexTherm)
            name = ['Thermode' upper(ids{n})];
            p.(name) = thrm;
            g.('nTherm') = g.('nTherm')+1;
        else
            name = lower(ids{n});
            for m = ids
                % remove, e.g., Vib when VibA and VibB are defined
                m2 = lower(m{:});
                if contains(m2, name) && ~strcmp(m, ids{n})
                    skip = true;
                    if length(name) == length(m2) && upper(name(end)) == ids{n}(end)
                        skip = false;
                    end
                end
            end
            if skip
                continue
            end
            if contains(name, 'ana') || contains(name, 'vib') || contains(name, 'piezo')
                p.(ids{n}) = ana; %TODO this recapitalises but it maybe shouldn't?
                g.('nAna') = g.('nAna') + 1;
            elseif contains(name, 'dig')
                p.(ids{n}) = dig;
                g.('nDig') = g.('nDig') + 1;
            elseif contains(name, 'pwm') || contains(name, 'led')
                p.(ids{n}) = pwm;
                g.('nPwm') = g.('nPwm') + 1;
            elseif contains(name, 'cam')
                p.(ids{n}) = cam;
                g.('nCam') = g.('nCam') + 1;
            elseif strcmp(regexString, regexArb)
                p.(ids{n}) = arb;
                g.('nArb') = g.('nArb') + 1;
            else
                error("Unknown Input Type %s", name);
            end
        end
    end
end

%% Finish initialising.
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
        % Switch to appropriate subroutine for provided token.  
        if regexpi(token,'^(I[01]|[NT]\d{3}|C\d{4}|S[01]{5}|[VR]\d{5}|D\d{6})[A-Z]?$','once')
            % Thermode
            p = parseThermode(p,token,idxStim);
            continue
        elseif regexpi(token, '^[A-Z]*\:([A-Z]+\/*)+\.((txt)|(csv)|(astim))$', 'once')
            % Specific arbitrary control - gotta read a text file.
            p = parseArbitrary(p,token,idxStim);
            continue
        elseif regexpi(token, ['^(((Ana)|(Vib)|(Piezo)|(Dig)|(PWM)|(LED)|(Cam))' ...
                '((Amp)|(Dur)|(Delay)|(DC)|(Freq)|(Light)|(Enable)|(Rep)|(RepDel))(-?\d*))[A-Z]*$'], 'once')
            % Standard format
            p = parseToken(p, token, idxStim);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
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
                case 'ttact' %TODO WHAT THIS - REMOVE? :)
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
            end
        end

        % if the token was not recognized, throw an error
        error('Unknown parameter "%s" for stimulus #%d',token,idxStim)
    end
end
p(idxStim+1:end) = [];

end

function p = parseArbitrary(p, token, idxStim)
    tmp = regexpi(token, '^([A-Z]*)(\:)(.*)$', 'once', 'tokens');
    id = tmp{1};
    filename = tmp{3};
    % read file
    if ~exist(filename,'file')
        error('File not found: %s',filename)
    end
    fid   = fopen(filename);
    lines = textscan(fid,'%s','Delimiter','\n','MultipleDelimsAsOne',1);
    fclose(fid);
    lines = lines{1};
    
    % remove comment lines
    lines(cellfun(@(x) (strcmp(x(1),'%') || strcmp(x(2), '%')) ,lines)) = [];
    try
        type = lower(lines{1});
        protocol = str2num(lines{2});
    catch
        error("Invalid protocol in file %s. Protocol line should have only numbers", filename);
    end
    if ~contains(['digital', 'analog'], type)
        error("invalid data type %s in file %s", type, filename);
    end
    p(idxStim).(id).type = type;
    p(idxStim).(id).filename = filename;
    p(idxStim).(id).data = protocol;
end

function p = parseToken(p, token, idxStim)
    tmp = regexpi(token, ['^((Ana)|(Vib)|(Piezo)|(Dig)|(PWM)|(LED)|(Cam))' ...
                            '((Amp)|(Dur)|(Delay)|(DC)|(Freq)|(Light)|(Enable)|(Rep)|(RepDel))' ...
                            '(-?\d*)([A-Z])*$'], 'once', 'tokens');
    stimType = tmp{1};
    attr = tmp{2};
    val = str2double(tmp{3});
    subtype = upper(tmp{4});
    if isempty(subtype)
        % applies to all stimuli of that type
        surfaces = cellfun(@(x) regexpi(x, ['(', stimType, ')([A-Z]*)'], ...
            'match'), fields(p), 'UniformOutput', false);
        surfaces = unique(horzcat(surfaces{:}));
    else
        surfaces = {strcat(stimType, subtype)};
    end
    for sName = surfaces
        sName = sName{:};
        if ~isfield(p(idxStim).(sName), lower(attr))
            error('Faulty parameter "%s" for stimulus #%d (%s, valid values for %s: %s)', ...
                    attr,idxStim,p(idxStim).(sName),fields(p(idxStim).(sName)))
        end
        p(idxStim).(sName).(lower(attr)) = val;
    end
end

function p = parseThermode(p,token,idxStim)
% Read the parameter's value, define the fieldname and wether the parameter
% applies to multiple surfaces of the thermode
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
    
    % Does the parameter apply to individual surfaces of the thermode?
    % Obtain logical index for respective surface(s) ...
    %TODO WHAT
    if multiSurf
        idxSurface = readRangeThermode(token,2,[0 5],idxStim);
        if ~idxSurface, idxSurface = 1:5; end
    end

    thermodes = cellfun(@(x) regexpi(x, '(Thermode)([A-Z]?)', ...
            'match'), fields(p(idxStim)), 'UniformOutput', false); 
    thermodes = unique(horzcat(thermodes{:}));
    if isstrprop(token(end),'alpha')
        if ~ismember(['Thermode', upper(token(end))],thermodes)
      	    format = token;
            format(end) = 'X';
            error(['Faulty parameter "%s" for stimulus #%d (%s, valid ' ...
                'values for X: %s)'],token,idxStim,format,thermodes{:})
        end
        thermodes = {['Thermode' upper(token(end))]};
    end

    % Loop through the thermodes and assign the value
    for thermode = thermodes
        if multiSurf
            if ~isfield(p(idxStim).(thermode{:}),fieldname)
                p(idxStim).(thermode{:}).(fieldname) = NaN(1,5);
            end
        end
        p(idxStim).(thermode{:}).(fieldname) = value;
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


% function checkRange(value,range,token,idxStim)
% if value<range(1) || value>range(2)
%     error(['Faulty parameter "%s" for stimulus #%d (expecting value ' ...
%         'to be within %d-%d)'],token,idxStim,range(1),range(2))
% end
% end