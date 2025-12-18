classdef DAQComponentProperties < ComponentProperties
properties (Constant)
ID = ComponentProperty( ...
    'default', DAQComponentProperties.GetDefault('ID'), ...
    'allowable', DAQComponentProperties.GetList('ID'))
ProtocolID = ComponentProperty( ...
    'default', 'Trigger', ...
    'validatefcn', @(x) isstring(x) || ischar(x), ...
    'dynamic', true, ...
    'note', "Maps directly to the computer's protocolMap")
Rate = ComponentProperty( ...
    'default', 1000, ...
    'validatefcn', @(x) (isnumeric(x) && x > 0) || ~isnan(str2double(x)) && str2double(x)>=0, ...
    'note', 'Sampling rate in Hz')
Vendor = ComponentProperty( ...
    'default', DAQComponentProperties.GetDefault('Vendor'), ...
    'allowable', DAQComponentProperties.GetList('Vendor'), ...
    'editable', false, ...
    'note', 'Used to initialise')
Model = ComponentProperty( ...
    'default', '', ...
    'allowable', DAQComponentProperties.GetList('Model'), ...
    'editable', false, ...
    'note', 'Distinguishes between multiple daqs with the same vendor')
ChannelConfig = ComponentProperty( ...
    'validatefcn', @(x) isstring(x) || ischar(x), ...
    'default', DAQComponentProperties.GetDefaultChannelConfig)
end
methods (Static, Access=private)
    function out = GetDefaultChannelConfig()
        % nb returns BASE DIRECTORY ONLY
        base = mfilename('fullpath');
        out = replace(base, ['components' filesep 'DAQComponentProperties'], ['config' filesep 'component_params']);
        
        % if contains(pwd, 'StimControl')
        %     out = [pwd filesep 'config' filesep 'component_params'];
        % else
        %     out = [pwd filesep 'StimControl' filesep 'config' filesep 'component_params'];
        % end
    end

    function out = GetList(type)
        if isempty(daqlist)
            out = {};
            return
        end
        switch lower(type)
            case 'vendor'
                out = unique(cellfun(@(x) x.ID, {daqlist().DeviceInfo.Vendor}, 'UniformOutput', false));
            case 'model'
                out = {daqlist().DeviceInfo.Model};
            case 'id'
                out = {daqlist().DeviceInfo.ID};
        end
    end

    function out = GetDefault(type)
        if isempty(daqlist)
            out = '';
            return
        end
        switch lower(type)
            case 'vendor'
                out = 'ni';
            case 'id'
                out = 'Dev1';
            case 'model'
                out = '';
        end
    end
end
end