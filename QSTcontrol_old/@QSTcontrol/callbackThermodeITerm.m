function callbackThermodeITerm(obj,hCheck,~)

nTherm  = int8(hCheck.Tag(1))-64;
tmp = obj.s(nTherm).query(sprintf('I%d P',hCheck.Value));
hCheck.Value = cellfun(@str2double,regexp(tmp,'I(\d)','Tokens','once'));