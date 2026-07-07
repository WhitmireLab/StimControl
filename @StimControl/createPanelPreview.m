function createPanelPreview(obj, hPanel, ~)
% CREATEPANELPREVIEW creates the panel that holds device previews

numComponents = length(obj.d.Available);
numRows = floor(sqrt(numComponents));
numCols = ceil(numComponents/numRows);

% if the display is being updated and not created, 
% flag that component preview plots should also be updated.
if ~isfield(obj.h, 'PreviewGrid')
    obj.h.PreviewGrid = uigridlayout(hPanel);
end

obj.h.PreviewGrid.RowHeight = repmat("1x", [1 numRows*2]);
obj.h.PreviewGrid.ColumnWidth = repmat("1x", [1 numCols*2]);

obj.h.PreviewPanels = {};
doNothing = @(x, y, z) true;
for i = 1:numRows
    for j = 1:numCols
        componentIdx = ((i-1) * numCols) + j;
        if obj.d.nActive < componentIdx
            return
        end
        component = obj.d.Available{componentIdx};
        gi = i*2;
        gj = j*2;
        panel = uipanel(obj.h.PreviewGrid, ...
            'CreateFcn', doNothing,...
            'Layout', matlab.ui.layout.GridLayoutOptions( ...
                'Row', [gi-1 gi], ...
                'Column', [gj-1 gj]));
        panelGrid = uigridlayout(panel, ...
            'RowHeight', {'1x'}, ...
            'ColumnWidth', {'1x'});
        ax = uiaxes(panelGrid, ...
            'Layout', matlab.ui.layout.GridLayoutOptions( ...
                'Row', 1, ...
                'Column', 1), ...
            'XTick', [], ...
            'XTickLabel', [], ...
            'YTick', [], ...
            'YTickLabel', []);
        
        panel.Title = component.ConfigStruct.ProtocolID;
        obj.h.PreviewPanels{end+1} = ax;
        component.UpdatePreview('newPlot', obj.h.PreviewPanels{end});
    end
end
end