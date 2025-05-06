function out = rfind(basedirs,varargin)
% RFIND Recursively find files/folders within several base directories.
%   Blah.
%
% (c) 2016 Florian Rau

%% manage the input arguments
p = inputParser;
addRequired(p,'expression',@(x) ...
    validateattributes(x,{'char'},{'row'}));
addOptional(p,'nmax',Inf,@(x) ...
    validateattributes(x,{'numeric'},{'scalar','positive'}));
addOptional(p,'rmax',Inf,@(x) ...
    validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
parse(p,varargin{:});

if ~iscell(basedirs)
    basedirs = {basedirs};
end
basedirs = basedirs(cellfun(@isdir,basedirs));
basedirs = {basedirs{:}}';
if isempty(basedirs)
    out = [];
    return
end

expression  = p.Results.expression;
nmax        = p.Results.nmax;
rmax        = p.Results.rmax;

%% search within BASEDIRS
out = cellfun(@dir,basedirs,'UniformOutput',0);
if verLessThan('matlab','9.1')                    	% workaround <R2016b
    for ii = 1:length(out)
        [out{ii}.folder] = deal(basedirs{ii});
    end
end
out = vertcat(out{:});
out = out(cellfun(@any,regexpi({out.name},expression)));

%% stop, if we have collected enough results
if length(out) >= nmax
    out = out(1:nmax);
    return
end

%% find sub-directories
sub = cellfun(@dir,basedirs,'UniformOutput',0);         % contents of basedirs
if verLessThan('matlab','9.1')                          % workaround <R2016b
    for ii = 1:length(sub)
        [sub{ii}.folder] = deal(basedirs{ii});
    end
end
sub = vertcat(sub{:});                                  % concatinate results
sub = sub([sub.isdir]);                                 % limit to directories
sub = sub(~cellfun(@any,regexpi({sub.name},'^\.')));    % drop hidden dirs
sub = fullfile({sub.folder},{sub.name});                % build full names
sub = unique(sub);                                      % drop duplicates

%% recursion
if ~isempty(sub) && rmax>0
    out   = ...                                         % search sub-directories
        vertcat(out,rfind(sub,expression,nmax,rmax-1));
    [~,u] = unique(fullfile({out.folder},{out.name}));  % index unique results
    out   = out(u);                                     % return unique results
else
    return
end