classdef ProtocolCheckerGUI < handle

    % Properties that correspond to app components
    properties (Access = public)

    end

    
    properties (Access = private)
        h = [];
        p = [];
        g = [];
        err = [];
        figs = {};
    end
    
    methods (Access = private)
        
        function fpath = LoadDlg(obj, src, event)
            folder = mfilename('fullpath');
            idx = strfind(folder, ['common' filesep 'checkprotocol']) - 1;
            folder = [folder(1:idx) 'config' filesep 'experiment_protocols' filesep '*.stim'];
            [filename, dir] = uigetfile(folder);
            if filename == 0
                fpath = [];
                return
            end
            fpath = [dir filesep filename];
        end

        function [p, g, err] = ProcessFile(obj, fpath)
            p = [];
            g = [];
            err = [];
            if contains(fpath, '.stim')
                try
                    [p, g] = readProtocol(fpath, true);
                catch err
                    err = err.message;
                end
            else
                err = "Unsupported file format. Supported formats: .stim";
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Callback function: PlotButton, TrialTable
        function PlotTrial(obj, src, event)
            if isempty(obj.p)
                return
            end
            index = obj.h.TrialTable.Selection;
            if isempty(index)
                for i = 1:length(obj.p)
                    trial = obj.p(i);
                    obj.figs{end+1} = trial.Plot();
                end
            else
                trial = obj.p(index);
                obj.figs{end+1} = trial.Plot();
            end
        end

        % Selection changed function: TrialTable
        function InspectTrial(obj, src, event)
            index = obj.h.TrialTable.Selection;
            if isempty(index)
                obj.h.PlotButton.Text = 'Plot All';
                return
            end
            obj.h.PlotButton.Text = 'Plot';
            trial = obj.p(index);
            if trial.valid
                statusMsg = "valid";
            else
                statusMsg = "INVALID";
            end
            params = strsplit(trial.line, '%');
            params = params{1};
            params = strtrim(params);
            obj.h.InformationLabel.Text = sprintf("Trial %d - %s \n(%s) \n\n" + ...
                " %s \n\n" + ...
                "%s ", index, statusMsg, trial.comment, params, trial.errorMsg);                
        end

        % Button pushed function: BrowseButton
        function BrowseTestProtocols(obj, src, event)
            fpath = obj.LoadDlg(src, event);
            if isempty(fpath)
                return
            end
            obj.h.FilePathField.Value = fpath;
            obj.LoadTestProtocol(src, event);
        end

        % Button pushed function: RefreshButton
        function LoadTestProtocol(obj, src, event)
            fpath = obj.h.FilePathField.Value;
            obj.p = [];
            obj.g = [];
            obj.err = [];
            [obj.p, obj.g, obj.err] = ProcessFile(obj, fpath);
    
            if ~isempty(obj.err)
                obj.h.InformationLabel.Text = sprintf("Error reading protocol: %s", obj.err);
            else
                obj.h.InformationLabel.Text = "Protocol Loaded Successfully.";
            end
    
            % fill out table
            tData = table();
            for i = 1:length(obj.p)
                trial = obj.p(i);
                if trial.valid
                    statusMsg = "valid";
                else
                    statusMsg = sprintf("INVALID");
                end
                tData{end+1, :} = {i, statusMsg};
            end
            obj.h.TrialTable.Data = tData;
        end

        % Close request function: fig
        function figCloseRequest(obj, src, event)
            for i = 1:length(obj.figs)
                fig = obj.figs{i};
                if ~isempty(fig) && isvalid(fig)
                    delete(fig);
                end
            end
            delete(obj.h.fig)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(obj, src, event)

            % Create fig and hide until all components are created
            obj.h.fig = uifigure('Visible', 'off');
            obj.h.fig.Position = [100 100 484 490];
            obj.h.fig.Name = 'Protocol Checker';
            obj.h.fig.CloseRequestFcn = @(src, event) obj.figCloseRequest(src, event);

            % Create GridLayout
            obj.h.GridLayout = uigridlayout(obj.h.fig);
            obj.h.GridLayout.ColumnWidth = {'1x'};
            obj.h.GridLayout.RowHeight = {'1x'};
            obj.h.GridLayout.ColumnSpacing = 6;
            obj.h.GridLayout.RowSpacing = 0;
            obj.h.GridLayout.Padding = [6 0 6 0];

            % Create Panel
            obj.h.Panel = uipanel(obj.h.GridLayout);
            obj.h.Panel.Layout.Row = 1;
            obj.h.Panel.Layout.Column = 1;

            % Create MainGrid
            obj.h.MainGrid = uigridlayout(obj.h.Panel);
            obj.h.MainGrid.ColumnWidth = {'1x', 50, 50};
            obj.h.MainGrid.RowHeight = {22, '1x', '1x'};

            % Create StatusPanel
            obj.h.StatusPanel = uipanel(obj.h.MainGrid);
            obj.h.StatusPanel.Layout.Row = 3;
            obj.h.StatusPanel.Layout.Column = [1 3];
            obj.h.StatusPanel.Scrollable = 'on';

            % Create statusGrid
            obj.h.statusGrid = uigridlayout(obj.h.StatusPanel);
            obj.h.statusGrid.ColumnWidth = {'1x', 50};
            obj.h.statusGrid.RowHeight = {'1x', 22};

            % Create InformationLabel
            obj.h.InformationLabel = uilabel(obj.h.statusGrid);
            obj.h.InformationLabel.VerticalAlignment = 'top';
            obj.h.InformationLabel.WordWrap = 'on';
            obj.h.InformationLabel.Layout.Row = [1 2];
            obj.h.InformationLabel.Layout.Column = [1 2];
            obj.h.InformationLabel.Text = 'Trial Information, when selected.';

            % Create PlotButton
            obj.h.PlotButton = uibutton(obj.h.statusGrid, 'push');
            obj.h.PlotButton.ButtonPushedFcn = @(src, event) obj.PlotTrial(src, event);
            obj.h.PlotButton.Tooltip = {'Refresh the contents of the TextArea above to match the contents of the file it was loaded from'};
            obj.h.PlotButton.Layout.Row = 2;
            obj.h.PlotButton.Layout.Column = 2;
            obj.h.PlotButton.Text = 'Plot';

            % Create TrialTable
            obj.h.TrialTable = uitable(obj.h.MainGrid);
            obj.h.TrialTable.ColumnName = {'Trial No.'; 'Status'};
            obj.h.TrialTable.RowName = {};
            obj.h.TrialTable.SelectionType = 'row';
            obj.h.TrialTable.DoubleClickedFcn = @(src, event) obj.PlotTrial(src, event);
            obj.h.TrialTable.SelectionChangedFcn = @(src, event) obj.InspectTrial(src, event);
            obj.h.TrialTable.Multiselect = 'off';
            obj.h.TrialTable.Layout.Row = 2;
            obj.h.TrialTable.Layout.Column = [1 3];

            % Create RefreshButton
            obj.h.RefreshButton = uibutton(obj.h.MainGrid, 'push');
            obj.h.RefreshButton.ButtonPushedFcn = @(src, event) obj.LoadTestProtocol(src, event);
            obj.h.RefreshButton.Tooltip = {'Refresh the current file with new changes.'};
            obj.h.RefreshButton.Layout.Row = 1;
            obj.h.RefreshButton.Layout.Column = 3;
            obj.h.RefreshButton.Text = 'Refresh';

            % Create BrowseButton
            obj.h.BrowseButton = uibutton(obj.h.MainGrid, 'push');
            obj.h.BrowseButton.ButtonPushedFcn = @(src, event) obj.BrowseTestProtocols(src, event);
            obj.h.BrowseButton.Tooltip = {'Select a file to parse'};
            obj.h.BrowseButton.Layout.Row = 1;
            obj.h.BrowseButton.Layout.Column = 2;
            obj.h.BrowseButton.Text = 'Browse';

            % Create FilePathField
            obj.h.FilePathField = uieditfield(obj.h.MainGrid, 'text');
            obj.h.FilePathField.Layout.Row = 1;
            obj.h.FilePathField.Layout.Column = 1;
            obj.h.FilePathField.Value = 'test';

            % Show the figure after all components are created
            obj.h.fig.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function obj = ProtocolCheckerGUI

            % Create UIFigure and components
            createComponents(obj)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(obj)

            % Delete UIFigure when app is deleted
            delete(obj.h.fig)
        end
    end
end