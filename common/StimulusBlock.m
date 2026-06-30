classdef StimulusBlock < handle
properties
    treeHandle  = [];   % TrialData, for indexing into children.
    idx         = 1;    % int, if == 1, this is a root node.
    repeatDelay = 0     % int, ms to wait between stim repeats
    startDelay  = 0;    % int, ms to wait after stim t=0 to start
    nStimRuns   = 1;    % int, number of times to run the stim within the block
    stimParams  = [];   % struct of stimulus parameters. Only one stimulus can be given per block.
    parentIdx   = [];   % int, index of location of parent in the s array. if empty, this is a root node
    childIdxes  = [];   % [int], vector where each entry is the index of its children in the s array. 
                            % For oddball childRel, assume the leftmost child is the default and all other children are swaps,
                            % Root node should have exactly two
                            % children: left for stims that start at tPre and right for stims that start at tPost
    oddParams   = [];   % oddball params, only used if childRel == 'odd'. Has fields:
                            % swapRatio (% of default stim to swap)
                            % distributionMethod (one of: 
                                % even, 
                                % random,
                                % semirandomX where x is the number of times 
                                    % to guarantee default stim between oddballs)
                            % oddballRel (rand / seq) - with multiple oddballs, 
                                % defined whether the oddballs are randomly distributed or 
                                % swapped in sequentially.
    childRel    = '';   % [char], relationship between children. One of:
                            % odd (oddball, swap out child1 for child2 according to oddball params
                            % sim (simultaneous, children start at same time)
                            % seq (sequential, child1 starts after child2 finishes
    tokenName   = '';   % [char], name of the token.
    singleStimNodeLength = [];
    tags = [];
    comment = [];
    debugText = '';
    childExecutionSequence = [];
end

properties (Access=private)
    allTargetsCached = [];
    oddballSequence = [];
    durCached = [];
    containsOdd = false;
end

methods
    function obj = StimulusBlock(varargin)
        % Construct an instance of StimulusBlock
        % ARGUMENTS:
        %   childIdxes  - [int], vector where each entry is the index of its children in the s array
        %   repeatDelay - int, ms to wait between stim repeats
        %   startDelay  - int, ms to wait after stim t=0 to start
        %   nStimRuns   - int, number of times to run the stim within the
        %   stimParams  - struct of stimulus parameters in the format stimName: [params = struct], ...
        %   oddParams   - oddball params, only used if childRel == 'odd'
        %   childRel    - [char], relationship between children. One of: 'odd', 'sim', 'seq'
        p = inputParser;
        addParameter(p, 'childIdxes', obj.childIdxes);
        addParameter(p, 'parentIdx', obj.parentIdx);
        addParameter(p, 'repeatDelay', obj.repeatDelay, @(x) isnumeric(x));
        addParameter(p, 'startDelay', obj.startDelay, @(x) isnumeric(x));
        addParameter(p, 'nStimRuns', obj.nStimRuns, @(x) isnumeric(x));
        addParameter(p, 'stimParams', obj.stimParams, @(x) isstruct(x));
        addParameter(p, 'oddParams', obj.oddParams, @(x) isstruct(x));
        addParameter(p, 'childRel', obj.childRel, @(x) ischar(x) && ismember(x, {'odd', 'sim', 'seq'}));
        addParameter(p, 'treeHandle', []);
        addParameter(p, 'tokenName', obj.tokenName);
        addParameter(p, 'comment', obj.comment);
        parse(p, varargin{:});
        for fn = fieldnames(p.Results)'
            obj.(fn{1}) = p.Results.(fn{1});
        end
    end

    function valid = isValid(obj)
        % whether this node is valid.
        valid = true;
         if obj.isRootNode % root node
            if length(obj.childIdxes) ~=2 ...   % should have exactly 2 children
                    || ~strcmpi(obj.childRel, 'sim') % tPre tPost
                valid = false;
            end
         elseif ~obj.isLeafNode
            % check the following attributes:
            % no simultaneous addressing of the same device
            % check oddball is valid: >1 children, >1 nStimRuns, params defined, common sense ratio checking?
            % check if not oddball params are not defined
         else
            % check stimParams is defined & valid
         end
    end

    function valid = allValid(obj)
        % whether this node and all its children are valid.
        valid = obj.isValid;
        if ~obj.isLeafNode
            children = obj.children;
            for i = 1:length(children)
                child = children(i);
                if ~child.allValid
                    valid = false;
                    return;
                end
            end
        end
    end

    function out = structencode(obj)
        out = [];
        for f = properties(obj)'
            if iscell(f)
                f = f{:};
            end
            if strcmpi(f, 'treeHandle')
                continue
            end
            out.(f) = obj.(f);
        end
       % add attribute-like function info
       out.activeDuration = obj.durationMs;
       out.fullDuration = obj.fullDuration;
       out.startTimes = obj.GetNodeStartTimes;
    end
    
    function out = debugprint(obj, varargin)
        tmp = sprintf("NODE_%d", obj.idx);
        if ~isempty(obj.tokenName)
            tmp = tmp + sprintf(" (%s)", obj.tokenName);
        end
        if isempty(obj.childIdxes)
            childTxt = 'N/A';
        elseif length(obj.childIdxes) == 1
            childTxt = string(obj.childIdxes);
        else
            childTxt = strjoin(string(obj.childIdxes), ' ');
        end
        out = sprintf("%s: \n\t" + ...
            "Children (%s): %s\n\t" + ...
            "Parent: %d", ...
            tmp, ...
            obj.childRel, childTxt, ...
            obj.parentIdx);
        for i = 1:length(varargin)
            tmp = sprintf("\n%s", formattedDisplayText(varargin{i}));
            out = out + tmp;
        end
    end

    function out = FirstCommonParentIdx(obj, idx)
        out = [];
        objParents = obj.traverseParentIdxes;
        altNode = obj.treeHandle{idx};
        altParents = altNode.traverseParentIdxes;
        for pIdx = objParents
            if any(altParents == pIdx)
                out = pIdx;
                return
            end
        end
    end

    function out = traverseParentIdxes(obj)
        out = [];
        if ~isempty(obj.parentIdx)
            parent = obj.treeHandle{obj.parentIdx};
            out = [obj.parentIdx parent.traverseParentIdxes];
        end
    end

    function trialParams = buildParams(obj)
        % Builds a params sequence
        [params, targets, singleStimParams, helperStruct] = BuildEmptyStructs();
        obj.containsOdd = obj.FindOddballChildren();

        if obj.isLeafNode
            trialParams = BuildLeafParams(singleStimParams);
            return
        end
        singleStimParams = BuildSingleStimParams();
        trialParams = singleStimParams;
        buildTrialFromSequence = obj.nStimRuns > 1 && (strcmpi(obj.childRel, 'sim') || strcmpi(obj.childRel, 'seq'));
        reshuffle = obj.containsOdd && buildTrialFromSequence; % reshuffle oddball sequence every repeat

        % fill in metadata
        for f = unique(targets)
            obj.singleStimNodeLength.(f) = length(singleStimParams.(f).sequence);
        end

        if buildTrialFromSequence
            for nRep = 2:obj.nStimRuns
                if reshuffle
                    singleStimParams = BuildSingleStimParams();
                end
                for f = unique(targets)
                    repeatDelays = singleStimParams.(f).delay;
                    repeatDelays(1) = repeatDelays(1) + obj.repeatDelay;
                    trialParams.(f).delay = [trialParams.(f).delay repeatDelays];
                    trialParams.(f).sequence = [trialParams.(f).sequence singleStimParams.(f).sequence];
                end
            end
        end

        % add start delay
        for f = unique(targets)
            trialParams.(f).delay(1) = trialParams.(f).delay(1) + obj.startDelay;
        end
        
        %% param construction helper functions
        function [params, targets, singleStimParams, helperStruct] = BuildEmptyStructs()
            params = struct('sequence', [], 'delay', [], 'params', []);
            targets = obj.targets;
            singleStimParams = [];
            helperStruct = [];
            for ti = 1:length(targets) % fair bit of duplication here but not a huge issue
                targetName = targets{ti};
                singleStimParams.(targetName).sequence = [];
                singleStimParams.(targetName).delay = [];
                singleStimParams.(targetName).params = [];
                singleStimParams.(targetName).sequenceStack = {};

                % initalise helperstruct
                helperStruct.(targetName) = [];
                helperStruct.(targetName).idxOffset = 0;
                helperStruct.(targetName).totalDelay = 0;
                helperStruct.(targetName).relativeSequence = [];
            end
        end

        function trialParams = BuildLeafParams(singleStimParams)
            tds = obj.stimParams.targetDevices;
            for ti = 1:length(tds)
                % TODO-OPTIMISATION: POSSIBILITY FOR A FAIR BIT OF REPLICATION HERE
                targetName = tds(ti);
                singleStimParams.(targetName).params = {obj.stimParams};
                singleStimParams.(targetName).delay = [obj.startDelay repmat(obj.repeatDelay, [1 obj.nStimRuns-1])];
                singleStimParams.(targetName).sequence = ones([1, obj.nStimRuns]);
                singleStimParams.(targetName).sequenceStack = num2cell(ones([1, obj.nStimRuns]) * obj.idx);
                obj.singleStimNodeLength.(targetName) = obj.nStimRuns;
                trialParams = singleStimParams;
            end
        end

        function singleStimParams = ConstructSimultaneousSequence(traversedParams)
            for ti = 1:length(traversedParams)
                traversedParam = traversedParams{ti};
                fds = fields(traversedParam); %todo check simultaneous execution on same line
                for fi = 1:length(fds)
                    fieldName = fds{fi};
                    singleStimParams.(fieldName) = traversedParam.(fieldName);
                end
            end
        end

        function [traversedParams, singleStimParams, helperStruct] = FillInHelperStruct( ...
                    traversedParams, singleStimParams, helperStruct)
            % First pass. Fill in helper struct and generate:
            %   index offsets for sub-stimuli per param target (i.e. 1 from
            %       sub-stim that is second in a sequence for a target becomes
            %       2, etc.)
            %   parameter list - concatenated from sub-params
            %   relativeSequence: the index of the sequence for the specific parameter 
            relativeSequence = ones(length(traversedParams), 1);
            for ti = 1:length(traversedParams)
                traversedParam = traversedParams{ti};
                for fd = fields(traversedParam)'
                    if iscell(fd)
                        f = fd{:};
                    else
                        f = fd;
                    end
                    if length(helperStruct.(f).relativeSequence) == 1
                        helperStruct.(f).relativeSequence = relativeSequence;
                    end
                    helperStruct.(f).relativeSequence(ti) = length(helperStruct.(f).idxOffset);
                    helperStruct.(f).idxOffset = [helperStruct.(f).idxOffset, ...
                                    traversedParam.(f).sequence+max(helperStruct.(f).idxOffset)];
                    singleStimParams.(f).params = ...
                                    [singleStimParams.(f).params traversedParam.(f).params];
                end
            end
        end

        function [singleStimParams, helperStruct] = ConstructParamsFromSequence( ...
                    singleStimParams, helperStruct, traversedParams, sequence)
            % construct from sequence (set new sequence and delay)
            children = obj.children;
            totalDelay = 0;
            for si = 1:length(sequence)
                traversedParam = traversedParams{sequence(si)};
                if ~isstruct(traversedParam)
                    traversedParam = traversedParam{:};
                end
                child = children(sequence(si));
                for f = fields(traversedParam)'
                    % set params
                    if iscell(f)
                        f = f{:};
                    end
                    % set sequence
                    singleStimParams.(f).sequence = ...
                        [singleStimParams.(f).sequence traversedParam.(f).sequence+helperStruct.(f).idxOffset(helperStruct.(f).relativeSequence(sequence(si)))]; 
                    
                    singleStimParams.(f).sequenceStack = ...
                        [singleStimParams.(f).sequenceStack traversedParam.(f).sequenceStack]; 

                    % set delay
                    if strcmpi(obj.childRel, 'odd') && ~isempty(singleStimParams.(f).delay) % oddball, add repeat delay if not first runthrough.
                        traversedParam.(f).delay(1) = traversedParam.(f).delay(1) + obj.repeatDelay;
                    end
                    singleStimParams.(f).delay = ...
                        [singleStimParams.(f).delay traversedParam.(f).delay+(totalDelay-helperStruct.(f).totalDelay)];

                    % update helperstruct
                    helperStruct.(f).totalDelay = totalDelay + child.fullDuration;
                    if strcmpi(obj.childRel, 'odd') 
                        helperStruct.(f).totalDelay = helperStruct.(f).totalDelay + obj.repeatDelay;
                    end
                end
                totalDelay = totalDelay + child.fullDuration;
                if strcmpi(obj.childRel, 'odd') % oddball, include repeat delay
                    totalDelay = totalDelay + obj.repeatDelay;
                end
            end
        end

        function singleStimParams = BuildSingleStimParams()
            [~, ~, singleStimParams, helperStruct] = BuildEmptyStructs();
            traversedParams = TraverseChildParams();
            if strcmpi(obj.childRel, 'sim') 
                singleStimParams = ConstructSimultaneousSequence(traversedParams);
                obj.childExecutionSequence = [obj.childExecutionSequence Inf];
            else
                % sequential or oddball. Build sequence and go from there.
                if strcmpi(obj.childRel, 'seq')
                    sequence = linspace(1, length(obj.childIdxes), length(obj.childIdxes));
                    obj.childExecutionSequence = [obj.childExecutionSequence {sequence}];
                elseif strcmpi(obj.childRel, 'odd')
                    sequence = generateOddballOrder;
                    obj.childExecutionSequence = [obj.childExecutionSequence {sequence}];
                    obj.oddballSequence = sequence;
                end
                [traversedParams, singleStimParams, helperStruct] = FillInHelperStruct(traversedParams, singleStimParams, helperStruct);
                [singleStimParams, helperStruct] = ConstructParamsFromSequence(singleStimParams, helperStruct, traversedParams, sequence);
            end
            for f = unique(targets)
                for i = 1:length(singleStimParams.(f).sequenceStack)
                    singleStimParams.(f).sequenceStack{i} = [obj.idx; singleStimParams.(f).sequenceStack{i}];
                end
            end
        end

        function order = generateOddballOrder()
            order = ones(1, obj.nStimRuns);
            obj.childIdxes = unique(obj.childIdxes);
            nOdds = length(obj.childIdxes) - 1;
            if length(obj.childIdxes) > obj.nStimRuns
                error(sprintf("nStims in oddball sequence (%d) is insufficient to run all oddball trials (total %d including baseline).", obj.nStimRuns, nOdds+1));
            end
            % first, shuffle the oddballs
            nSwaps = floor(obj.nStimRuns * obj.oddParams.swapRatio);
            oddIdxes = linspace(2, nOdds+1, nOdds);
    
            odds = [repmat(oddIdxes, [1 floor(nSwaps / nOdds)]) oddIdxes(1:rem(nSwaps, nOdds))];
            if isfield(obj.oddParams, 'oddballRel') && strcmpi(obj.oddParams.oddballRel, 'rand')
                odds = odds(randperm(length(odds)));
            end
    
            % Swap oddballs into baseline execution order
            if strcmpi(obj.oddParams.distributionMethod, 'even') %evenly distributed
                swapIdxes = ceil(linspace(2, length(order), nSwaps)); % (ish)
            elseif strcmpi(obj.oddParams.distributionMethod, 'random') %randomly distributed
                swapIdxes = randperm(obj.nStimRuns, nSwaps);
            else
                if ~contains(obj.oddParams.distributionMethod, 'semirandom') %randomly distributed with minimum swap distance
                    error("Invalid distribution method: %s", obj.oddParams.distributionMethod);
                end
                minPostOddDefaults = str2double(obj.oddParams.distributionMethod(11:end)); % warning: cursed
                if minPostOddDefaults > (obj.nStimRuns/nSwaps) - 1
                    error("Unable to set %d default stimuli between oddballs " + ...
                        "for %d total instances at %.3f oddball rate. \n" + ...
                        "Maximum allowable value for OddMinDistX = %d", ...
                        minPostOddDefaults, obj.nStimRuns, obj.oddParams.swapRatio, ...
                        obj.nStimRuns/nSwaps - 1);
                end
                % semirandom: assign buckets of size nRuns/nSwaps & randomly place within
                % those buckets
                bucketIdxes = round(linspace(minPostOddDefaults+1, obj.nStimRuns, nSwaps+1));
                swapIdxes = repmat([], [1 nSwaps]);
                prevSwap = 0;
                for i = 1:length(bucketIdxes) - 1
                    startIdx = max([bucketIdxes(i), prevSwap+minPostOddDefaults]);
                    endIdx = bucketIdxes(i+1);
                    swapIdx = startIdx + round((endIdx - startIdx)*rand(1,1));
                    swapIdxes(i) = swapIdx;
                    prevSwap = swapIdx;
                end
            end
            for i = 1:nSwaps
                order(swapIdxes(i)) = odds(i);
            end
            c = obj.children;
            childOrder = c(order);
            sum = 0;
            for child = childOrder
                sum = sum + child.fullDuration;
            end
            obj.durCached = sum + (obj.repeatDelay*(obj.nStimRuns-1));
        end

        function traversedParams = TraverseChildParams()
            % Traverse children
            children = obj.children;
            traversedParams = cell([1, length(children)]);
            for ci = 1:length(children)
                child = children(ci);
                traversedParams{ci} = child.buildParams;
            end
        end
        %% end buildParams
    end

    function out = GetNodeStartTimes(obj)
        if strcmpi(obj.childRel, 'odd') ...
                || obj.nStimRuns == 1 ...
                || obj.fullDuration == -1
            out = [obj.startDelay];
        else
            out = linspace(obj.startDelay, obj.fullDuration, obj.nStimRuns); 
        end
        % keyboard; % TODO TEST
        % repmat(obj.repeatDelay, [1 obj.nStimRuns-1]) + linspace(obj.startDelay, obj.)
    end
    % 
    % function out = GetChildStartTimes(obj)
    %     children = obj.children;
    %     if obj.isLeafNode
    %         out = [];
    %     elseif strcmpi(obj.childRel, 'sim')
    %         out = obj.GetNodeStartTimes - obj.startDelay;
    %     elseif any(regexpi(obj.childRel, 'odd'))
    %         out = [];
    %         for i = 1:length(obj.childExecutionSequence)
    %             for j = 1:length(subsequence)
    % 
    %             end
    %         end
    %     else
    %         for i = 1:length(obj.childExecutionSequence)
    %             for j = 1:length(subsequence)
    % 
    %             end
    %         end
    %     end
    % end

    %% Attribute-like functions
    function children = children(obj)
        children = [obj.treeHandle{obj.childIdxes}];
    end

    function out = FindOddballChildren(obj)
        if strcmpi(obj.childRel, 'odd') || obj.containsOdd
            out = true;
        elseif obj.isLeafNode
            out = false;
        else
            out = false;
            children = obj.children();
            for child = children
                if child.FindOddballChildren
                    out = true;
                    return
                end
            end
        end
    end

    function isRootNode = isRootNode(obj)
        isRootNode = obj.idx == obj.treeHandle.rootNodeIdx;
    end

    function isLeafNode = isLeafNode(obj)
        % returns whether the node is a **CONNECTED** leaf node. Ignores
        % empty nodes that were removed on cleanup.
        isLeafNode = ~isempty(obj.stimParams) && isempty(obj.children);
    end

    function allTargets = targets(obj)
        % tree traversal to find all child targets
        %TODO caching here would be SO HELPFUL but not a priority rn
        if ~obj.isLeafNode
            allTargets = {};
            children = obj.children;
            for i = 1:length(children)
                child = children(i);
                allTargets = [allTargets, child.targets]; %#ok<AGROW>
            end
        else
            allTargets = obj.selfTargets;
        end
    end

    function childTargets = childTargets(obj)
        % returns the list of the direct targets of the children.
        childTargets = [];
        if ~obj.isLeafNode
            children = obj.children;
            for i = 1:length(children)
                child = children(i);
                childTargets = [childTargets child.targets];
            end
        end
    end

    function targets = selfTargets(obj)
        % direct targets
        targets = {};
        if ~isempty(obj.stimParams)
            targets = obj.stimParams.targetDevices;
        end
    end

    function duration = durationMs(obj)
        if ~isempty(obj.durCached)
            duration = obj.durCached;
            return
        end
        if ~obj.isLeafNode
            children = obj.children;
            if strcmpi(obj.childRel, 'sim') 
                % children occur simultaneously - only count longest duration
                stimDur = 0;
                for i = 1:length(children)
                    stimDur = max(stimDur, children(i).fullDuration);
                end
                duration = obj.nStimRuns*(stimDur + obj.repeatDelay) - obj.repeatDelay;
            elseif strcmpi(obj.childRel, 'seq')
                % children occur sequentially. consider a single stim
                stimDur = 0;
                for i = 1:length(children)
                    stimDur = stimDur + children(i).fullDuration;
                end
                duration = obj.nStimRuns*(stimDur + obj.repeatDelay) - obj.repeatDelay;
            elseif any(regexpi(obj.childRel, 'odd'))
                children = obj.children;
                total = 0;
                for i = 1:length(obj.childExecutionSequence)
                    subsequence = obj.childExecutionSequence{i};
                    for j = 1:length(subsequence)
                        child = children(subsequence(j));
                        total = total + child.fullDuration;
                        if j ~= length(subsequence)
                            total = total + obj.repeatDelay;
                        end
                    end
                end
                duration = total;
            else
                % this is an empty node, but we'll keep it in for indexing
                % purposes.
                duration = 0;
            end
        else
            % leaf node.
            if strcmpi(obj.stimParams.type, 'serial')
                if ~contains(obj.stimParams.targetDevices, 'QST')
                    stimDur = 0;
                else
                    stimDur = max([obj.stimParams.commands.dStimulus]);
                end
            else
                stimDur = obj.stimParams.duration;
            end
            duration = stimDur;
        end
        try
            obj.durCached = duration;
        catch e
            keyboard;
        end
    end

    function duration = fullDuration(obj)
        if ~any(regexpi(obj.childRel, 'odd'))
            duration = (obj.durationMs + obj.repeatDelay)*obj.nStimRuns + obj.startDelay - obj.repeatDelay;
        else
            duration = obj.durationMs + obj.startDelay;
        end
    end
end

methods(Access=private)
    %% PRIVATE FUNCTIONS
    

    function out = childfcn(obj, fcnHandle)
        out = [];
        children = obj.children;
        for i = 1:length(children)
            out = [out child.fcnHandle];
        end
    end
end

% methods(Static,Access=private)
%     function out = protectedField(fieldName)
%         out = strcmpi(fieldName, 'sequenceStack') || strcmpi(fieldName, 'startTimes');
%     end
% end
end