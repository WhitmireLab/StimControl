function callbackProtocolNstim(obj,hCtrl,~)

if isempty(obj.p)
    return
end

if strcmp(hCtrl.Style,'pushbutton')
    switch hCtrl.String
        case '>'
            if obj.idxStim < length(obj.p)
                obj.idxStim = obj.idxStim + 1;
            else
                obj.idxStim = 1;
            end
        case '<'
            if obj.idxStim > 1
                obj.idxStim = obj.idxStim - 1;
            else
                obj.idxStim = length(obj.p);
            end
    end
end
