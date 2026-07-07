function callbackEditComponentConfig(obj, ~, ~)
% CALLBACKEDITCOMPONENTCONFIG updates the ComponentConfigPanel to connect
% it to the selected component and its settings. 

%% first, retrieve selected component from obj.
rowIndex = obj.h.AvailableHardwareTable.Selection;
if isempty(rowIndex)
    return;
end
component = obj.d.Available{rowIndex};

%% Pass handle for later use
obj.h.ComponentConfig.SelectedComponentIndex = rowIndex;

% display which component is selected.
for pi = 1:length(obj.h.PreviewPanels)
    pan = obj.h.PreviewPanels{pi};
    if pi == rowIndex
        pan.Parent.Parent.BackgroundColor = '#ADD8E6';
    else
        pan.Parent.Parent.BackgroundColor = [0.9400 0.9400 0.9400];
    end
end
    
%% Enable confirmation and cancel buttons
obj.h.ConfirmComponentConfigBtn.Enable = true;
obj.h.CancelComponentConfigBtn.Enable = true;

%% Populate Config Table
if isfield(component.ConfigStruct, 'ID')
    obj.h.ComponentConfig.Label.Text = component.ConfigStruct.ID;
else
    obj.h.ComponentConfig.Label.Text = class(component);
end

% Create additional config button, if necessary.
if component.HasAdditionalConfig
    obj.h.ComponentConfig.AdditionalConfigBtn.Enable = true;
    obj.h.ComponentConfig.AdditionalConfigBtn.Visible = true;
    obj.h.ComponentConfig.AdditionalConfigBtn.ButtonPushedFcn = ...
            @(src, event)component.CreateConfigFigure(src, event);
else
    obj.h.ComponentConfig.AdditionalConfigBtn.Enable = false;
    obj.h.ComponentConfig.AdditionalConfigBtn.Visible = false;
end

tData = rows2vars(struct2table(component.ConfigStruct, 'AsArray', true));
rowNames = tData{:, 1};
values = tData{:, 2};

for fnum = 1:length(rowNames)
    prop = component.ComponentProperties.(rowNames{fnum});
    if ~isempty(prop.allowable)
        cat = prop.getCategorical;
        configVal = component.ConfigStruct.(rowNames{fnum});
        if ischar(configVal)
            configCat = categorical(cellstr(configVal));
            idx = find(cat == configCat);
            values{fnum} = cat(idx);
        elseif isstring(configVal)
            configCat = categorical(cellstr(configVal));
            idx = find(cat == configCat);
            values(fnum) = {cat(idx)};
        elseif isnumeric(configVal)
            configCat = categorical(configVal);
            idx = find(cat == configCat);
            values(fnum) = {cat(idx)};
        end
    end
end

tData =  table(values, ...
    'RowNames', rowNames);

obj.h.ComponentConfig.Table.Data = tData;
end