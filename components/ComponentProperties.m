classdef (Abstract, HandleCompatible) ComponentProperties < handle
    properties (Abstract, Constant, Access=public)
        ID
        ProtocolID
    end

    methods
        function out = isfield(obj, fieldName)
            f = properties(obj);
            if ~any(cellfun(@(x) strcmpi(fieldName, x), f))
                out = false;
            else
                out = true;
            end
        end

        function out = fields(obj)
            out = properties(obj);
        end
    end
end
