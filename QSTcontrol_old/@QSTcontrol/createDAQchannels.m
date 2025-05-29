function createDAQchannels(obj)

% Analog Input: Thermode Surfaces
for ii = 1:obj.nThermodes
    id  = char(64+ii);
    % manually edited to take away the 2nd QST probe options
    % ch  = obj.DAQ.addAnalogInputChannel('Dev1',(1:5)+(8*(ii-1)),'Voltage');
    ch  = obj.DAQ.addAnalogInputChannel('Dev1',(1:2),'Voltage');
    tmp = arrayfun(@(x) {['Surface ' id num2str(x)]},1:5);
    [ch.Name] = tmp{:};
    set(ch,...
        'TerminalConfig',   'SingleEnded', ...
        'Range',            [-5 5]);    
end

% Analog Input: Aurora Force OUT
ch = obj.DAQ.addAnalogInputChannel('Dev1',3,'Voltage');
set(ch,...
    'Name',             'Aurora Force OUT', ...
    'TerminalConfig',   'SingleEnded')

% Analog Input: Aurora Length OUT
ch = obj.DAQ.addAnalogInputChannel('Dev1',4,'Voltage');
set(ch,...
    'Name',             'Aurora Length OUT', ...
    'TerminalConfig',   'SingleEnded')

% Analog Input: DC Temperature Controller
ch = obj.DAQ.addAnalogInputChannel('Dev1',0,'Voltage');
set(ch,...
    'Name',             'DC Temperature Controller', ...
    'TerminalConfig',   'SingleEnded')

% TTL Input: Stimulus Onset
for ii = 1:obj.nThermodes
    id = char(64+ii);
    ch = obj.DAQ.addDigitalChannel('Dev1',['port0/line' num2str(ii)],'InputOnly');
    ch.Name = ['TTL Thermode ' id ': Onset'];
end

% TTL Input: Galvo
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line20:21','InputOnly');
ch(1).Name = 'TTL ScanImage: Res Galvo';
ch(2).Name = 'TTL ScanImage: Y Galvo';

% TTL Output: ScanImage
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line3','OutputOnly'); %gunk in board. had to change channels
% ch = obj.DAQ.addDigitalChannel('Dev1','port0/line17:21','OutputOnly');
ch(1).Name = 'TTL ScanImage: Acq Start';

ch = obj.DAQ.addDigitalChannel('Dev1','port0/line5:6','OutputOnly');
ch(1).Name = 'TTL ScanImage: Acq Stop';
ch(2).Name = 'TTL ScanImage: Next File';

% TTL Output: Widefield Imaging (Basler) %%CJW EDIT 2023.04.04
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line4','OutputOnly');
ch(1).Name = 'TTL Basler: Frame Trigger';
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line23','OutputOnly');
ch(1).Name = 'TTL Basler: UNUSED';

% % TTL Output: Widefield Imaging (Basler) %%CJW ADD 2018.11.06
% ch = obj.DAQ.addDigitalChannel('Dev1','port0/line22:23','OutputOnly');
% ch(1).Name = 'TTL Basler: Frame Trigger';
% ch(2).Name = 'TTL Basler: UNUSED';

% TTL Output: LED Control %%CJW ADD 2018.11.07 %% CJW and PB changed on 2025.05.01
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line0','OutputOnly');
% ch = obj.DAQ.addDigitalChannel('Dev1','port0/line24','OutputOnly');
ch.Name = 'BLUE LED';
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line25','OutputOnly');
ch.Name = 'GREEN LED';

% TTL Output: Auditory Stimulus %%CJW ADD 2019.06.05
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line26','OutputOnly');
ch(1).Name = 'Speaker';

% TTL Output: Optical Stimulus (LED) %%CJW ADD 2019.06.05
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line27','OutputOnly');
ch(1).Name = 'Optical Stimulus';

% TTL Output: Hamamatsu Camera Drive %%CJW ADD 2019.06.05
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line28','OutputOnly');
ch(1).Name = 'HamamatsuTrigger';

% TTL Output: LED
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line29','OutputOnly');
ch(1).Name = 'LED';

% TTL Output: IR LED
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line30','OutputOnly');
ch(1).Name = 'IRLED_BaslerImaging';


% Digital Output: Vibration Motors
for ii = 1:obj.nThermodes
    id = char(64+ii);
    ch = obj.DAQ.addDigitalChannel('Dev1',['port0/line' num2str(ii+1)],'OutputOnly');
    ch.Name = ['Vibration ' id];
end

% Digital Output: Thermode Trigger
ch = obj.DAQ.addDigitalChannel('Dev1','port0/line7','OutputOnly');
ch(1).Name = 'Thermode Trigger';

% Analog Output: Piezo Driver %added 2022.03.18. edited port 2022.04.12
            ch = obj.DAQ.addAnalogOutputChannel('Dev1',0,'Voltage');
            set(ch,...
                'Name',             'Aurora Force Command Voltage', ...
                'TerminalConfig',   'SingleEnded', ...
                'Range',            [0 10]);
                


