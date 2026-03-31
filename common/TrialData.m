classdef (HandleCompatible) TrialData < handle &  matlab.mixin.indexing.RedefinesBrace
% Handle wrapper for cell array of stimulus blocks so that they can be
% passed to one another without data reduplication. 

properties (Access=protected)
    StimulusBlocks (1,:) cell
end

properties(Access=private)
    treeTargets = []; % to be cached on first call of obj.targets
    displayFig = [];
end

properties (Dependent)
    data
end

properties 
    tPre
    tPost
    nRuns
    comment
    params
    line
    trialIdx
    RootNodeIdx
    stimuli
    tags
    metadata

    valid
    errorMsg
end

methods
function obj = TrialData(varargin)
    % Construct an instance of this class
    %   ARGUMENTS: 
    %       data (cell array): a 1xn cell array where n is the number of stimulus blocks in the trial
    %       tPre
    %       tPost
    %       nRuns
    %       line
    %       stimuli
    p = inputParser;
    addParameter(p, 'tPre', obj.tPre, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'tPost', obj.tPost, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'nRuns', obj.nRuns, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'data', obj.data);
    addParameter(p, 'line', obj.line);
    addParameter(p, 'stimuli', obj.stimuli);
    addParameter(p, 'comment', obj.comment);
    addParameter(p, 'tags', obj.tags);
    parse(p, varargin{:});
    for fn = fieldnames(p.Results)'
        obj.(fn{1}) = p.Results.(fn{1});
    end

    for i = 1:length(obj.StimulusBlocks)
        block = obj.StimulusBlocks{i};
        block.treeHandle = obj;
        block.idx = i;
        obj.StimulusBlocks{i} = block;
    end
end

%% tree functions
function out = RootNode(obj)
    out = obj.StimulusBlocks{obj.RootNodeIdx};
end

function targets = targets(obj)
    if isempty(obj.treeTargets)
        rootNode = obj.RootNode;
        targets = rootNode.targets;
        obj.treeTargets = targets;
    else
        targets = obj.treeTargets;
    end
end

function targets = recalculateTargets(obj)
    rootNode = obj.RootNode;
    targets = rootNode.allTargets;
    obj.treeTargets = targets;
end

function [trialParams, metadata] = generateParamsSequence(obj)
    % generates full set of params for a trial in the format:
    %   targetID: 
    %       sequence [int]: the order in which to execute the stimuli
    %       delay [double]: ms delay to wait between each parameter 
    %       params: [struct] array of params for each struct. Order maps to sequence
    rootNode = obj.RootNode;
    try 
        obj.params = rootNode.buildParams;
    catch exception
        dbstack
        error("Error in trial %d (%s): %s", obj.trialIdx, obj.comment, exception.message)
    end
    trialParams = obj.params;
    obj.metadata = obj.BuildMetaData;
    % obj.data = {};
end

function metadata = BuildMetaData(obj)
    metadata= [];
    metadata = obj.data{1}.structencode;
    for i = 2:length(obj.data)
        node = obj.data{i};
        metadata(i) = node.structencode;
    end
end

function out = PrintableMetadata(obj)
    out = [];
    saveableProperties = {"tPre", "tPost", "nRuns", "comment", "params", "line", "trialIdx", "RootNodeIdx", "stimuli", "tags", "metadata"};
    for f = saveableProperties
        if iscell(f)
            f = f{:};
        end
        out.(f) = obj.(f);
    end
end

function set.data(obj, val)
    %sets the data      
    obj.StimulusBlocks = val;
    for i = 1:length(obj.StimulusBlocks)
        block = obj.StimulusBlocks{i};
        block.treeHandle = obj;
        block.idx = i;
        obj.StimulusBlocks{i} = block;
    end
end

function out = get.data(obj)
    out = obj.StimulusBlocks;
end

