function callbackSingleRunStart(obj,~,~)

% disable GUI elemens
hGUI = findobj('Parent',obj.h.fig,'Enable','on');
for hChild = obj.h.fig.Children'
    hGUI = [hGUI;findobj('Parent',hChild,...
        'Enable','on','-not','Style','Text')]; %#ok<AGROW>
end
set(hGUI,'Enable','off')
obj.h.singleRun.push.stop.Enable = 'on';

% create output directory
dirOut    = fullfile(obj.dirAnimal,datestr(now,'yymmdd'),'single');
if ~exist(dirOut,'dir')
    mkdir(dirOut)
end

% number of columns in output files
nCols = length(obj.DAQ.Channels)+1;

% create filename
fnOut = sprintf('%s_%dcol.dbl',datestr(now,'yymmdd_HHMMSS'),nCols);
fnOut = fullfile(dirOut,fnOut);

obj.setTitle('Running Stimulation ...')
obj.stimulate(fnOut)
obj.setTitle()

% Enable GUI elemens
set(hGUI,'Enable','on')
obj.h.singleRun.push.stop.Enable = 'off';