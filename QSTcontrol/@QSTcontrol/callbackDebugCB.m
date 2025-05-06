function callbackDebugCB(obj,~,~)
%#ok<*AGROW>

for nTherm = 1:2
    idT     = char(nTherm+64);
    pIn     = strsplit(obj.s(nTherm).query('P'),'\r');
    
    % process first line of parameter block
    tmp     = regexp(pIn{1},'([NTIS]\d*)','tokens');
    p.(idT)	= [tmp{:}];
    
    % process remaining lines of parameter block
    tmp  = cell2mat(cellfun(@(x) {sscanf(x,'C%d V%d R%d D%d')},pIn(2:6)))';
    idParams  = 'CVRD';
    precision = '3444';
    for ii = 1:length(idParams)
        if all(~diff(tmp(:,ii)))
            p.(idT) = [p.(idT) sprintf(['%s0%0' precision(ii) 'd'],idParams(ii),tmp(1,ii))];
        else
            for jj = 1:5
                p.(idT) = [p.(idT) sprintf(['%s%d%0' precision(ii) 'd'],idParams(ii),jj,tmp(1,ii))];
            end
        end
    end
end
p          = struct2cell(p);
[pC,iA,iB] = intersect(p{:},'stable');
p{1}(iA)   = [];
p{2}(iB)   = [];
pOut       = [pC cellfun(@(x) {[x 'A']},p{1}) cellfun(@(x) {[x 'B']},p{2})];
pOut       = [pOut; repmat({' '},size(pOut))];
pOut       = deblank([pOut{:}]);

clipboard('copy',pOut)