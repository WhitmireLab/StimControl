function createPanelComponentConfig(obj, hPanel, ~)
% function createPanelThermode(obj,hPanel,~,idxThermode,nThermodes)
%     obj.h.(thermodeID).panel.params = uipanel(obj.h.fig,...
%         'CreateFcn',    {@obj.createPanelThermode,ii,length(obj.s)});

grid = uigridlayout(hPanel);
grid.RowHeight = {23, '1x', 23};
grid.ColumnWidth = {'1x', '1x'};

obj.h.ComponentConfig.Label = uilabel(grid, "Text", "No Component Selected", ...
    'Layout', matlab.ui.layout.GridLayoutOptions( ...
        'Row', 1, ...
        'Column', [1 2]));

obj.h.ComponentConfig.Table = uitable(grid, 'Data', table(), ...
    'ColumnEditable', true, ...
    'ColumnWidth', {100}, ...
    'Layout', matlab.ui.layout.GridLayoutOptions( ...
        'Row', 2, ...
        'Column', [1 2]), ...
    'DisplayDataChangedFcn', @(src, event) updateComponentConfigTable(src, event, obj));

obj.h.ConfirmComponentConfigBtn = uibutton(grid, 'Text', 'Confirm', ...
    'Layout', matlab.ui.layout.GridLayoutOptions( ...
        'Row', 3, ...
        'Column', 2), ...
    'ButtonPushedFcn', @(src, event) confirmComponentConfig(obj, src, event), ...
    'Enable', false);

obj.h.CancelComponentConfigBtn = uibutton(grid, 'Text', 'Cancel', ...
    'Layout', matlab.ui.layout.GridLayoutOptions( ...
        'Row', 3, ...
        'Column', 1), ...
    'ButtonPushedFcn', @(src, event) cancelComponentConfig(obj, src, event), ...
    'Enable', false);

end

%% UPDATE FUNCTIONS

%% update table
function updateComponentConfigTable(src,event,obj)
    rownum  = event.DisplaySelection(1);
    component = obj.d.Available{obj.h.ComponentConfig.SelectedComponentIndex};
    propertyName = event.DisplayRowName{rownum};
    c = 1;
    if iscategorical(event.Source.Data{rownum, 1}{1}) 
        % TODO possible to add categories? 
        % if you want, change protected=true in ComponentProperty.getCategorical
    elseif ~component.ComponentProperties.(propertyName).validatefcn(src.Data{rownum,c}{1}) %validate function
        % new value is invalid
        sInvalid = uistyle('BackgroundColor','red');
        addStyle(src,sInvalid,'row', rownum);
        obj.errorMsg(sprintf("%s: %s must fulfil the following: %s", ...
            propertyName, component.ConfigStruct.ProtocolID, ...
            func2str(component.ComponentProperties.(propertyName).validatefcn)));
    end
    removeStyle(src);
    newVal = src.Data.values{rownum};
    if iscategorical(newVal)
        cats = categories(newVal);
        idx = find(categorical(cats) == newVal);
        newVal = cats{idx};
        if ~isnan(str2double(newVal))
            newVal = str2double(newVal);
        end
    end
    component.ConfigStruct.(propertyName) = newVal;
    if component.ComponentProperties.(propertyName).dynamic
        component.SetParam(propertyName, newVal);
    else
        sUnsaved = uistyle('BackgroundColor', [1 0.8 0]);
        addStyle(src,sUnsaved,'row', rownum);
        obj.warnMsg(sprintf("%s: %s requires a device restart to take effect. Press 'confirm' or lose your changes!", ...
            propertyName, component.ConfigStruct.ProtocolID));
        if ~isfield(obj.h.ComponentConfig, 'ValsToUpdate') || isempty(obj.h.ComponentConfig.ValsToUpdate)
            obj.h.ComponentConfig.ValsToUpdate = struct(propertyName, newVal);
        else
            obj.h.ComponentConfig.ValsToUpdate.(propertyName) = newVal;
        end
    end
end

%% Confirm / Cancel Component Configs
function confirmComponentConfig(obj, src, event)
% Configure component
component = obj.d.Available{obj.h.ComponentConfig.SelectedComponentIndex};
if isfield(obj.h.ComponentConfig, 'ValsToUpdate')
    component.SetParams(obj.h.ComponentConfig.ValsToUpdate);
end
% Then clear everything
obj.status = obj.status; % clear warning messages
removeStyle(obj.h.ComponentConfig.Table);
cancelComponentConfig(obj, src, event);
end

function cancelComponentConfig(obj, src, event)
obj.h.ComponentConfig.Label.Text = "No Component Selected";
obj.h.ComponentConfig.Component.Handle = [];
obj.h.ComponentConfig.Component.Properties = [];
obj.h.ComponentConfig.Table.Data = table();
obj.h.ComponentConfig.ValsToUpdate = struct();

obj.h.ConfirmComponentConfigBtn.Enable = false;
obj.h.CancelComponentConfigBtn.Enable = false;
end