function fig = Plot(obj)
    % tiledlayout(1, 2);
    if ~isempty(obj.displayFig)
        try
            delete(obj.displayFig);
            clear(obj.displayFig);
        catch exc
            % do nothing, we don't care if this fails.
        end
    end
    obj.displayFig = figure;
    subplot (2,1,1)

    % plot the stim tree
    tree = obj.data;
    dat = zeros([1 length(tree)]);
    labels = repmat({}, [1 length(tree)]);
    for j = 1:length(tree)
        node = tree{j};
        if ~isempty(node.childIdxes)
            dat(node.childIdxes) = j;
        end
        if ~isempty(node.stimParams)
            target = strjoin(node.stimParams.targetDevices);
            len = min([length(char(target)) 5]);
            t = char(target);
            target = string(t(1:len));
        else
            target = "";
        end
        labels{j} = sprintf("%d-%s-%s", j, string(node.childRel), target);
    end
    treeplot(dat);
    [x,y] = treelayout(dat);
    text(x + 0.02,y,labels);
    title(sprintf("Trial %d: %s", obj.trialIdx, obj.line));

    % nexttile
    subplot(2,1,2)
    
    if ~isempty(obj.params)
        fds = fields(obj.params);
        l = length(fields(obj.params));
        tax = linspace(-obj.tPre/1000, obj.tPost/1000, obj.tPre+obj.tPost);
        stimOutputs = zeros(l, length(tax));
        for i = 1:l
            fName = fds{i};
            if strcmpi(fName, 'qst')
                passParams = obj.params.(fName);
                for jj = 1:length(passParams.params)
                    passParams.params{jj}.type = 'thermalPulse';
                end
            else
                passParams = obj.params.(fName);
            end
            stim = StimGenerator.GenerateStimTrain(passParams, obj, 1000);
            if strcmpi(fName, 'qst') && length(stim) > length(stimOutputs)
                stim = stim(1:length(stimOutputs)); %not worth putting more effort into than this I think.
            end
            stimOutputs(i,:) = stim;
        end
        sp = stackedplot(tax, stimOutputs', 'DisplayLabels', fds);
        title(sprintf("Trial %d: %s", obj.trialIdx, obj.line));
    end
    
    fig = obj.displayFig;
end

function leafIdxes = leafIdxes(obj)
    leafIdxes = [];
    for i = 1:length(obj.data)
        node = obj.StimulusBlocks{i};
        if node.isLeafNode
            leafIdxes(end+1) = i;
        end
    end
end

%% line parsing functions
function out = GetTrialDataFromLine(obj, line, stimuli)
    if ~isempty(line)
        obj.line = line;
    end
    if ~isempty(stimuli)
        obj.stimuli = stimuli;
    end
end

function obj = Clean(obj)
    tree = obj.data;
    line = obj.line;
    for rti = length(tree):-1:1
        % go through in reverse trimming all nodes that don't ultimately
        % end in a parameter.
        block = tree{rti};
        if isempty(block.childIdxes) && isempty(block.stimParams)
            % node shouldn't exist
            if isempty(block.parentIdx)
                continue
            end
            parent = tree{block.parentIdx};
            parent.childIdxes(parent.childIdxes == rti) = [];
            tree{block.parentIdx} = parent;
            block.parentIdx = [];
            tree{rti} = block;
        end
    end
    for ti =1:length(tree)
        block = tree{ti};
        if isempty(block.childIdxes) && isempty(block.parentIdx)
            % already pruned. skip.
            continue
        end
        if (isempty(block.childRel) && isempty(block.stimParams)) || ...
                (strcmpi(block.childRel, 'oddSeq') || strcmpi(block.childRel, 'oddRand')) || ...
                (isempty(block.childIdxes) && isempty(block.stimParams))
            if strcmpi(block.childRel, 'oddSeq') || strcmpi(block.childRel, 'oddRand')
                parent = tree{block.parentIdx};
                % pass relevant oddball params up.
                if ~strcmpi(parent.childRel, 'odd')
                     error("Invalid syntax on trial definition line %d (%s). " + ...
                        "|> and | operators are only valid in the context of an oddball relationship. " + ...
                        "Appropriate syntax: A ^.X (B |> C) nStimsX ...", obj.trialIdx, obj.comment);
                end
                parent.oddParams.oddballRel = lower(char(block.childRel(4:end)));
                tree{block.parentIdx} = parent;
            elseif block.repeatDelay ~= 0 || block.startDelay ~= 0 || block.nStimRuns ~= 1
                % not actually an empty block. define child relationship
                % and continue.
                block.childRel = 'sim';
                tree{ti} = block;
                continue
            end
            % EMPTY BLOCK.
            % move child indices to parent
            if isempty(block.parentIdx)
                % this is the root node. Slightly different logic.
                if length(block.childIdxes) == 1
                    obj.RootNodeIdx = block.childIdxes(1);
                    child = tree{obj.RootNodeIdx};
                    child.parentIdx = [];
                    block.childIdxes = [];
                    tree{ti} = block;
                    tree{obj.RootNodeIdx} = child;
                else
                    error("Parsing error on trial definition line %d (%s). " + ...
                        "Root node has multiple children but no relationship assigned.", ...
                        obj.trialIdx, obj.comment);
                end
            end
            parent = tree{block.parentIdx};
            parent.childIdxes = [parent.childIdxes block.childIdxes];
            parent.childIdxes(parent.childIdxes == ti) = [];

            % put altered block back into data
            tree{block.parentIdx} = parent;
            % move parent indices to children
            for ci = 1:length(block.childIdxes)
                child = tree{block.childIdxes(ci)};
                child.parentIdx = block.parentIdx;
                tree{block.childIdxes(ci)} = child;
            end
            % clear block indices (for plotting)
            block.childIdxes = [];
            block.parentIdx = [];
            tree{ti} = block;
        end
    end
    obj.StimulusBlocks = tree;
end

function [tbl, tables] = PrintParams(obj)
    fs = fields(obj.params);
    tables = {};
    tblData = repmat({}, length(fs), 3);
    for fi = 1:length(fs)
        fieldName = fs{fi};
        dat = obj.params.(fs{fi});
        tblData{fi, 1} = fieldName;
        tblData{fi, 2} = strcat(string(dat.sequence));
        tblData{fi, 3} = dat.delay;
        tbl = struct2table(obj.params.(fs{fi}).params, 'AsArray', true);
        tables{fi} = tbl;
    end
    tbl = cell2table(tblData);
    tbl.Properties.VariableNames = {'Target', 'Sequence', 'Delay'};
end

function ValidateTree(obj)
    % Check the tree is valid. 
    leafIdxes = obj.leafIdxes;

    % check all stimuli fit within tPre + tPost
    fs = fields(obj.params);
    for i = 1:length(fs)
        fieldName = fs{i};
        % get stimulus duration
        paramDur = [];
        for j = 1:length(obj.params.(fieldName).params)
            singleStimParams = obj.params.(fieldName).params(j);
            if iscell(singleStimParams)
                singleStimParams = singleStimParams{:};
            end
            if singleStimParams.duration == -1
                paramDur(end+1) = 0;                
            else
                if singleStimParams.duration == 0 ...
                        && isfield(singleStimParams, 'commands') ...
                        && isfield(singleStimParams.commands, 'dStimulus')
                    singleStimParams.duration = singleStimParams.commands.dStimulus;
                end
                paramDur(end+1) = singleStimParams.duration;
            end
        end
        totalDeviceDur = sum(paramDur(obj.params.(fieldName).sequence)) + ...
            sum(obj.params.(fieldName).delay);
        if totalDeviceDur > obj.tPre + obj.tPost
            % % display precise data
            % sprintf("%s: \n dur: %s \n delay: %s", ...
            %     fieldName, ...
            %     strjoin(string(paramDur(obj.params.(fieldName).sequence)), ','), ...
            %     strjoin(string(obj.params.(fieldName).delay), ','))
            % throw error
            error("Stimulus error on trial definition line %d (%s). \n" + ...
                        "Stimulus for %s has a total duration of %d ms, which does not fit within " + ...
                        "tPre + tPost = %d ms. \ntPost should be set to at least %d to fit the stimulus as written. \n" + ...
                        "   sequence: %s\n" + ...
                        "   duration: %s\n" + ...
                        "      delay: %s\n", ...
                        obj.trialIdx, obj.comment, fieldName, totalDeviceDur, obj.tPre+obj.tPost, totalDeviceDur-obj.tPre, ...
                        strjoin(string(obj.params.(fieldName).sequence), ','), ...
                        strjoin(string(paramDur(obj.params.(fieldName).sequence)), ','), ...
                        strjoin(string(obj.params.(fieldName).delay), ','));
        end
    end
end
end

methods (Access=protected)
%% parsing helpers
function tree = GenerateTreeFromLine(obj)
    [p, c] = strtok(obj.line, '%');
    obj.params = strtrim(p);
    obj.comment = strtrim(c(2:end));

    % initialise stack vars
    stack = java.util.Stack;
    stack.push(1); % push root node index to stack
    tree = {StimulusBlock()};
    paramTokens = split(obj.params, ' ');

    for i = 1:length(paramTokens)
        token = paramTokens{i};
        [name, value] = regexpi(token, '(\w*)(\d*)', 'tokens');
        value = str2double(value);
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
                currentParent.oddballParams.swapRatio = str2double(['0.' token(3:end)]);
            end
            if ~isempty(currentParent.childRel) && ~strcmpi(currentParent.childRel, childRel)
                error("Syntax error in trial line %d (%s): Only one relationship type may exist per stim block. " + ...
                    "In oddball paradigms with multiple oddballs, put all oddball " + ...
                    "stimuli into their own bracket block within the oddball block."+ ...
                    "(relationships defined: %s, %s)", ...
                    obj.trialIdx, obj.comment, currentParent.childRel, childRel); 
            else
                currentParent.childRel = childRel;
            end
            % update parent in tree
            tree{currentParentIdx} = currentParent;
        elseif isfield(stimuli, token)
            % leaf (stimulus) node. Create child node and push, add index to current parent
            newNode = StimulusBlock('stimParams', stimuli.(token), 'parentIdx', currentParentIdx);
            tree{end+1} = newNode;
            currentParent.childIdxes(end+1) = length(tree);
            tree{currentParentIdx} = currentParent;
        elseif isfield(trialParamsTracker, name)
            % set trial data (and check it hasn't already been set)
            if trialParamsTracker.(name)
                error("Invalid syntax on trial line %d (%s): %s can only be defined once per trial.", ...
                    obj.trialIdx, obj.comment, name);
            else
                trialParamsTracker.(name) = true;
                obj.(name) = value;
            end
        elseif isfield(validStimBlockParams, name)
            % params for current parent! set em.
            switch lower(name)
                case 'odddistr'
                    % some syntax checking
                    if ~strcmpi(currentParent.childRel, 'odd')
                        % gotta be an oddball to use this
                        error("Invalid syntax on trial definition line %d (%s): " + ...
                            "OddDistrX is set, but the relationship for its stimulus block is not oddball (^.X)", obj.trialIdx, obj.comment);
                    end
                    if value == 0
                        currentParent.oddParams.distributionMethod = 'even';
                    elseif value == 1
                        currentParent.oddParams.distributionMethod = 'random';
                    elseif value == 2
                        if (~isfield(currentParent.oddParams, 'distributionMethod') || ...
                            currentParent.oddParams.distributionMethod(1) ~= 's') && ...
                            ~contains(lower(p), 'oddmindist')
                                % can't set semirandom without also setting a minimum distance
                                error("Invalid syntax on trial definition line %d (%s): " + ...
                                    "to make oddball distribution semirandom, you must also define the minimum distance between oddballs using OddMinDistX. " + ...
                                    "Add this parameter or change to another OddDistr (0=even, 1=random, 2=semirandom)", obj.trialIdx, obj.comment);
                        end
                    else
                        error("Invalid syntax on trial definition line %d (%s): " + ...
                            "OddDistrX accepts X values 0=even, 1=random, 2=semirandom", obj.trialIdx, obj.comment);
                    end
                case 'oddmindist'
                    % some syntax checking.
                    if ~strcmpi(currentParent.childRel, 'odd')
                        % gotta be an oddball to use this
                        error("Invalid syntax on trial definition line %d (%s): " + ...
                            "OddMinDistX is set, but the relationship for its stimulus block is not oddball (^.X).", obj.trialIdx, obj.comment);
                    elseif isfield(currentParent.oddParams, 'distributionMethod')
                        % shouldn't be set! likely the wrong kind of oddball distribution method.
                        error("Invalid syntax on trial definition line %d (%s): " + ...
                            "OddMinDistX is set, but the OddDistr value for its stimulus block is not semirandom (OddDistr2).", obj.trialIdx, obj.comment);
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
             error("Invalid parameter on trial definition line %d (%s): %s. " + ...
                "Parameters must be a stimulis defined in the stimulus section " + ...
                "or one of the following: %s", obj.trialIdx, obj.comment, tkName, ...
                GetListFromArray(fields(validTrialParams)));
        end
        % put parent back on the stack
        stack.push(currentParentIdx);
        % plotTree(tree, stack, comment, idxTrial);
    end
end

function line = PreProcessLine(obj, line)
    % Sanitise line (add spaces around everything)
    sepQuery = '&|>|(\|>)|(\^\.\d?)';
    [startIdxes, endIdxes] = regexpi(params, [sepQuery '|\)|\(']);
    for i = 0:length(startIdxes)-1
        l = length(startIdxes);
        startIdx = startIdxes(l-i);
        endIdx = endIdxes(l-i);
        if endIdx ~= length(params) && ~strcmpi(params(endIdx + 1), ' ')
            params = insertAfter(params, endIdx, ' ');
        end
        if startIdx ~= 1 && ~strcmpi(params(startIdx - 1), ' ')
            params = insertBefore(params, startIdx, ' ');
        end
    end
end

%% brace redefinitions
function varargout = braceReference(obj,indexOp)
    [varargout{1:nargout}] = obj.StimulusBlocks.(indexOp);
end

function obj = braceAssign(obj,indexOp,varargin)
    if isscalar(indexOp)
        [obj.StimulusBlocks.(indexOp)] = varargin{:};
        return;
    end
    [obj.StimulusBlocks.(indexOp)] = varargin{:};
    
    for i = 1:length(indexOp)
        idx = obj.StimulusBlocks{i};
        block = obj.StimulusBlocks.(indexOp);
        block.treeHandle = obj;
        block.idx = idx;
    end
end

function n = braceListLength(obj,indexOp,indexContext)
    n = listLength(obj.StimulusBlocks,indexOp,indexContext);
end
end
end