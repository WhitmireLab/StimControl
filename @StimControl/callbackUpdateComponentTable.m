function callbackUpdateComponentTable(obj, src, event)
    if isstring(event) && strcmpi(event, "CreateTable")
        obj.h.AvailableHardwareTable.Data = PopulateHardwareTable();
    elseif src == obj.h.menuRefreshHardware % refresh hardware
        if obj.h.tabs.SelectedTab ~= obj.h.Setup.Tab % if selected tab isn't setup, don't allow this.
            obj.errorMsg("Please switch to the setup tab before reloading hardware.");
            return
        end
        stop(obj.timerStateMachine); % pause the timers to prevent errors in iterating over devices
        stop(obj.timerGui);
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
                filename = obj.h.SessionSelectDropDown.Value;
            end
            obj.createPanelPreview(obj.h.Preview.panel.params, []); % update preview panel
            obj.h.AvailableHardwareTable.Data = PopulateHardwareTable(); % refresh hardware table
            obj.loadDefaultSession;
            if ~isempty(filename) && isfile([obj.path.sessionBase filesep filename]) % reload saved info.
                obj.h.SessionSelectDropDown.Value = filename;
                obj.callbackLoadConfig(obj.h.SessionSelectDropDown, []);
            end
            obj.MapConnectedHardware;
            obj.clearMessage;
            obj.createChans = true;
            start(obj.timerStatemachine); % restart the timers
            start(obj.timerGui)
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