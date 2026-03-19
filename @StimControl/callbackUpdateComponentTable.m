function callbackUpdateComponentTable(obj, src, event)
    if isstring(event) && strcmpi(event, "CreateTable")
        obj.h.AvailableHardwareTable.Data = PopulateHardwareTable();
    elseif src == obj.h.menuRefreshHardware % refresh hardware
        selection = uiconfirm(obj.h.fig, ...
            "WARNING: This will reset any unsaved changes made to existing hardware configurations. Continue?","Confirm Reload", ...
            "Icon","warning", ...
            "Options", ["Save & Continue", "Continue Without Saving", "Cancel"]);
        if ~strcmpi(selection, "Cancel")
            obj.indicateLoading("Searching for hardware...")
            if strcmpi(selection, "Save & Continue")
                obj.callbackSaveConfig(src, event)
                % get filename
                filename = obj.h.SessionSelectDropDown.Value;
                obj.d = obj.d.FindAvailableHardware();
            elseif strcmpi(selection, "Continue Without Saving")
                filename = [];
            end
            obj.h.AvailableHardwareTable.Data = PopulateHardwareTable(); % refresh GUI
            obj.loadDefaultSession;
            if ~isempty(filename) % reload saved info.
                obj.h.SessionSelectDropDown.Value = filename;
                obj.callbackLoadConfig()
            end
            obj.MapConnectedHardware;
            obj.status = obj.status;
        else % cancel
            return;
        end
    else % update data in existing table
        idxRow = event.Indices(1);
        property = src.Data.Properties.VariableNames(event.Indices(2));
        component = obj.d.Available{idxRow};
        if strcmpi(property, "ProtocolID")
            component.SetParam("ProtocolID", event.NewData);
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
    end

    function tData = PopulateHardwareTable()
    columnNames = {'Type', 'ID', 'ProtocolID', 'Status', 'Enable', 'Preview', 'PRow', 'PColumn'};
    tData = table();
    available = obj.d.Available;
    if isempty(obj.d.Available) % prevent errors with no hardware attached
        return
    end
    for i = 1:length(obj.d.Available)
        device = obj.d.Available{i};
        tData(end+1, :) = {class(device), ...
                            device.ComponentID, ...
                            device.ConfigStruct.ProtocolID, ...
                            device.GetStatus, ...
                            ~isempty(device.SessionHandle), ...
                            device.Previewing, ...
                            cellstr(num2str(device.PreviewPlot.Parent.Parent.Layout.Row)), ...
                            cellstr(num2str(device.PreviewPlot.Parent.Parent.Layout.Column))};
    end
    
    tData.Properties.VariableNames = columnNames;
end
end