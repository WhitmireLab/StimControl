function [p, g, cam, d] = Debug()
%DEBUG Summary of this function goes here
%   Detailed explanation goes here
baseDir = [pwd filesep 'StimControl'];
protocolPath = [baseDir filesep 'protocolfiles' filesep 'TempandVibe.stim'];
hardwareParamPath = [baseDir filesep 'paramfiles' filesep 'HardwareParams.json'];
daqConfigPath = [baseDir filesep 'paramfiles' filesep 'Default_OuterLab_DaqChanParams.csv'];

[p, g] = readProtocol(protocolPath);
objs = readHardwareParams(hardwareParamPath);
cam = objs.camera1;
d = objs.daq1;
d.Configure('ChannelConfig', daqConfigPath);
end

