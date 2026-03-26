function callbackChangeTab(obj, src, event)
if strcmpi(event.NewValue.Title, 'Experiment')
    % move components over
    for i = 1:length(obj.d.Available)
        component = obj.d.Available{i};
        % if obj.d.Active(i)
        %     % make sure device is initialised
        %     if isempty(component.SessionHandle)
        %         component.InitialiseSession();
        %     end
        if ~obj.d.Active(i)
            % de-initialise unnecessary devices
            try
                component.Stop();
            catch exc
                disp("[CALLBACKCHANGETAB] fix this when you have a second")
            end
        end
    end
    % remove selection indicator from preview background colour
    for pi = 1:length(obj.h.PreviewPanels)
        pan = obj.h.PreviewPanels{pi};
            pan.Parent.Parent.BackgroundColor = [0.9400 0.9400 0.9400];
    end
    obj.createPanelSessionHardware(obj.h.Session.HardwareStatus.panel.params);
elseif strcmpi(event.NewValue.Title, 'Setup')
    % If experiment is running, swap it back. (can't disable the tab so this is the next best thing)
    if contains("running, inter-trial, paused, awaiting trigger, stopping", obj.status)
        obj.warnMsg("Can't change tabs when a trial is running. Stop the trial and try again.");
        obj.h.tabs.SelectedTab = obj.h.Session.Tab;
        return
    else
        for i = 1:length(obj.d.Available)
            component = obj.d.Available{i};
            try
                component.Stop(); %stop components so their properties can be changed
            catch error
                disp(sprintf("Error stopping component ", component.ConfigStruct.ProtocolID));
            end
        end
    end
end
% warning: cursed. Moves the preview panels to the new tab.
obj.h.Preview.panel.params.Parent = event.NewValue.Children;
end