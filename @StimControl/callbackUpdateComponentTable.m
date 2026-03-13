function callbackUpdateComponentTable(obj, src, event)
    idxRow = event.Indices(1);
    property = src.Data.Properties.VariableNames(event.Indices(2));
    component = obj.d.Available{idxRow};
    if strcmpi(property, "ProtocolID")
        component.SetParam("ProtocolID", event.NewData);
        % TODO REFRESH BUTTON
        obj.d.ProtocolIDMap = remove(obj.d.ProtocolIDMap, event.PreviousData);
        obj.d.ProtocolIDMap(event.NewData) = idxRow;
    elseif strcmpi(property, "Enable")
        if event.NewData
            obj.d.Active(idxRow) = true;
            component.InitialiseSession();
        else
            obj.d.Active(idxRow) = false;
            component.Stop();
            component.Close(); %TODO RE-INITIALISE ON STARTUP
            src.Data.Preview(idxRow) = false;
            component.PreviewPlot.Parent.Parent.Visible = "off";
            component.StopPreview();
        end
    elseif strcmpi(property, "Preview")
        if event.NewData    
            if ~obj.d.Active(idxRow)
                % can't preview if not active.
                src.Data.Preview(idxRow) = false;
                return
            end
            component.PreviewPlot.Parent.Parent.Visible = "on";
            component.StartPreview();
        else
            component.PreviewPlot.Parent.Parent.Visible = "off";
            component.StopPreview();
        end
        %TODO automatically re-shuffle other preview plots to fill the gap?
    elseif strcmpi(property, "PRow") || strcmpi(property, "PColumn")
        property = property{:};
        property = property(2:end);
        component.PreviewPlot.Parent.Parent.Layout.(property) = str2num(event.NewData); %#ok
    end

    % % update preview display
    % obj.h.Preview.panel.params.Children(1).Children; % the panels within the grid (can also go through obj.d)
    % obj.h.Preview.panel.params.Children; % the grid
end