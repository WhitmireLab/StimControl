function [p,g] = readProtocol(filename,varargin)

%% parse inputs
ip = inputParser;
addRequired(ip,'filename',...
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

%% define defaults
%%TODO ADD NumTHINGS?
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
dig = struct( ...           %basic digital output
    'digDelay',             0,...
    'digDuration',          2);
pwm  = struct( ...          %PWM digital output
    'pwmDc',                50,...
    'pwmFreq',              100,...
    'pwmDur',               2,...
    'pwmDelay',             0);
ana  = struct( ...          %basic analog output
    'anAmp',                5,...
    'anDur',                2,...
    'anDelay',              0,...
    'anFreq',               100); %TODO FREQ RELEVANT?
cam  = struct(...           % cameras
    'light',                111,...
    'enable',               1);
general = struct(...        % timing / repetitions
    'Comments',             '',...
    'tPre',                 1000,...
    'tPost',                2000,...
	'nRepetitions',         1);
arb = struct( ...           % arbitrary outputs
    'type',                 'analog',...
    'filename',             '');
p = struct();
% Count and initialise with names
RegXTherm = 'V\d{4}[A-Z]?';
RegXAn = '((An)|(Vib)|(Piezo))[A-Z]*\d*[A-Z]?';
RegXDi = '(Di)[A-Z]*\d*)[A-Z]?'; 
RegXPwm = '((PWM)|(LED))[A-Z]*\d*[A-Z]?';
RegXCam = '(Cam)[A-Z]*\d*[A-Z]?';
regexStrings = {RegXTherm, RegXAn, RegXDi, RegXPwm, RegXCam};
for regexString = regexStrings
    occasions = cellfun(@(x) regexpi(x, regexString, 'match'), lines);
    min = any(~isempty(horzcat(occasions{:})));
    if min == 0 %no matches
        continue
    end
    if strcmp(regexString, RegXTherm)
        occasions = cellfun(@(x) regexpi(x, '(?<=\d+)[A-Z]?', 'match'), horzcat(occasions{:}), 'UniformOutput', false);
        ids = unique(horzcat(occasions{:}));
        if length(ids) <= 1
            p.('Thermode') = tmp;
            continue
        end
    else
        occasions = cellfun(@(x) extract(x, lettersPattern), horzcat(occasions{:}), 'UniformOutput', false);
        ids = unique(horzcat(occasions{:}));
        %if there are multiple strings with the same prefix and one is
        %shorter, remove it?
        % ids(ismember(animals)) = [];
        %TODO IF THERE'S MULTIPLE GET RID OF THE BASE ONE?
    end %TODO WHAT ABOUT ARBITRARY
    for n = 1:length(ids)
        if strcmp(regexString, RegXTherm)
            name = sprintf('Thermode%s', 64+n);
            str = tmp;
        else
            name = ids{n};
            if contains(name, )
        end
        p.(name) = str;
    end
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

        % Switch to appropriate subroutine for provided token.  
        if regexpi(token,'^(I[01]|[NT]\d{3}|C\d{4}|S[01]{5}|[VR]\d{5}|D\d{6})[A-Z]?$','once')
            %thermode
            p = parseThermode(p,token,idxStim,fnThermodes);
            continue
        elseif regexpi(token, '^(((An)|(Vib)|(Piezo))((Amp)|(Dur)|(Delay))\d*)[A-Z]?$', 'once')
            % analog oputput - vibration and piezo included.
            p = parseToken(p, token, idxStim);
            continue
        elseif regexpi(token, '^([(Di)][(Dur)(Delay)]\d*)[A-Z]?$', 'once')
            % simple digital output
            continue
        elseif regexpi(token, '^([(PWM)|(LED)][(DC)(Freq)(Dur)(Delay)]\d*)[A-Z]?$', 'once')
            % PWM including LED control
            continue
        elseif regexpi(token, '^([(Cam)][(Light)(Enable)]\d*)[A-Z]?$', 'once')
            % Specific camera acquisition controls
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
    thermodes = {['Thermode' upper(token(end))]};
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


% function checkRange(value,range,token,idxStim)
% if value<range(1) || value>range(2)
%     error(['Faulty parameter "%s" for stimulus #%d (expecting value ' ...
%         'to be within %d-%d)'],token,idxStim,range(1),range(2))
% end
% end