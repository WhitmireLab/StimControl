function p2serial(obj,p)

for ii = 1:length(obj.s)
    idTherm = sprintf('Thermode%s',64+ii);
    if ~isfield(p,idTherm)
        continue
    end
    
    % build command stack
    stack = {};
    for param = fieldnames(p.(idTherm))'
        val = p.(idTherm).(param{:});
        switch param{:}
            case 'NeutralTemp'
                cmd = sprintf('N%03d',round(val*10));
            case 'SurfaceSelect'
                cmd = sprintf('S%d%d%d%d%d',val>0);
            case 'SetpointTemp'
                cmd = helper('C%d%03d',round(val*10));
            case 'PacingRate'
                cmd = helper('V%d%04d',round(val*10));
            case 'ReturnSpeed'
                cmd = helper('R%d%04d',round(val*10));
            case 'dStimulus'
                cmd = helper('D%d%05d',round(val));
            case 'nTrigger'
                cmd = sprintf('T%03d',round(val));
            case 'integralTerm'
                cmd = sprintf('I%d',round(val));
        end
        stack = [stack cmd]; %#ok<AGROW>
    end
    
    % send command stack to thermode
    tmp = [stack; repmat({' '},size(stack))];
    obj.s(ii).query([tmp{:}]);
end

    function out = helper(format,val)
        if all(val==val(1))
            out = sprintf(format,0,val(1));
        else
            out = cell(1,sum(~isnan(val)));
            for idx = find(~isnan(val))
                out{idx} = sprintf(format,idx,val(idx));
            end
        end
    end
end