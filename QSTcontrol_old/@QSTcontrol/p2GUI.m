function p2GUI(obj)

for nTherm = 1:obj.nThermodes
    
    idTherm = ['Thermode' char(64+nTherm)];

    % get current parameters from thermode
    ps = strsplit(obj.s(nTherm).query('P'),'\r');
    h  = obj.h.(idTherm);

    % process first line of parameter block
    p = sscanf(ps{1},'N%d T%d I%d Y%d S%s');
    h.edit.N.Value     = p(1)/10;
    h.edit.N.String    = sprintf('%1.1f',h.edit.N.Value);
    p = num2cell(p(5:end)'==49);
    [h.toggle.S.Value] = p{:};

    % process remaining lines of parameter block
    p = cell2mat(cellfun(@(x) {sscanf(x,'C%d V%d R%d D%d')},ps(2:end)));
    p(1:3,:) = p(1:3,:) / 10;
    f        = {'C','V','R','D'};
    format   = {'%0.1f','%0.1f','%0.1f','%d'};
    for ii = 1:4
        tmp = num2cell(p(ii,:));
        h.check.(f{ii}).Value   = isequal(tmp{:});
        [h.edit.(f{ii}).Value]  = tmp{:};   
        tmp = cellfun(@(x) {sprintf(format{ii},x)},tmp);
        [h.edit.(f{ii}).String] = tmp{:};
    end
        
    % update plots
    obj.createPlotThermode(obj.h.(idTherm).axes)
    obj.createPlotLED(obj.h.LED.axes)
end