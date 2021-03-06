function PDAFit(~,~)
% PDAFit Global Analysis of PDA data
%
%      To use the program, simply call PDAFit at command line.
%
%      The PDAData structure contains original experimental data and a
%      number of parameters exported from BurstBrowser (gamma,
%      crosstalk, direct excitation, background, lifetime, anisotropy...).
%
%      Saving PDA project saves the above back into the PDA file.
%      When data is saved in the global PDA program, the fit parameters obtained
%      after fitting are also saved back into the file.
%
%      The h structure contains the user interface.
%
%      The PDAMeta structure contains all metadata generated during program usage
%
%   2017 - FAB Lab Munich - Don C. Lamb

%%% TO DO:
%%% Fix Brightness correction
%%% Implement donor only for MLE and MC fitting

global UserValues PDAMeta PDAData

h.GlobalPDAFit=findobj('Tag','GlobalPDAFit');

addpath(genpath(['.' filesep 'functions']));

LSUserValues(0);
Look=UserValues.Look;

if isempty(h.GlobalPDAFit)
    %% Disables uitabgroup warning
    warning('off','MATLAB:uitabgroup:OldVersion');
    %% Define main window
    h.GlobalPDAFit = figure(...
        'Units','normalized',...
        'Name','GlobalPDAFit',...
        'NumberTitle','off',...
        'MenuBar','none',...
        'defaultUicontrolFontName',Look.Font,...
        'defaultAxesFontName',Look.Font,...
        'defaultTextFontName',Look.Font,...
        'OuterPosition',[0.01 0.05 0.78 0.9],...
        'UserData',[],...
        'Visible','on',...
        'Tag','GlobalPDAFit',...
        'Toolbar','figure',...
        'CloseRequestFcn',@Close_PDA);
    
    whitebg(h.GlobalPDAFit, Look.Axes);
    set(h.GlobalPDAFit,'Color',Look.Back);
    %%% Remove unneeded items from toolbar
    toolbar = findall(h.GlobalPDAFit,'Type','uitoolbar');
    toolbar_items = findall(toolbar);
    delete(toolbar_items([2:7 9 13:17]));
    %% Menubar %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % File Menu
    h.Menu.File = uimenu(...
        'Parent',h.GlobalPDAFit,...
        'Label','File',...
        'Tag','File',...
        'Enable','on');
    h.Menu.Load = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Load File(s)...',...
        'Callback',{@Load_PDA, 1},...
        'Tag','Load');
    h.Menu.Add = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Add File(s)...',...
        'Callback',{@Load_PDA, 2},...
        'enable','off',...
        'Tag','Add');
    h.Menu.Save = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Save to File(s)',...
        'Callback',@Save_PDA,...
        'enable','off',...
        'Tag','Save');
    h.Menu.Export = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Export Figure(s), Figure and Table Data',...
        'Callback',@Export_Figure,...
        'Tag','Export'); 
    h.Menu.Params = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Reload Parameters',...
        'Callback',{@Update_ParamTable, 2},...
        'Tag','Params');
    h.Menu.FitParams = uimenu(...
        'Parent',h.Menu.File,...
        'Label','Reload Fit Parameters',...
        'Callback',{@Update_FitTable, 2},...
        'Tag','Params');
    %%% Fit Menu
    h.Menu.Fit = uimenu(...
        'Parent',h.GlobalPDAFit,...
        'Label','Fit');
    h.Menu.ViewFit = uimenu(...
        'Parent',h.Menu.Fit,...
        'Tag','ViewFit',...
        'Label','View',...
        'Callback',@Start_PDA_Fit);
    h.Menu.StartFit = uimenu(...
        'Parent',h.Menu.Fit,...
        'Tag','StartFit',...
        'Label','Start',...
        'Callback',@Start_PDA_Fit);
    h.Menu.StopFit = uimenu(...
        'Parent',h.Menu.Fit,...
        'Tag','StopFit',...
        'Label','Stop',...
        'Callback',@Stop_PDA_Fit);
    h.Menu.EstimateError = uimenu(...
        'Parent',h.Menu.Fit,...
        'Label','Estimate Error',...
        'Tag','EstimateError');
    h.Menu.EstimateErrorHessian = uimenu(...
        'Parent',h.Menu.EstimateError,...
        'Label','Estimate Error from Jacobian at solution',...
        'Tag','EstimateErrorHessian',...
        'Callback',@Start_PDA_Fit);
    h.Menu.EstimateErrorMCMC = uimenu(...
        'Parent',h.Menu.EstimateError,...
        'Label','Estimate Error from Markov-chain Monte Carlo',...
        'Tag','EstimateErrorMCMC',...
        'Callback',@Start_PDA_Fit);
    %%% Info Menu
%     h.Menu.Info = uimenu(...
%         'Parent',h.GlobalPDAFit,...
%         'Label','Info');
%     h.Menu.Todo = uimenu(...
%         'Parent',h.Menu.Info,...
%         'Tag','Todo',...
%         'Label','To do',...
%         'Callback', @Todolist);
%     h.Menu.Manual = uimenu(...
%         'Parent',h.Menu.Info,...
%         'Tag','Manual',...
%         'Label','Manual',...
%         'Callback', @Manual);
    
    %% Upper tabgroup %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.Tabgroup_Up = uitabgroup(...
        'Parent',h.GlobalPDAFit,...
        'Tag','MainPlotTab',...
        'Units','normalized',...
        'Position',[0 0.2 1 0.8]);
    
    %% All tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.AllTab.Tab = uitab(...
        'Parent',h.Tabgroup_Up,...
        'Tag','Tab_All',...
        'Title','All');
    
    % Main Axes
    h.AllTab.Main_Panel = uibuttongroup(...
        'Parent',h.AllTab.Tab,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0 0 1 1],...
        'Tag','Main_Panel_All');
    h.AllTab.Main_Axes = axes(...
        'Parent',h.AllTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.045 0.08 0.715 0.745],...
        'Box','on',...
        'Tag','Main_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XLim',[0 1],...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto');
    xlabel('Proximity Ratio','Color',Look.Fore);
    ylabel('#','Color',Look.Fore);
    h.AllTab.Res_Axes = axes(...
        'Parent',h.AllTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.045 0.85 0.715 0.13],...
        'Box','on',...
        'Tag','Residuals_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XTickLabel','',...
        'XLim',[0 1],...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto');
    ylabel('w_{res}','Color',Look.Fore);
    linkaxes([h.AllTab.Main_Axes,h.AllTab.Res_Axes],'x');
    
    %%% Progress Bar
    h.AllTab.Progress.Panel = uibuttongroup(...
        'Parent',h.AllTab.Main_Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0.78 0.94 0.21 0.04],...
        'Tag','Progress_Panel_All');
    h.AllTab.Progress.Axes = axes(...
        'Parent',h.AllTab.Progress.Panel,...
        'Tag','Progress_Axes_All',...
        'Units','normalized',...
        'Color',Look.Control,...
        'Position',[0 0 1 1]);
    h.AllTab.Progress.Axes.XTick=[];
    h.AllTab.Progress.Axes.YTick=[];
    h.AllTab.Progress.Text=text(...
        'Parent',h.AllTab.Progress.Axes,...
        'Tag','Progress_Text_All',...
        'Units','normalized',...
        'FontSize',12,...
        'FontWeight','bold',...
        'String','Nothing loaded',...
        'Interpreter','none',...
        'HorizontalAlignment','center',...
        'BackgroundColor','none',...
        'Color',Look.Fore,...
        'Position',[0.5 0.5]);
    
    h.AllTab.PlotTab = uitabgroup(...
        'Parent',h.AllTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.765,0.45,0.235,0.475],...
        'Tag','PlotTab_All'...
        );
    h.AllTab.BSD_Tab = uitab(...
        h.AllTab.PlotTab,...
        'Title','Photon count distribution',...
        'BackgroundColor',Look.Back);
    %%% Burst Size Distribution Plot
    h.AllTab.BSD_Axes = axes(...
        'Parent',h.AllTab.BSD_Tab,...
        'Units','normalized',...
        'Position',[0.15 0.175 0.80 0.765],...
        'Box','on',...
        'Tag','BSD_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('# Photons per Bin','Color',Look.Fore);
    ylabel('Occurence','Color',Look.Fore);
    
    h.AllTab.ES_Tab = uitab(...
        h.AllTab.PlotTab,...
        'Title','E-S plot',...
        'BackgroundColor',Look.Back);
    %%% E-S scatter plot
    h.AllTab.ES_Axes = axes(...
        'Parent',h.AllTab.ES_Tab,...
        'Units','normalized',...
        'Position',[0.15 0.175 0.80 0.765],...
        'Box','on',...
        'Tag','BSD_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('E','Color',Look.Fore);
    ylabel('S','Color',Look.Fore);
    
    %%% distance Plot
    h.AllTab.Gauss_Axes = axes(...
        'Parent',h.AllTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.8 0.08 0.185 0.35],...
        'Box','on',...
        'Tag','Gauss_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('Distance [A]','Color',Look.Fore);
    ylabel('Probability','Color',Look.Fore);
    
    
    %% Single tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% main plot
    h.SingleTab.Tab = uitab(...
        'Parent',h.Tabgroup_Up,...
        'Tag','Tab_Single',...
        'Title','Single');
    h.SingleTab.Main_Panel = uibuttongroup(...
        'Parent',h.SingleTab.Tab,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0 0 1 1],...
        'Tag','Main_Panel_Single');
    h.SingleTab.Main_Axes = axes(...
        'Parent',h.SingleTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.04 0.075 0.72 0.75],...
        'Box','on',...
        'Tag','Main_Axes_Single',...
        'FontSize',18,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
                       'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'XLim',[0 1],...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto');
    xlabel('Proximity Ratio','Color',Look.Fore);
    ylabel('#','Color',Look.Fore);
    h.SingleTab.Res_Axes = axes(...
        'Parent',h.SingleTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.04 0.85 0.72 0.13],...
        'Box','on',...
        'Tag','Residuals_Axes_Single',...
        'FontSize',18,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XTickLabel','',...
        'XLim',[0 1],...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto');
    ylabel('w_{res}','Color',Look.Fore);
    linkaxes([h.SingleTab.Main_Axes,h.SingleTab.Res_Axes],'x');
    
    %%% Progress Bar
    h.SingleTab.Progress.Panel = uibuttongroup(...
        'Parent',h.SingleTab.Main_Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0.78 0.94 0.21 0.04],...
        'Tag','Progress_Panel_Single');
    h.SingleTab.Progress.Axes = axes(...
        'Parent',h.SingleTab.Progress.Panel,...
        'Tag','Progress_Axes_Single',...
        'Units','normalized',...
        'Color',Look.Control,...
        'Position',[0 0 1 1]);
    h.SingleTab.Progress.Axes.XTick=[]; 
    h.SingleTab.Progress.Axes.YTick=[];
    h.SingleTab.Progress.Text=text(...
        'Parent',h.SingleTab.Progress.Axes,...
        'Tag','Progress_Text_Single',...
        'Units','normalized',...
        'FontSize',12,...
        'FontWeight','bold',...
        'String','Nothing loaded',...
        'Interpreter','none',...
        'HorizontalAlignment','center',...
        'BackgroundColor','none',...
        'Color',Look.Fore,...
        'Position',[0.5 0.5]);
    
    h.SingleTab.PlotTab = uitabgroup(...
        'Parent',h.SingleTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.765,0.45,0.235,0.475],...
        'Tag','PlotTab_All'...
        );
    h.SingleTab.BSD_Tab = uitab(...
        h.SingleTab.PlotTab,...
        'Title','Photon count distribution',...
        'BackgroundColor',Look.Back);
    %%% Burst Size Distribution Plot
    h.SingleTab.BSD_Axes = axes(...
        'Parent',h.SingleTab.BSD_Tab,...
        'Units','normalized',...
        'Position',[0.15 0.175 0.80 0.765],...
        'Box','on',...
        'Tag','BSD_Axes_Single',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('# Photons per Bin','Color',Look.Fore);
    ylabel('Occurence','Color',Look.Fore);
    
    h.SingleTab.ES_Tab = uitab(...
        h.SingleTab.PlotTab,...
        'Title','E-S plot',...
        'BackgroundColor',Look.Back);
    %%% E-S scatter plot
    h.SingleTab.ES_Axes = axes(...
        'Parent',h.SingleTab.ES_Tab,...
        'Units','normalized',...
        'Position',[0.15 0.175 0.80 0.765],...
        'Box','on',...
        'Tag','BSD_Axes_All',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('E','Color',Look.Fore);
    ylabel('S','Color',Look.Fore);
    
    %%% distance Plot
    h.SingleTab.Gauss_Axes = axes(...
        'Parent',h.SingleTab.Main_Panel,...
        'Units','normalized',...
        'Position',[0.8 0.11 0.185 0.325],...
        'Box','on',...
        'Tag','Gauss_Axes_Single',...
        'FontSize',12,...
        'nextplot','add',...
        'UIContextMenu',[],...
        'Color',Look.Axes,...
        'XColor',Look.Fore,...
        'YColor',Look.Fore,...
        'XGrid','on',...
        'YGrid','on',...
        'GridAlpha',0.5,...
        'LineWidth',Look.AxWidth,...
        'YLimMode','auto',...
        'XLimMode','auto');
    xlabel('Distance [A]','Color',Look.Fore);
    ylabel('Probability','Color',Look.Fore);
    
    %%% Determines, which file to plot
    h.SingleTab.Popup = uicontrol(...
        'Parent',h.SingleTab.Main_Panel,...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', [1 1 1],...
        'ForegroundColor', [0 0 0],...
        'Style','popupmenu',...
        'String',{'Nothing selected'},...
        'Value',1,...
        'Callback',{@Update_Plots,2},...
        'Position',[0.775 -0.05 0.22 0.1],...
        'Tag','Popup_Single');
    
  
    
    %% Bottom tabgroup %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.Tabgroup_Down = uitabgroup(...
        'Parent',h.GlobalPDAFit,...
        'Tag','Params_Tab',...
        'Units','normalized',...
        'Position',[0 0 1 0.2]);
    
    %% Database tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     h.PDADatabase.Tab= uitab(...
        'Parent',h.Tabgroup_Down,...
        'Tag','PDADatabase_Tab',...
        'Title','Database');    
    %%% Database panel
    h.PDADatabase.Panel = uibuttongroup(...
        'Parent',h.PDADatabase.Tab,...
        'Tag','PDADatabase_Panel',...
        'Units','normalized',...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Position',[0 0 1 1]);    
    %%% Database list
    h.PDADatabase.List = uicontrol(...
        'Parent',h.PDADatabase.Panel,...
        'Tag','PDADatabase_List',...
        'Style','listbox',...
        'Units','normalized',...
        'FontSize',14,...
        'Max',2,...
        'String',[],...
        'BackgroundColor', Look.List,...
        'ForegroundColor', Look.ListFore,...
        'KeyPressFcn',{@Database,0},...
        'Tooltipstring', ['<html>'...
                          'List of files in database <br>',...
                          '<i>"return"</i>: Loads selected files <br>',...
                          '<I>"delete"</i>: Removes selected files from list </b>'],...
        'Position',[0.01 0.01 0.9 0.98]);   
    %%% Button to add files to the database
    h.PDADatabase.Load = uicontrol(...
        'Parent',h.PDADatabase.Panel,...
        'Tag','PDADatabase_Load_Button',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'String','Load',...
        'Callback',{@Database,2},...
        'Position',[0.93 0.55 0.05 0.15],...
        'Tooltipstring', 'Load database from file');
    %%% Button to add files to the database
    h.PDADatabase.Save = uicontrol(...
        'Parent',h.PDADatabase.Panel,...
        'Tag','PDADatabase_Save_Button',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'String','Save',...
        'Callback',{@Database,3},...
        'Position',[0.93 0.35 0.05 0.15],...
        'enable', 'off',...
        'Tooltipstring', 'Save database to a file');
    
    %% Fit tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.FitTab.Tab = uitab(...
        'Parent',h.Tabgroup_Down,...
        'Tag','Fit_Tab',...
        'Title','Fit');
    h.FitTab.Panel = uibuttongroup(...
        'Parent',h.FitTab.Tab,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0 0 1 1],...
        'Tag','Fit_Panel');
    h.FitTab.Table = uitable(...
        'Parent',h.FitTab.Panel,...
        'Tag','Fit_Table',...
        'Units','normalized',...
        'ForegroundColor',Look.TableFore,...
        'BackgroundColor',[Look.Table1;Look.Table2],...
        'FontSize',12,...
        'Position',[0 0 1 1],...
        'CellEditCallback',{@Update_FitTable,3},...
        'CellSelectionCallback',{@Update_FitTable,3});
    
    %% Parameters tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.ParametersTab.Tab = uitab(...
        'Parent',h.Tabgroup_Down,...
        'Tag','Parameters_Tab',...
        'Title','Parameters');
    h.ParametersTab.Panel = uibuttongroup(...
        'Parent',h.ParametersTab.Tab,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0 0 1 1],...
        'Tag','Parameters_Panel');
    h.ParametersTab.Table = uitable(...
        'Parent',h.ParametersTab.Panel,...
        'Tag','Parameters_Panel',...
        'Units','normalized',...
        'ForegroundColor',Look.TableFore,...
        'BackgroundColor',[Look.Table1;Look.Table2],...
        'FontSize',12,...
        'Position',[0 0 1 1],...
        'CellEditCallback',{@Update_ParamTable,3},...
        'CellSelectionCallback',{@Update_ParamTable,3});
    
    %% Settings tab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h.SettingsTab.Tab = uitab(...
        'Parent',h.Tabgroup_Down,...
        'Tag','Settings_Tab',...
        'Title','Settings');
    h.SettingsTab.Panel = uibuttongroup(...
        'Parent',h.SettingsTab.Tab,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'HighlightColor', Look.Control,...
        'ShadowColor', Look.Shadow,...
        'Units','normalized',...
        'Position',[0 0 1 1],...
        'Tag','SettingsPanel');
    % First column
    h.SettingsTab.NumberOfBins_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String','Number of Bins',...
        'Position',[0.02 0.775 0.175 0.2],...
        'HorizontalAlignment','right',...
        'Tag','NumberOfBins_Text');
    h.SettingsTab.NumberOfBins_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',UserValues.PDA.NoBins,...
        'Position',[0.2 0.825 0.05 0.15],...
        'Callback',{@Update_Plots,3,1},...
        'Tag','NumberOfBins_Edit');
    h.SettingsTab.NumberOfPhotMin_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String','Minimum Number of Photons per Bin',...
        'Position',[0.02 0.575 0.175 0.2],...
        'HorizontalAlignment','right',...
        'Tag','NumberOfPhotMin_Text');
    h.SettingsTab.NumberOfPhotMin_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',UserValues.PDA.MinPhotons,...
        'Callback',{@Update_Plots,3,1},...
        'Position',[0.2 0.625 0.05 0.15],...
        'Tag','NumberOfPhotMin_Edit');
    h.SettingsTab.NumberOfPhotMax_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String','Maximum Number of Photons per Bin',...
        'Position',[0.02 0.375 0.175 0.2],...
        'HorizontalAlignment','right',...
        'Tag','NumberOfPhotMax_Text');
    h.SettingsTab.NumberOfPhotMax_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',UserValues.PDA.MaxPhotons,...
        'Callback',{@Update_Plots,3,1},...
        'Position',[0.2 0.425 0.05 0.15],...
        'Tag','NumberOfPhotMax_Edit');
    h.SettingsTab.NumberOfBinsE_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String','Grid resolution for E',...
        'TooltipString','Higher increases fit accuracy, but makes it slower.',...
        'Position',[0.02 0.175 0.175 0.2],...
        'HorizontalAlignment','right',...
        'Tag','NumberOfBinsE_Text');
    h.SettingsTab.NumberOfBinsE_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'String',UserValues.PDA.GridRes,...
        'TooltipString','Higher increases fit accuracy, but makes it slower.',...
        'FontSize',12,...
        'Callback',{@Update_Plots,0,1},...
        'Position',[0.2 0.225 0.05 0.15],...
        'Tag','NumberOfBinsE_Edit');
    h.SettingsTab.StoichiometryThreshold_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String','Stoichiometry threshold:',...
        'Position',[0.02 -0.025 0.175 0.2],...
        'HorizontalAlignment','right',...
        'Tag','StoichiometryThreshold_Text');
    h.SettingsTab.StoichiometryThresholdLow_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',UserValues.PDA.Smin,...
        'Position',[0.2 0.025 0.025 0.15],...
        'Callback',{@Update_Plots,3,1},...
        'Tag','StoichiometryThresholdLow_Edit');
    h.SettingsTab.StoichiometryThresholdHigh_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',UserValues.PDA.Smax,...
        'Position',[0.225 0.025 0.025 0.15],...
        'Callback',{@Update_Plots,3,1},...
        'Tag','StoichiometryThresholdHigh_Edit');
    
    % third column
    h.SettingsTab.PDAMethod_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'String','PDA Method',...
        'FontSize',12,...
        'Position',[0.4 0.75 0.1 0.2],...
        'HorizontalAlignment','left',...
        'Tag','PDAMethod_Text');
    h.SettingsTab.PDAMethod_Popupmenu = uicontrol(...
        'Style','popupmenu',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor',[1 1 1],...
        'ForegroundColor',[0 0 0],...
        'Units','normalized',...
        'String',{'Histogram Library','MLE','MonteCarlo'},...
        'Value',1,...
        'FontSize',12,...
        'Position',[0.5 0.775 0.1 0.2],...
        'Tag','PDAMethod_Popupmenu');
    h.SettingsTab.FitMethod_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'String','Fit Method',...
        'FontSize',12,...
        'Position',[0.4 0.50 0.1 0.2],...
        'HorizontalAlignment','left',...
        'Tag','FitMethod_Text');
    h.SettingsTab.FitMethod_Popupmenu = uicontrol(...
        'Style','popupmenu',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', [1 1 1],...
        'ForegroundColor', [0 0 0],...
        'Units','normalized',...
        'String',{'Simplex','Gradient-based (lsqnonlin)','Gradient-based (fmincon)','Patternsearch','Gradient-based (global)'},...
        'Value',1,...
        'FontSize',12,...
        'Position',[0.5 0.525 0.1 0.2],...
        'Tag','FitMethod_Popupmenu');
    h.SettingsTab.OverSampling_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',sprintf('MonteCarlo Oversampling'),...
        'Position',[0.4 0.25 0.155 0.2],...
        'HorizontalAlignment','left',...
        'Tag','OverSampling_Text');
    h.SettingsTab.OverSampling_Edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'String','10',...
        'FontSize',12,...
        'Callback',[],...
        'Position',[0.555 0.275 0.05 0.2],...
        'Tag','OverSampling_Edit');
    h.SettingsTab.Chi2Method_Text = uicontrol(...
        'Style','text',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'FontSize',12,...
        'String',sprintf('Chi2 method'),...
        'Position',[0.4 0.025 0.1 0.2],...
        'HorizontalAlignment','left',...
        'Tag','Chi2Method_Text');
    h.SettingsTab.Chi2Method_Popupmenu = uicontrol(...
        'Style','popupmenu',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', [1 1 1],...
        'ForegroundColor', [0 0 0],...
        'Units','normalized',...
        'String',{'Poissonian','Gaussian'},...
        'FontSize',12,...
        'Callback',[],...
        'Value',1,...
        'Position',[0.5 0.025 0.1 0.2],...
        'Tag','Chi2Method_Edit');
     h.SettingsTab.DynamicModel = uicontrol(...
        'Parent',h.SettingsTab.Panel,...
        'Tag','DynamicModel',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Style','checkbox',...
        'String','Dynamic Model',...
        'Value',UserValues.PDA.Dynamic,...
        'TooltipString',sprintf('Only works for Histogram Library Approach!\nSpecies 3 and onward will be treated as static.'),...
        'Callback',@Update_GUI,...
        'Position',[0.65 0.55 0.1 0.15]);
    h.SettingsTab.FixSigmaAtFractionOfR = uicontrol(...
        'Parent',h.SettingsTab.Panel,...
        'Tag','FixSigmaAtFractionOfR',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Style','checkbox',...
        'String','Fix Sigma at Fraction of R:',...
        'Tooltipstring', 'If you want this parameter globally, globally link some random parameter like Donly',...
        'Value',UserValues.PDA.FixSigmaAtFraction,...
        'Callback',@Update_GUI,...
        'Position',[0.65 0.75 0.15 0.2]);
    h.SettingsTab.SigmaAtFractionOfR_edit = uicontrol(...
        'Style','edit',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Control,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'String',UserValues.PDA.SigmaAtFractionOfR,...
        'Tooltipstring', 'If you want this parameter globally, globally link some random parameter like Donly',...
        'FontSize',12,...
        'Callback',{@Update_Plots,0},...
        'Position',[0.8 0.75 0.05 0.2],...
        'Enable','off',...
        'Tag','SigmaAtFractionOfR_edit');
    h.SettingsTab.FixSigmaAtFractionOfR_Fix = uicontrol(...
        'Style','checkbox',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'Value',UserValues.PDA.FixSigmaAtFractionFix,...
        'FontSize',12,...
        'String','Fix?',...
        'Callback',[],...
        'Position',[0.85 0.75 0.1 0.2],...
        'Enable','off',...
        'Tag','FixSigmaAtFractionOfR_Fix');
    h.SettingsTab.OuterBins_Fix = uicontrol(...
        'Style','checkbox',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'Value',UserValues.PDA.IgnoreOuterBins,...
        'FontSize',12,...
        'String','ignore outer bins?',...
        'Tooltipstring', 'ignore outer Epr bins during fitting. Does not work for MLE fitting!!!',...
        'Callback',{@Update_Plots,3,1},...
        'Position',[0.8 0.3 0.2 0.15],...
        'Tag','OuterBins_Fix');
    h.SettingsTab.GaussAmp_Fix = uicontrol(...
        'Style','checkbox',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'Value',0,...
        'FontSize',12,...
        'String','gauss amplitude',...
        'Tooltipstring', '(Unchecked: area / checked: amplitude) of the gaussian is the fraction of molecules in that state',...
        'Callback',{@Update_Plots,1},...
        'Position',[0.8 0.05 0.1 0.15],...
        'Tag','OuterBins_Fix');
    h.SettingsTab.Use_Brightness_Corr = uicontrol(...
        'Style','checkbox',...
        'Parent',h.SettingsTab.Panel,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Units','normalized',...
        'Value',0,...
        'FontSize',12,...
        'String','Brightness Correction',...
        'Tooltipstring', '',...
        'Callback',{@Load_Brightness_Reference,1},...
        'ButtonDownFcn',{@Load_Brightness_Reference,2},...
        'Position',[0.9 0.05 0.1 0.15],...
        'Tag','Use_Brightness_Corr');
     h.SettingsTab.LiveUpdate = uicontrol(...
        'Parent',h.SettingsTab.Panel,...
        'Tag','LiveUpdate',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Style','checkbox',...
        'String','Live plot update',...
        'Value',0,...
        'Position',[0.8 0.55 0.15 0.15]);
     h.SettingsTab.HalfGlobal = uicontrol(...
        'Parent',h.SettingsTab.Panel,...
        'Tag','HalfGlobal',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Style','checkbox',...
        'String','Half global',...
        'Value',UserValues.PDA.HalfGlobal,...
        'Callback', {@Update_Plots, 0},...
        'Position',[0.65 0.05 0.15 0.15]);
    h.SettingsTab.DeconvoluteBackground = uicontrol(...
        'Parent',h.SettingsTab.Panel,...
        'Tag','HalfGlobal',...
        'Units','normalized',...
        'FontSize',12,...
        'BackgroundColor', Look.Back,...
        'ForegroundColor', Look.Fore,...
        'Style','checkbox',...
        'String','Deconvolute background',...
        'Value',UserValues.PDA.DeconvoluteBackground,...
        'Callback', {@Update_Plots, 0},...
        'Position',[0.65 0.3 0.15 0.15]);
    %% Other stuff
    %%% Re-enable menu
    h.Menu.File.Enable = 'on';
    %% Initializes global variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    PDAData=[];
    PDAData.Data=[];
    PDAData.FileName=[];
    PDAData.FitTable = [];
    PDAMeta=[];
    PDAData.Corrections = [];
    PDAData.Background = [];
    PDAMeta.Confidence_Intervals = cell(1,1);
    PDAMeta.Plots=cell(0);
    PDAMeta.Model=[];
    PDAMeta.Fits=[];
    PDAMeta.FitInProgress = 0;
    PDAMeta.LiveUpdate = 0;
    
    %% store handles structure
    guidata(h.GlobalPDAFit,h);
    SampleData
    Update_FitTable([],[],0); %initialize
    Update_ParamTable([],[],0);
    Update_GUI(h.SettingsTab.DynamicModel,[]);
    Update_GUI(h.SettingsTab.FixSigmaAtFractionOfR,[]);
    Update_FitTable([],[],0); %reset to standard
else
    figure(h.GlobalPDAFit); % Gives focus to GlobalPDAFit figure
end

function Close_PDA(~,~)
clearvars -global PDAData PDAMeta
delete(findobj('Tag','GlobalPDAFit'));
Phasor=findobj('Tag','Phasor');
Pam=findobj('Tag','Pam');
MIAFit=findobj('Tag','MIAFit');
Mia=findobj('Tag','Mia');
Sim=findobj('Tag','Sim');
PCF=findobj('Tag','PCF');
BurstBrowser=findobj('Tag','BurstBrowser');
TauFit=findobj('Tag','TauFit');
PhasorTIFF = findobj('Tag','PhasorTIFF');
FCSFit = findobj('Tag','FCSFit');
if isempty(Phasor) && isempty(Pam) && isempty(MIAFit) && isempty(PCF) && isempty(Mia) && isempty(Sim) && isempty(TauFit) && isempty(BurstBrowser) && isempty(PhasorTIFF) && isempty(FCSFit)
    clear global -regexp UserValues
end

% Load data that was exported in BurstBrowser
function Load_PDA(~,~,mode)
global PDAData UserValues
h = guidata(findobj('Tag','GlobalPDAFit'));

if mode ~= 3
    %% Load or Add data
    Files = GetMultipleFiles({'*.pda','*.pda file'},'Select *.pda file',UserValues.File.PDAPath);
    if isempty(Files)
        return;
    end
    FileName = Files(:,1);
    PathName = Files(:,2);
    %%% Only executes, if at least one file was selected
    if all(FileName{1}==0)
        return
    end
    %PathName = cell(numel(FileName),1);
    %PathName(:) = {p};
else
    %% Database loading
    FileName = PDAData.FileName;
    PathName = PDAData.PathName;
end

UserValues.File.PDAPath = PathName{1};

LSUserValues(1);

if mode==1 || mode ==3 % new files are loaded or database is loaded
    PDAData.FileName = [];
    PDAData.PathName = [];
    PDAData.Data = [];
    PDAData.timebin = [];
    PDAData.Type = [];
    PDAData.Corrections = [];
    PDAData.Background = [];
    PDAData.OriginalFitParams = [];
    PDAData.FitTable = [];
    PDAData.BrightnessReference = [];
    h.FitTab.Table.RowName(1:end-3)=[];
    h.FitTab.Table.Data(1:end-3,:)=[];
    h.ParametersTab.Table.RowName(1:end-1)=[];
    h.ParametersTab.Table.Data(1:end-1,:)=[];
    h.PDADatabase.List.String = [];
    h.PDADatabase.Save.Enable = 'off';
    h.Menu.Add.Enable = 'on';
    h.Menu.Save.Enable = 'on';
end
errorstr = cell(0,1);
a = 1;
for i = 1:numel(FileName)
    Progress(i/numel(FileName),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Loading file(s)...');
    Progress(i/numel(FileName),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Loading file(s)...');
    if exist(fullfile(PathName{i},FileName{i}), 'file') == 2
        load('-mat',fullfile(PathName{i},FileName{i}));
        PDAData.FileName{end+1} = FileName{i};
        PDAData.PathName{end+1} = PathName{i};
        if exist('PDA','var') % file has not been saved before in GlobalPDAFit
            % PDA %structure
            % .NGP
            % ....
            % .NR
            % .Corrections %structure
            %       .CrossTalk_GR
            %       .DirectExcitation_GR
            %       .Gamma_GR
            %       .Beta_GR
            %       .GfactorGreen
            %       .GfactorRed
            %       .DonorLifetime
            %       .AcceptorLifetime
            %       .FoersterRadius
            %       .LinkerLength
            %       .r0_green
            %       .r0_red
            %       ... maybe more in future
            % .Background %structure
            %       .Background_GGpar
            %       .Background_GGperp
            %       .Background_GRpar
            %       .Background_GRperp
            %       ... maybe more in future
            % NOTE: direct excitation correction in Burst analysis is NOT the
            % same as PDA, therefore we put it to zero. In PDA, this factor
            % is either the extcoeffA/(extcoeffA+extcoeffD) at donor laser,
            % or the ratio of Int(A)/(Int(A)+Int(D)) for a crosstalk, gamma
            % corrected double labeled molecule having no FRET at all.
            PDAData.Data{end+1} = PDA;
            PDAData.Data{end} = rmfield(PDAData.Data{end}, 'Corrections');
            PDAData.Data{end} = rmfield(PDAData.Data{end}, 'Background');
            PDAData.timebin(end+1) = timebin;
            PDAData.Corrections{end+1} = PDA.Corrections; %contains everything that was saved in BurstBrowser
            PDAData.Background{end+1} = PDA.Background; %contains everything that was saved in BurstBrowser
            if isfield(PDA,'BrightnessReference')
                if ~isempty(PDA.BrightnessReference.N)
                    PDAData.BrightnessReference = PDA.BrightnessReference;
                    PDAData.BrightnessReference.PN = histcounts(PDAData.BrightnessReference.N,1:(max(PDAData.BrightnessReference.N)+1));
                end
            end
            if isfield(PDA,'Type') %%% Type distinguishes between whole measurement and burstwise
                PDAData.Type{end+1} = PDA.Type;
            else
                PDAData.Type{end+1} = 'Burst';
            end
            clear PDA timebin
            PDAData.FitTable{end+1} = h.FitTab.Table.Data(end-2,:);
        elseif exist('SavedData','var') % file has been saved before in GlobalPDAFit and contains PDAData (named SavedData)
            % SavedData %structure
            %   .Data %cell
            %       .NGP
            %       ....
            %       .NR
            %   .Corrections %structure
            %           see above
            %   .Background %structure
            %           see above
            %   .FitParams %1 x 47 cell
            PDAData.Data{end+1} = SavedData.Data;
            PDAData.timebin(end+1) = SavedData.timebin;
            PDAData.Corrections{end+1} = SavedData.Corrections;
            PDAData.Background{end+1} = SavedData.Background;
            if isfield(SavedData,'BrightnessReference')
                PDAData.BrightnessReference = SavedData.BrightnessReference;
                PDAData.BrightnessReference.PN = histcounts(PDAData.BrightnessReference.N,1:(max(PDAData.BrightnessReference.N)+1));
            end
            if isfield(SavedData,'Sigma')
                try
                    h.SettingsTab.FixSigmaAtFractionOfR.Value = SavedData.Sigma(1);
                    h.SettingsTab.SigmaAtFractionOfR_edit.String = num2str(SavedData.Sigma(2));
                    h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value = SavedData.Sigma(3);
                    UserValues.PDA.FixSigmaAtFraction = SavedData.Sigma(1);
                    UserValues.PDA.FixSigmaAtFractionFix = SavedData.Sigma(3);
                    LSUserValues(1)
                catch
                end
            end
            if isfield(SavedData,'Dynamic')
                h.SettingsTab.DynamicModel.Value = SavedData.Dynamic;
                UserValues.PDA.Dynamic = SavedData.Dynamic;
                LSUserValues(1)
            end
            if isfield(SavedData,'Type') %%% Type distinguishes between whole measurement and burstwise
                PDAData.Type{end+1} = SavedData.Type;
            else
                PDAData.Type{end+1} = 'Burst';
            end
            % load fit table data from files
            PDAData.FitTable{end+1} = SavedData.FitTable;
        elseif exist('PDAstruct','var')
            %%% File is probably from old PDAFit
            PDAData.Data{end+1} = PDAstruct.Data;
            PDAData.timebin(end+1) = PDAstruct.timebin;
            PDAData.Corrections{end+1} = PDAstruct.Corrections; %contains everything that was saved in BurstBrowser
            PDAData.Background{end+1}.Background_GGpar = PDAstruct.Corrections.BackgroundDonor/2;
            PDAData.Background{end}.Background_GGperp = PDAstruct.Corrections.BackgroundDonor/2;
            PDAData.Background{end}.Background_GRpar = PDAstruct.Corrections.BackgroundAcceptor/2;
            PDAData.Background{end}.Background_GRperp = PDAstruct.Corrections.BackgroundAcceptor/2;
            PDAData.FitTable{end+1} = h.FitTab.Table.Data(end-2,:);
            PDAData.Type{end+1} = 'Burst';
        end
        % add files to database table
        h.PDADatabase.List.String{end+1} = [FileName{i} ' (path:' PathName{i} ')'];
        h.PDADatabase.Save.Enable = 'on';
    else
        errorstr{a} = ['File ' FileName{i} ' on path ' PathName{i} ' could not be found. File omitted from database.'];
        a = a+1;
    end       
end
PDAData.OriginalFitParams = PDAData.FitTable; %contains the fit table as it was originally displayed when opening the data
if a > 1
    msgbox(errorstr)
end

% data cannot be directly plotted here, since other functions (bin size,...)
% might change the appearance of the data
Update_GUI(h.SettingsTab.DynamicModel,[]);
Update_GUI(h.SettingsTab.FixSigmaAtFractionOfR,[]);
Update_FitTable([],[],1);
Update_ParamTable([],[],1);
Update_Plots([],[],3);

% Save data and fit table back into each individual file 
function Save_PDA(~,~)
global PDAData
h = guidata(findobj('Tag','GlobalPDAFit'));
for i = 1:numel(PDAData.FileName)
    Progress(i/numel(PDAData.FileName),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Saving file(s)...');
    Progress(i/numel(PDAData.FileName),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Saving file(s)...');
    SavedData.Data = PDAData.Data{i};
    SavedData.timebin = PDAData.timebin(i);
    SavedData.Corrections = PDAData.Corrections{i};
    SavedData.Background = PDAData.Background{i};
    SavedData.Type = PDAData.Type{i};
    % for each dataset, all info from the table is saved (including active, global, fixed)
    SavedData.FitTable = h.FitTab.Table.Data(i,:);
    SavedData.FitTable{1} = true; %put file to active to avoid problems when reloading data
    SavedData.Sigma = [h.SettingsTab.FixSigmaAtFractionOfR.Value,...
        str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String),...
        h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value];
    SavedData.Dynamic = h.SettingsTab.DynamicModel.Value;
    save(fullfile(PDAData.PathName{i},PDAData.FileName{i}),'SavedData');
end

% Function that groups things that concern the plots
function Update_Plots(obj,~,mode,reset)
% function creates and/or updates the plots after:
% mode = 1: after fitting
% mode = 2: changing the popup value on single tab + called in UpdatePlot
% mode = 3: loading or adding data, n.o. bins, min/max, fix w_r...
% mode = 4: after updateparam table
% mode = 5: LiveUpdate plots during fitting

global PDAData PDAMeta UserValues
h = guidata(findobj('Tag','GlobalPDAFit'));

if nargin < 4
    reset = 0;
end
%%% reset resets the PDAMeta.PreparationDone variable
if reset == 1
    PDAMeta.PreparationDone(:) = 0;
end

% check if plot is active
Active = find(cell2mat(h.FitTab.Table.Data(1:end-3,1)))';

if isempty(Active) %% Clears 2D plot, if all are inactive
    %     h.Plots.Main.ZData = zeros(2);
    %     h.Plots.Main.CData = zeros(2,2,3);
    %     h.Plots.Fit.ZData = zeros(2);
    %     h.Plots.Fit.CData = zeros(2,2,3);
    h.SingleTab.Popup.String = {'Nothing selected'};
else %% Updates 2D plot selection string
    h.SingleTab.Popup.String = PDAData.FileName(Active);
    if h.SingleTab.Popup.Value>numel(h.SingleTab.Popup.String)
        h.SingleTab.Popup.Value = 1;
    end
end

switch mode
    case 3
        %% Update the All tab
        color = lines(100);
        n = size(PDAData.Data,2);
        % after loading data or changing settings tab
        % predefine handle cells
        PDAMeta.Plots.Data_All = cell(n,1);
        PDAMeta.Plots.Res_All = cell(n,1);
        PDAMeta.Plots.Fit_All = cell(n,8); 
        % 1 = all
        % 2:6 = substates
        % 7 = D only
        % 8 = all dynamic bursts
        PDAMeta.Plots.BSD_All = cell(n,1);
        PDAMeta.Plots.ES_All = cell(n,1);
        PDAMeta.Plots.Gauss_All = cell(n,8);
        % 1 = all
        % 2:6 = substates
        % 7 = D only
        % 8 = all dynamic bursts
        PDAMeta.hProx = cell(n,1); %hProx has to be global cause it's used for error calculation during fitting
        cla(h.AllTab.Main_Axes)
        cla(h.AllTab.Res_Axes)
        cla(h.AllTab.BSD_Axes)
        cla(h.AllTab.ES_Axes)
        cla(h.AllTab.Gauss_Axes)
        PDAMeta.Chi2_All = text('Parent',h.AllTab.Main_Axes,...
            'Units','normalized',...
            'Position',[0.77,0.95],...
            'String',['avg. \chi^2_{red.} = ' sprintf('%1.2f',randn(1))],...
            'FontWeight','bold',...
            'FontSize',18,...
            'FontSmoothing','on',...
            'Visible','off');
        for i = 1:n
            %colors
            normal = color(i,:);
            light = (normal+1)./2;
            dark = normal./2;
            if strcmp(PDAData.Type{i},'Burst')
                %%% find valid bins (chosen by thresholds min/max and stoichiometry)
                StoAll = (PDAData.Data{i}.NF+PDAData.Data{i}.NG)./(PDAData.Data{i}.NG+PDAData.Data{i}.NF+PDAData.Data{i}.NR);
                valid = ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) > str2double(h.SettingsTab.NumberOfPhotMin_Edit.String)) & ... %min photon number
                    ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) < str2double(h.SettingsTab.NumberOfPhotMax_Edit.String)) & ... %max photon number
                    ((StoAll > str2double(h.SettingsTab.StoichiometryThresholdLow_Edit.String))) & ... % Stoichiometry low
                    ((StoAll < str2double(h.SettingsTab.StoichiometryThresholdHigh_Edit.String))); % Stoichiometry high
            else
                valid = true(size(PDAData.Data{i}.NF));
            end
            %%% Calculate proximity ratio histogram
            Prox = PDAData.Data{i}.NF(valid)./(PDAData.Data{i}.NG(valid)+PDAData.Data{i}.NF(valid));
            Sto = (PDAData.Data{i}.NF(valid)+PDAData.Data{i}.NG(valid))./(PDAData.Data{i}.NG(valid)+PDAData.Data{i}.NF(valid)+PDAData.Data{i}.NR(valid));
            BSD = PDAData.Data{i}.NF(valid)+PDAData.Data{i}.NG(valid);
            PDAMeta.BSD{i} = BSD;
            PDAMeta.hProx{i} = histcounts(Prox, linspace(0,1,str2double(h.SettingsTab.NumberOfBins_Edit.String)+1)); 
            % if NumberOfBins = 50, then the EDGES(1:51) array is 0 0.02 0.04... 1.00
            % histcounts bins as 0 <= N < 0.02
            xProx = linspace(0,1,str2double(h.SettingsTab.NumberOfBins_Edit.String)+1)+1/str2double(h.SettingsTab.NumberOfBins_Edit.String)/2;
            % if NumberOfBins = 50, then xProx(1:51) = 0.01 0.03 .... 0.99 1.01
            % the last element is to allow proper display of the 50th bin
            
            hBSD = histcounts(BSD,1:(max(BSD)+1));
            xBSD = 1:max(BSD);
            
            % make 'stairs' appear similar to 'bar'
            xProx = xProx-mean(diff(xProx))/2;
            
            % slightly modify x-axis for each following dataset, to
            % allow better visualization of the different datasets.
            if i ~= 1
                % i = 1: do nothing
                % i = 2: shift each x value +5% of the x bin size
                % i = 3: shift each x value -5% of the x bin size
                % i = 4: shift each x value +10% of the x bin size
                % i = 5: shift each x value -10% of the x bin size
                % ...
                diffx = mean(diff(xProx))/20;
                if mod(i,2) == 0 %i = 2, 4, 6...
                    xProx = xProx + diffx*i/2;
                else %i = 3, 5, 7...
                    xProx = xProx - diffx*(i-1)/2;
                end
            end
            
            % data plot
            PDAMeta.Plots.Data_All{i} = stairs(h.AllTab.Main_Axes,...
                xProx,...
                [PDAMeta.hProx{i} PDAMeta.hProx{i}(end)],...
                'Color',normal,...
                'LineWidth',1);
            
            if h.SettingsTab.OuterBins_Fix.Value
                % do not display or take into account during fitting, the
                % outer bins of the histogram.
                lims = [xProx(2) xProx(end-1)];
                mini = PDAMeta.hProx{i}(2);
                maxi = PDAMeta.hProx{i}(end-1);
            else
                lims = [xProx(1) xProx(end)];
                mini = PDAMeta.hProx{i}(1);
                maxi = PDAMeta.hProx{i}(end);
            end
            PDAMeta.Plots.Data_All{i}.YData(1) = mini;
            PDAMeta.Plots.Data_All{i}.YData(end) = maxi;
            set(h.AllTab.Main_Axes, 'XLim', lims)
            set(h.AllTab.Res_Axes, 'XLim', lims)
            % residuals plot
            PDAMeta.Plots.Res_All{i} = stairs(h.AllTab.Res_Axes,...
                xProx,...
                zeros(numel(xProx),1),...
                'Color',normal,...
                'LineWidth',1,...
                'Visible', 'off');
            
            % fit plots
            PDAMeta.Plots.Fit_All{i,1} = stairs(h.AllTab.Main_Axes,...
                xProx,...
                zeros(numel(xProx),1),...
                'Color',dark,...
                'LineWidth',2,...
                'Visible','off');
            
            % plots for individual fits
            for j = 2:8
                % 1 = all
                % 2:6 = substates
                % 7 = D only
                % 8 = all dynamic bursts
                PDAMeta.Plots.Fit_All{i,j} = stairs(h.AllTab.Main_Axes,...
                    xProx,...
                    zeros(numel(xProx),1),...
                    'Color',light,...
                    'LineWidth',2,...
                    'Linestyle','--',...
                    'Visible','off');
            end

            % burst size distribution plot
            if isempty(PDAData.BrightnessReference)
                PDAMeta.Plots.BSD_Reference = plot(h.AllTab.BSD_Axes,...
                    xBSD,...
                    hBSD,...
                    'Color','m',...
                    'LineStyle','--',...
                    'Visible','off',...
                    'LineWidth',2);
            else
                PDAMeta.Plots.BSD_Reference = plot(h.AllTab.BSD_Axes,...
                    xBSD(1:min([end numel(PDAData.BrightnessReference.PN)])),...
                    PDAData.BrightnessReference.PN(xBSD(1:min([end numel(PDAData.BrightnessReference.PN)]))),...
                    'Color','m',...
                    'LineStyle','--',...
                    'LineWidth',2,...
                    'Visible','off');
            end
            if h.SettingsTab.Use_Brightness_Corr.Value
                PDAMeta.Plots.BSD_Reference.Visible = 'on';
            end
            PDAMeta.Plots.BSD_All{i} = plot(h.AllTab.BSD_Axes,...
                xBSD,...
                hBSD,...
                'Color',normal,...
                'LineWidth',2);
            % ES scatter plots
            PDAMeta.Plots.ES_All{i} = plot(h.AllTab.ES_Axes,...
                Prox,...
                Sto,...
                'Color',normal,...
                'MarkerSize',2,...
                'LineStyle','none',...
                'Marker','.');
            % generate exemplary distance plots
            x = 0:0.1:200;
            g = zeros(5,200*10+1);
            for j = 1:6
                g(j,:) = normpdf(x,40+10*j,j);
            end;
            % summed distance plot
            PDAMeta.Plots.Gauss_All{i,1} = plot(h.AllTab.Gauss_Axes,...
                x,sum(g,1),...
                'Color',dark,...
                'LineWidth',2,...
                'Visible', 'off');
            %individual distance plots
            for j = 2:7
                % 1 = all
                % 2:6 = substates
                % 7 = D only
                % 8 = all dynamic bursts
                PDAMeta.Plots.Gauss_All{i,j} = plot(h.AllTab.Gauss_Axes,...
                    x,g(j-1,:),...
                    'Color',light,...
                    'LineWidth',2,...
                    'LineStyle', '--',...
                    'Visible', 'off');
            end
            xlim(h.AllTab.Gauss_Axes,[40 120]);
        end
end
switch mode
    case {2,3}
        %% Update the 'Single' tab plots
        % after load data
        % after popup change
        % during fitting, when the tab is changed to single
        if ~isempty(Active)
            % check if plot is active
            i = Active(h.SingleTab.Popup.Value);
            % predefine cells
            PDAMeta.Plots.Fit_Single = cell(1,6);
            PDAMeta.Plots.Gauss_Single = cell(1,6);
            % clear axes
            cla(h.SingleTab.Main_Axes)
            cla(h.SingleTab.Res_Axes)
            cla(h.SingleTab.BSD_Axes)
            cla(h.SingleTab.Gauss_Axes)
            cla(h.SingleTab.ES_Axes);
            PDAMeta.Chi2_Single = copyobj(PDAMeta.Chi2_All, h.SingleTab.Main_Axes);
            PDAMeta.Chi2_Single.Position = [0.8,0.95];
            try
                % if fit is performed, this will work
                PDAMeta.Chi2_Single.String = ['\chi^2_{red.} = ' sprintf('%1.2f',PDAMeta.chi2(i))];
            end
            if strcmp(PDAData.Type{i},'Burst')
                %%% Re-Calculate proximity ratio histogram
                StoAll = (PDAData.Data{i}.NF+PDAData.Data{i}.NG)./(PDAData.Data{i}.NG+PDAData.Data{i}.NF+PDAData.Data{i}.NR);  
                valid = ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) > str2double(h.SettingsTab.NumberOfPhotMin_Edit.String)) & ...%min photon number
                    ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) < str2double(h.SettingsTab.NumberOfPhotMax_Edit.String)) & ...%max photon number
                    ((StoAll > str2double(h.SettingsTab.StoichiometryThresholdLow_Edit.String))) & ... % Stoichiometry low
                    ((StoAll < str2double(h.SettingsTab.StoichiometryThresholdHigh_Edit.String))); % Stoichiometry high
            else
                valid = true(size(PDAData.Data{i}.NF));
            end
            Prox = PDAData.Data{i}.NF(valid)./(PDAData.Data{i}.NG(valid)+PDAData.Data{i}.NF(valid));
            hProx = histcounts(Prox, linspace(0,1,str2double(h.SettingsTab.NumberOfBins_Edit.String)+1));
            % if NumberOfBins = 50, then the EDGES(1:51) array is 0 0.02 0.04... 1.00
            % histcounts bins as 0 <= N < 0.02
            xProx = linspace(0,1,str2double(h.SettingsTab.NumberOfBins_Edit.String)+1)+1/str2double(h.SettingsTab.NumberOfBins_Edit.String)/2;
            % if NumberOfBins = 50, then xProx(1:51) = 0.01 0.03 .... 0.99 1.01
            % the last element is to allow proper display of the 50th bin
            
            % data plot
            PDAMeta.Plots.Data_Single = bar(h.SingleTab.Main_Axes,...
                xProx,...
                [hProx hProx(end)],...
                'FaceColor',[0.4 0.4 0.4],...
                'EdgeColor','none',...
                'BarWidth',1);
            
            % make 'stairs' appear similar to 'bar'
            xProx = xProx-mean(diff(xProx))/2;
            
            if h.SettingsTab.OuterBins_Fix.Value
                % do not display or take into account during fitting, the
                % outer bins of the histogram.
                lims = [xProx(2) xProx(end-1)];
                mini = hProx(2);
                maxi = hProx(end-1);
            else
                lims = [xProx(1) xProx(end)];
                mini = hProx(1);
                maxi = hProx(end);
            end
            PDAMeta.Plots.Data_Single.YData(1) = mini;
            PDAMeta.Plots.Data_Single.YData(end) = maxi;
            set(h.SingleTab.Main_Axes, 'XLim', lims)
            set(h.SingleTab.Res_Axes, 'XLim', lims)
            
            % residuals
            PDAMeta.Plots.Res_Single = copyobj(PDAMeta.Plots.Res_All{i}, h.SingleTab.Res_Axes);
            set(PDAMeta.Plots.Res_Single,...
                'LineWidth',2,...
                'Color','k') %only define those properties that are different to the all tab
            PDAMeta.Plots.Res_Single.XData = xProx;
            
            % summed fit
            PDAMeta.Plots.Fit_Single{1,1} = copyobj(PDAMeta.Plots.Fit_All{i,1}, h.SingleTab.Main_Axes);
            PDAMeta.Plots.Fit_Single{1,1}.Color = 'k';%only define those properties that are different to the all tab
            PDAMeta.Plots.Fit_Single{1,1}.XData = xProx;
            
            % individual fits
            for j = 2:8
                % 1 = all
                % 2:6 = substates
                % 7 = D only
                % 8 = all dynamic bursts
                PDAMeta.Plots.Fit_Single{1,j} = copyobj(PDAMeta.Plots.Fit_All{i,j}, h.SingleTab.Main_Axes);
                PDAMeta.Plots.Fit_Single{1,j}.Color = [0.2 0.2 0.2];
                PDAMeta.Plots.Fit_Single{1,j}.XData = xProx;
            end
            
            if h.SettingsTab.DynamicModel.Value
                % state 1
                PDAMeta.Plots.Fit_Single{1,2}.Color = [1 0 1];
                % state 2
                PDAMeta.Plots.Fit_Single{1,3}.Color = [0 1 1];
                % in between 1 and 2
                PDAMeta.Plots.Fit_Single{1,8}.Color = [1 1 0];
            end

            % bsd
            PDAMeta.Plots.BSD_Single = copyobj(PDAMeta.Plots.BSD_All{i}, h.SingleTab.BSD_Axes);
            PDAMeta.Plots.BSD_Single.Color = 'k';%only define those properties that are different to the all tab
            % deconvoluted PofF
            PDAMeta.Plots.PF_Deconvolved_Single = plot(h.SingleTab.BSD_Axes,...
                    0,...
                    1,...
                    'Color','k',...
                    'LineWidth',2,...
                    'LineStyle','--',...
                    'Visible','off');
            if UserValues.PDA.DeconvoluteBackground
                if isfield(PDAMeta,'PN')
                    PDAMeta.Plots.PF_Deconvolved_Single.XData = 0:(numel(PDAMeta.PN{i})-1);
                    PDAMeta.Plots.PF_Deconvolved_Single.YData = PDAMeta.PN{i};
                    PDAMeta.Plots.PF_Deconvolved_Single.Visible = 'on';
                end
            end

            % ES
            PDAMeta.Plots.ES_Single = copyobj(PDAMeta.Plots.ES_All{i}, h.SingleTab.ES_Axes);
            PDAMeta.Plots.ES_Single.Color = 'k';%only define those properties that are different to the all tab
            % gaussians
            for j = 1:7
                PDAMeta.Plots.Gauss_Single{1,j} = copyobj(PDAMeta.Plots.Gauss_All{i,j}, h.SingleTab.Gauss_Axes);
                PDAMeta.Plots.Gauss_Single{1,j}.Color = [0.4 0.4 0.4]; %only define those properties that are different to the all tab
            end
            % set Ylim of the single plot Gauss
            ylim(h.SingleTab.Gauss_Axes,[min(PDAMeta.Plots.Gauss_Single{1,1}.YData), max(PDAMeta.Plots.Gauss_Single{1,1}.YData)*1.05]);
            PDAMeta.Plots.Gauss_Single{1,1}.Color = 'k';
        end
    case 4
        %% change active checkbox 
        %PDAMeta.PreparationDone = 0; %recalculate histogram (why?)
        for i = 1:numel(PDAData.FileName)
            if cell2mat(h.FitTab.Table.Data(i,1))
                %active
                tex = 'on';
            else
                tex = 'off';
            end
            PDAMeta.Plots.Data_All{i}.Visible = tex;
            if sum(PDAMeta.Plots.Res_All{i}.YData) ~= 0
                % data has been fitted before
                PDAMeta.Plots.Res_All{i}.Visible = tex;
            end
            PDAMeta.Plots.BSD_All{i}.Visible = tex;
            for j = 1:8
                % 1 = all
                % 2:6 = substates
                % 7 = D only
                % 8 = all dynamic bursts
                if sum(PDAMeta.Plots.Fit_All{i,j}.YData) ~= 0;
                    % data has been fitted before and component exists
                    PDAMeta.Plots.Fit_All{i,j}.Visible = tex;
                    PDAMeta.Plots.Gauss_All{i,j}.Visible = tex;
                end  
            end
            % Update the 'Single' tab plots
            if isempty(Active)
                PDAMeta.Plots.Data_Single.Visible = 'off';
                if sum(PDAMeta.Plots.Res_Single.YData) ~= 0
                    % data has been fitted before
                    PDAMeta.Plots.Res_Single.Visible = 'off';
                end
                PDAMeta.Plots.BSD_Single.Visible = 'off';
                for j = 1:8
                    % 1 = all
                    % 2:6 = substates
                    % 7 = D only
                    % 8 = all dynamic bursts
                    if sum(PDAMeta.Plots.Fit_Single{1,j}.YData) ~= 0;
                        % data has been fitted before and component exists
                        PDAMeta.Plots.Fit_Single{1,j}.Visible = 'off';
                        PDAMeta.Plots.Gauss_Single{1,j}.Visible = 'off';
                    end
                end
            end
        end
    case 1
        %% Update plots post fitting
        FitTable = cellfun(@str2double,h.FitTab.Table.Data);
        minGaussSum = 0;
        maxGaussSum = 0;
        %%% if the single tab is selected, only fit this dataset!
        if h.Tabgroup_Up.SelectedTab == h.SingleTab.Tab
            Active(:) = false;
            %%% find which is selected
            selected = find(strcmp(PDAData.FileName,h.SingleTab.Popup.String{h.SingleTab.Popup.Value}));
            Active(selected) = true;
            Active = find(Active);
        end
        for i = Active
            try %%% see if histogram exists
                x = PDAMeta.hFit{i};
            catch
                continue;
            end
            fitpar = FitTable(i,2:3:end-1); %everything but chi^2
            if h.SettingsTab.DynamicModel.Value
                % calculate the amplitude from the k12 [fitpar(1)] and k21 [fitpar(4)]
                tmp = fitpar(4)/(fitpar(1)+fitpar(4));
                tmp2 = fitpar(1)/(fitpar(1)+fitpar(4));
                fitpar(1) = tmp;
                fitpar(4) = tmp2;
            end
            % normalize the amplitudes to get a total area of 1
            % this is just for the normpdf plots
            fitpar(1:3:end) = fitpar(1:3:end)/sum(fitpar(1:3:end));

            %%% Calculate Gaussian Distance Distributions
            for c = PDAMeta.Comp{i}
                pdf = normpdf(PDAMeta.Plots.Gauss_All{i,1}.XData,fitpar(3*c-1),fitpar(3*c));
                Gauss{c} = fitpar(3*c-2).*pdf;
                if h.SettingsTab.GaussAmp_Fix.Value
                    Gauss{c} = Gauss{c}./max(pdf);
                end
            end
            
            if h.SettingsTab.OuterBins_Fix.Value
                % do not display or take into account during fitting, the
                % outer bins of the histogram.
                ydatafit = [PDAMeta.hFit{i}(2) PDAMeta.hFit{i}(2:end-1) PDAMeta.hFit{i}(end-1) PDAMeta.hFit{i}(end-1)];
                ydatares = [PDAMeta.w_res{i}(2) PDAMeta.w_res{i}(2:end-1) PDAMeta.w_res{i}(end-1) PDAMeta.w_res{i}(end-1)];
            else
                ydatafit = [PDAMeta.hFit{i} PDAMeta.hFit{i}(end)];
                ydatares = [PDAMeta.w_res{i} PDAMeta.w_res{i}(end)];
            end

            %%% Update All Plot
            set(PDAMeta.Plots.Fit_All{i,1},...
                'Visible', 'on',...
                'YData', ydatafit);
            set(PDAMeta.Plots.Res_All{i},...
                'Visible', 'on',...
                'YData', real(ydatares));
            for c = PDAMeta.Comp{i}
                if h.SettingsTab.OuterBins_Fix.Value
                    % do not display or take into account during fitting, the
                    % outer bins of the histogram.
                    ydatafitind = [PDAMeta.hFit_Ind{i,c}(2); PDAMeta.hFit_Ind{i,c}(2:end-1); PDAMeta.hFit_Ind{i,c}(end-1); PDAMeta.hFit_Ind{i,c}(end-1)];
                else
                    ydatafitind = [PDAMeta.hFit_Ind{i,c}; PDAMeta.hFit_Ind{i,c}(end)];
                end
                set(PDAMeta.Plots.Fit_All{i,c+1},...
                    'Visible', 'on',...
                    'YData', ydatafitind);
            end
            %%% donor only plot (plot #7)
            if PDAMeta.FitParams(i,16) > 0 %%% donor only existent
                if h.SettingsTab.OuterBins_Fix.Value
                    % do not display or take into account during fitting, the
                    % outer bins of the histogram.
                    ydatafitind = [PDAMeta.hFit_Donly{i}(2); PDAMeta.hFit_Donly{i}(2:end-1); PDAMeta.hFit_Donly{i}(end-1); PDAMeta.hFit_Donly{i}(end-1)];
                else
                    ydatafitind = [PDAMeta.hFit_Donly{i}'; PDAMeta.hFit_Donly{i}(end)];
                end
                PDAMeta.Plots.Fit_All{i,7}.Visible = 'on';
                PDAMeta.Plots.Fit_All{i,7}.YData = ydatafitind;
            else
                PDAMeta.Plots.Fit_All{i,7}.Visible = 'off';
            end
            
            if h.SettingsTab.DynamicModel.Value
                % plot the summed dynamic component
                if h.SettingsTab.OuterBins_Fix.Value
                    % do not display or take into account during fitting, the
                    % outer bins of the histogram.
                    ydatafitind = [PDAMeta.hFit_onlyDyn{i}(2); PDAMeta.hFit_onlyDyn{i}(2:end-1); PDAMeta.hFit_onlyDyn{i}(end-1); PDAMeta.hFit_onlyDyn{i}(end-1)];
                else
                    ydatafitind = [PDAMeta.hFit_onlyDyn{i}; PDAMeta.hFit_onlyDyn{i}(end)];
                end
                set(PDAMeta.Plots.Fit_All{i,8},...
                    'Visible', 'on',...
                    'YData', ydatafitind);
            else
                set(PDAMeta.Plots.Fit_All{i,8},'Visible', 'off');
            end
            
            set(PDAMeta.Chi2_All,...
                'Visible','on',...
                'String', ['\chi^2_{red.} = ' sprintf('%1.2f',mean(PDAMeta.chi2))]);
            GaussSum = sum(vertcat(Gauss{:}),1);
            minGaussSum = min([minGaussSum, min(GaussSum)]);
            maxGaussSum = max([maxGaussSum, max(GaussSum)]);
            set(PDAMeta.Plots.Gauss_All{i,1},...
                'Visible', 'on',...
                'YData', GaussSum);
            for c = PDAMeta.Comp{i}
                set(PDAMeta.Plots.Gauss_All{i,c+1},...
                    'Visible', 'on',...
                    'YData', Gauss{c});
            end
            
            %%% Update Single Plot
            if i == find(strcmp(PDAData.FileName,h.SingleTab.Popup.String{h.SingleTab.Popup.Value}))%Active(h.SingleTab.Popup.Value)
                set(PDAMeta.Plots.Fit_Single{1,1},...
                    'Visible', 'on',...
                    'YData', ydatafit);
                set(PDAMeta.Plots.Res_Single,...
                    'Visible', 'on',...
                    'YData', real(ydatares));
                for c = PDAMeta.Comp{i}
                    if h.SettingsTab.OuterBins_Fix.Value
                        % do not display or take into account during fitting, the
                        % outer bins of the histogram.
                        ydatafitind = [PDAMeta.hFit_Ind{i,c}(2); PDAMeta.hFit_Ind{i,c}(2:end-1); PDAMeta.hFit_Ind{i,c}(end-1); PDAMeta.hFit_Ind{i,c}(end-1)];
                    else
                        ydatafitind = [PDAMeta.hFit_Ind{i,c}; PDAMeta.hFit_Ind{i,c}(end)];
                    end
                    set(PDAMeta.Plots.Fit_Single{1,c+1},...
                        'Visible', 'on',...
                        'YData', ydatafitind);
                end
                if h.SettingsTab.DynamicModel.Value
                    % plot the summed dynamic component
                    if h.SettingsTab.OuterBins_Fix.Value
                        % do not display or take into account during fitting, the
                        % outer bins of the histogram.
                        ydatafitind = [PDAMeta.hFit_onlyDyn{i}(2); PDAMeta.hFit_onlyDyn{i}(2:end-1); PDAMeta.hFit_onlyDyn{i}(end-1); PDAMeta.hFit_onlyDyn{i}(end-1)];
                    else
                        ydatafitind = [PDAMeta.hFit_onlyDyn{i}; PDAMeta.hFit_onlyDyn{i}(end)];
                    end
                    set(PDAMeta.Plots.Fit_Single{1,8},...
                        'Visible', 'on',...
                        'YData', ydatafitind);
                else
                    set(PDAMeta.Plots.Fit_Single{1,8},'Visible', 'off');
                end
                set(PDAMeta.Chi2_Single,...
                    'Visible','on',...
                    'String', ['\chi^2_{red.} = ' sprintf('%1.2f',PDAMeta.chi2(i))]);
                % file is shown on the 'Single' tab
                set(PDAMeta.Plots.Gauss_Single{1,1},...
                    'Visible', 'on',...
                    'YData', sum(vertcat(Gauss{:}),1));
                for c = PDAMeta.Comp{i}
                    set(PDAMeta.Plots.Gauss_Single{1,c+1},...
                        'Visible', 'on',...
                        'YData', Gauss{c});
                end
                % set Ylim of the single plot Gauss
                ylim(h.SingleTab.Gauss_Axes,[min(GaussSum), max(GaussSum)*1.05]);
            end
            
            clear Gauss
        end
        %%% Set Gauss Axis X limit
        % get fit parameters
        FitTable = FitTable(1:end-3,2:3:end-1);
        % get all active files and components
        Mini = 40; Maxi = 60;
        for i = Active
            for c = PDAMeta.Comp{i}
                Mini = min(Mini, FitTable(i,3*c-1)-3*FitTable(i,3*c));
                Maxi = max(Maxi, FitTable(i,3*c-1)+3*FitTable(i,3*c));
            end
        end
        Maxi = min(Maxi,150);
        xlim(h.AllTab.Gauss_Axes,[Mini, Maxi]);
        xlim(h.SingleTab.Gauss_Axes,[Mini, Maxi]);
        %xlim(h.AllTab.Gauss_Axes,[20 70]);
        %xlim(h.SingleTab.Gauss_Axes,[20 70]);
        
        %%% Set Gauss Axis Y limit
        ylim(h.AllTab.Gauss_Axes,[minGaussSum, maxGaussSum*1.05]);
    case 5 %% Live Plot update
        i = PDAMeta.file;
        % PDAMeta.Comp{i} = index of the gaussian component that is used
        set(PDAMeta.Plots.Res_All{i},...
            'Visible', 'on',...
            'YData', [PDAMeta.w_res{i} PDAMeta.w_res{i}(end)]);
        if h.SettingsTab.OuterBins_Fix.Value
            % do not display or take into account during fitting, the
            % outer bins of the histogram.
            ydatafit = [PDAMeta.hFit{i}(2) PDAMeta.hFit{i}(2:end-1) PDAMeta.hFit{i}(end-1) PDAMeta.hFit{i}(end-1)];
            ydatares = [PDAMeta.w_res{i}(2) PDAMeta.w_res{i}(2:end-1) PDAMeta.w_res{i}(end-1) PDAMeta.w_res{i}(end-1)];
        else
            ydatafit = [PDAMeta.hFit{i} PDAMeta.hFit{i}(end)];
            ydatares = [PDAMeta.w_res{i} PDAMeta.w_res{i}(end)];
        end
        for c = PDAMeta.Comp{i}
            if h.SettingsTab.OuterBins_Fix.Value
                % do not display or take into account during fitting, the
                % outer bins of the histogram.
                ydatafitind = [PDAMeta.hFit_Ind{i,c}(2); PDAMeta.hFit_Ind{i,c}(2:end-1); PDAMeta.hFit_Ind{i,c}(end-1); PDAMeta.hFit_Ind{i,c}(end-1)];
            else
                ydatafitind = [PDAMeta.hFit_Ind{i,c}; PDAMeta.hFit_Ind{i,c}(end)];
            end
            set(PDAMeta.Plots.Fit_All{i,c+1},...
                'Visible', 'on',...
                'YData', ydatafitind);
        end
        if h.SettingsTab.DynamicModel.Value
            % plot the summed dynamic component
            if h.SettingsTab.OuterBins_Fix.Value
                % do not display or take into account during fitting, the
                % outer bins of the histogram.
                ydatafitind = [PDAMeta.hFit_onlyDyn{i}(2); PDAMeta.hFit_onlyDyn{i}(2:end-1); PDAMeta.hFit_onlyDyn{i}(end-1); PDAMeta.hFit_onlyDyn{i}(end-1)];
            else
                ydatafitind = [PDAMeta.hFit_onlyDyn{i}; PDAMeta.hFit_onlyDyn{i}(end)];
            end
            set(PDAMeta.Plots.Fit_All{i,8},...
                'Visible', 'on',...
                'YData', ydatafitind);
        else
            set(PDAMeta.Plots.Fit_All{i,8},'Visible', 'off');
        end
        set(PDAMeta.Plots.Fit_All{i,1},...
            'Visible', 'on',...
            'YData', ydatafit);
        
        if i == Active(h.SingleTab.Popup.Value)
            set(PDAMeta.Plots.Res_Single,...
                'Visible', 'on',...
                'YData', ydatares);
            for c = PDAMeta.Comp{i}
                if h.SettingsTab.OuterBins_Fix.Value
                    % do not display or take into account during fitting, the
                    % outer bins of the histogram.
                    ydatafitind = [PDAMeta.hFit_Ind{i,c}(2); PDAMeta.hFit_Ind{i,c}(2:end-1); PDAMeta.hFit_Ind{i,c}(end-1); PDAMeta.hFit_Ind{i,c}(end-1)];
                else
                    ydatafitind = [PDAMeta.hFit_Ind{i,c}; PDAMeta.hFit_Ind{i,c}(end)];
                end
                set(PDAMeta.Plots.Fit_Single{1,c+1},...
                    'Visible', 'on',...
                    'YData', ydatafitind);
                %%% donor only plot (plot #7)
                if PDAMeta.FitParams(i,16) > 0 %%% donor only existent
                    if h.SettingsTab.OuterBins_Fix.Value
                        % do not display or take into account during fitting, the
                        % outer bins of the histogram.
                        ydatafitind = [PDAMeta.hFit_Donly{i}(2); PDAMeta.hFit_Donly{i}(2:end-1); PDAMeta.hFit_Donly{i}(end-1); PDAMeta.hFit_Donly{i}(end-1)];
                    else
                        ydatafitind = [PDAMeta.hFit_Donly{i}'; PDAMeta.hFit_Donly{i}(end)];
                    end
                    PDAMeta.Plots.Fit_All{i,7}.Visible = 'on';
                    PDAMeta.Plots.Fit_All{i,7}.YData = ydatafitind;
                else
                    PDAMeta.Plots.Fit_All{i,7}.Visible = 'off';
                end
            end
            if h.SettingsTab.DynamicModel.Value
                % plot the summed dynamic component
                if h.SettingsTab.OuterBins_Fix.Value
                    % do not display or take into account during fitting, the
                    % outer bins of the histogram.
                    ydatafitind = [PDAMeta.hFit_onlyDyn{i}(2); PDAMeta.hFit_onlyDyn{i}(2:end-1); PDAMeta.hFit_onlyDyn{i}(end-1); PDAMeta.hFit_onlyDyn{i}(end-1)];
                else
                    ydatafitind = [PDAMeta.hFit_onlyDyn{i}; PDAMeta.hFit_onlyDyn{i}(end)];
                end
                set(PDAMeta.Plots.Fit_Single{1,8},...
                    'Visible', 'on',...
                    'YData', ydatafitind);
                PDAMeta.Plots.Fit_Single{1,2}.Color = [1 0 1];
                PDAMeta.Plots.Fit_Single{1,3}.Color = [0 1 1];
                PDAMeta.Plots.Fit_Single{1,8}.Color = [1 1 0];
            else
                set(PDAMeta.Plots.Fit_Single{1,8},'Visible', 'off');
                PDAMeta.Plots.Fit_Single{1,2}.Color = [0.2 0.2 0.2];
                PDAMeta.Plots.Fit_Single{1,3}.Color = [0.2 0.2 0.2];
                PDAMeta.Plots.Fit_Single{1,8}.Color = [0.2 0.2 0.2];
            end
            
            set(PDAMeta.Plots.Fit_Single{1,1},...
                'Visible', 'on',...
                'YData', ydatafit);
        end
end

% store settings in UserValues
UserValues.PDA.NoBins = h.SettingsTab.NumberOfBins_Edit.String;
UserValues.PDA.MinPhotons = h.SettingsTab.NumberOfPhotMin_Edit.String;
UserValues.PDA.MaxPhotons = h.SettingsTab.NumberOfPhotMax_Edit.String;
UserValues.PDA.GridRes = h.SettingsTab.NumberOfBinsE_Edit.String;
UserValues.PDA.Smin = h.SettingsTab.StoichiometryThresholdLow_Edit.String;
UserValues.PDA.Smax = h.SettingsTab.StoichiometryThresholdHigh_Edit.String;
UserValues.PDA.Dynamic = h.SettingsTab.DynamicModel.Value;
UserValues.PDA.FixSigmaAtFraction = h.SettingsTab.FixSigmaAtFractionOfR.Value;
UserValues.PDA.SigmaAtFractionOfR = h.SettingsTab.SigmaAtFractionOfR_edit.String;
UserValues.PDA.FixSigmaAtFractionFix = h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value;
UserValues.PDA.IgnoreOuterBins = h.SettingsTab.OuterBins_Fix.Value;
UserValues.PDA.HalfGlobal = h.SettingsTab.HalfGlobal.Value;
UserValues.PDA.DeconvoluteBackground =  h.SettingsTab.DeconvoluteBackground.Value;
if obj == h.SettingsTab.DeconvoluteBackground
    PDAMeta.PreparationDone(:) = 0;
    
    if h.SettingsTab.DeconvoluteBackground.Value == 1 %%% disable other methods that are not supported
        h.SettingsTab.PDAMethod_Popupmenu.String = {'Histogram Library'};
        h.SettingsTab.PDAMethod_Popupmenu.Value = 1;
    else
        if ~h.SettingsTab.DynamicModel.Value
            h.SettingsTab.PDAMethod_Popupmenu.String = {'Histogram Library','MLE','MonteCarlo'};
        end
    end
end
LSUserValues(1)

% File menu - view/start fitting
function Start_PDA_Fit(obj,~)
global PDAData PDAMeta UserValues
h = guidata(findobj('Tag','GlobalPDAFit'));
%%% disable Fit Menu and Fit parameters table
h.FitTab.Table.Enable='off';
%%% Indicates fit in progress
PDAMeta.FitInProgress = 1;

%% Store parameters globally for easy access during fitting
try
    PDAMeta = rmfield(PDAMeta, 'BGdonor');
    PDAMeta = rmfield(PDAMeta, 'BGacc');
    PDAMeta = rmfield(PDAMeta, 'crosstalk');
    PDAMeta = rmfield(PDAMeta, 'R0');
    PDAMeta = rmfield(PDAMeta, 'directexc');
    PDAMeta = rmfield(PDAMeta, 'gamma');
end
allsame = 1;
calc = 1;
for i = 1:numel(PDAData.FileName)
    % if all files have the same parameters as the ALL row some things will only be calculated once
    if ~isequal(cell2mat(h.ParametersTab.Table.Data(i,:)),cell2mat(h.ParametersTab.Table.Data(end,:)))
        if ~isequal(cell2mat(h.ParametersTab.Table.Data(i,1:end-1)),cell2mat(h.ParametersTab.Table.Data(end,1:end-1)))
            allsame = 0;
        end
    end
    PDAMeta.BGdonor(i) = cell2mat(h.ParametersTab.Table.Data(i,4));
    PDAMeta.BGacc(i) = cell2mat(h.ParametersTab.Table.Data(i,5));
    PDAMeta.crosstalk(i) = cell2mat(h.ParametersTab.Table.Data(i,3));
    PDAMeta.R0(i) = cell2mat(h.ParametersTab.Table.Data(i,6));
    PDAMeta.directexc(i) = cell2mat(h.ParametersTab.Table.Data(i,2));
    PDAMeta.gamma(i) = cell2mat(h.ParametersTab.Table.Data(i,1));
    % Make Plots invisible
    for c = 1:8
        PDAMeta.Plots.Fit_All{i,c}.Visible = 'off';
        PDAMeta.Plots.Gauss_All{i,c}.Visible = 'off';
    end
    PDAMeta.Plots.Res_All{i}.Visible = 'off';
    
    if i == h.SingleTab.Popup.Value
        for c = 1:8
            PDAMeta.Plots.Fit_Single{1,c}.Visible = 'off';
            PDAMeta.Plots.Gauss_Single{1,c}.Visible = 'off';
        end
        PDAMeta.Plots.Res_Single.Visible = 'off';
    end
end
Nobins = str2double(h.SettingsTab.NumberOfBins_Edit.String);
NobinsE = str2double(h.SettingsTab.NumberOfBinsE_Edit.String);

% Store active globally at this point. Do not access it globally from
% anywhere else to avoid confusion!
PDAMeta.Active = cell2mat(h.FitTab.Table.Data(1:end-3,1));
%%% if the single tab is selected, only fit this dataset!
if h.Tabgroup_Up.SelectedTab == h.SingleTab.Tab
    PDAMeta.Active(:) = false;
    %%% find which is selected
    selected = find(strcmp(PDAData.FileName,h.SingleTab.Popup.String{h.SingleTab.Popup.Value}));
    PDAMeta.Active(selected) = true;
end
    
%%% Read fit settings and store in UserValues
%% Prepare Fit Inputs
if (any(PDAMeta.PreparationDone == 0)) || ~isfield(PDAMeta,'eps_grid')
    counter = 1;
    maxN = 0;
    for i  = find(PDAMeta.Active)'
        if strcmp(PDAData.Type{i},'Burst')
            %%% find valid bins (chosen by thresholds min/max and stoichiometry)
            StoAll = (PDAData.Data{i}.NF+PDAData.Data{i}.NG)./(PDAData.Data{i}.NG+PDAData.Data{i}.NF+PDAData.Data{i}.NR);
            PDAMeta.valid{i} = ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) > str2double(h.SettingsTab.NumberOfPhotMin_Edit.String)) & ... % min photon number
                ((PDAData.Data{i}.NF+PDAData.Data{i}.NG) < str2double(h.SettingsTab.NumberOfPhotMax_Edit.String)) & ... % max photon number
                ((StoAll > str2double(h.SettingsTab.StoichiometryThresholdLow_Edit.String))) & ... % Stoichiometry low
                ((StoAll < str2double(h.SettingsTab.StoichiometryThresholdHigh_Edit.String))); % Stoichiometry high
        else
            PDAMeta.valid{i} = true(size(PDAData.Data{i}.NF));
        end
        %%% find the maxN of all data
        maxN = max(maxN, max((PDAData.Data{i}.NF(PDAMeta.valid{i})+PDAData.Data{i}.NG(PDAMeta.valid{i}))));
    end

    for i  = find(PDAMeta.Active)'
        if ~PDAMeta.FitInProgress
            break;
        end
        if PDAMeta.PreparationDone(i) == 1
            %disp(sprintf('skipping file %i',i));
            continue; %skip this file
        end
        if counter > 1
            if allsame
                %calculate some things only once
                calc = 0;
            end
        end
        PDAMeta.P(i,:) = cell(1,NobinsE+1);
        if calc
            %%% evaluate the background probabilities
            BGgg = poisspdf(0:1:maxN,PDAMeta.BGdonor(i)*PDAData.timebin(i)*1E3);
            BGgr = poisspdf(0:1:maxN,PDAMeta.BGacc(i)*PDAData.timebin(i)*1E3);
            
            method = 'cdf';
            switch method
                case 'pdf'
                    %determine boundaries for background inclusion
                    BGgg(BGgg<1E-2) = [];
                    BGgr(BGgr<1E-2) = [];
                case 'cdf'
                    %%% evaluate the background probabilities
                    CDF_BGgg = poisscdf(0:1:maxN,PDAMeta.BGdonor(i)*PDAData.timebin(i)*1E3);
                    CDF_BGgr = poisscdf(0:1:maxN,PDAMeta.BGacc(i)*PDAData.timebin(i)*1E3);
                    %determine boundaries for background inclusion
                    threshold = 0.95;
                    BGgg((find(CDF_BGgg>threshold,1,'first')+1):end) = [];
                    BGgr((find(CDF_BGgr>threshold,1,'first')+1):end) = [];
            end
            PBG = BGgg./sum(BGgg);
            PBR = BGgr./sum(BGgr);
            NBG = numel(BGgg)-1;
            NBR = numel(BGgr)-1;
        end
        % assign current file to global cell
        PDAMeta.PBG{i} = PBG;
        PDAMeta.PBR{i} = PBR;
        PDAMeta.NBG{i} = NBG;
        PDAMeta.NBR{i} = NBR;
        
        if strcmp(h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value},'Histogram Library')
            if calc
                %%% prepare epsilon grid
                Progress(0,h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Preparing Epsilon Grid...');
                Progress(0,h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Preparing Epsilon Grid...');
                
                % generate NobinsE+1 values for eps
                %E_grid = linspace(0,1,NobinsE+1);
                %R_grid = linspace(0,5*PDAMeta.R0(i),100000)';
                %epsEgrid = 1-(1+PDAMeta.crosstalk(i)+PDAMeta.gamma(i)*((E_grid+PDAMeta.directexc(i)/(1-PDAMeta.directexc(i)))./(1-E_grid))).^(-1);
                %epsRgrid = 1-(1+PDAMeta.crosstalk(i)+PDAMeta.gamma(i)*(((PDAMeta.directexc(i)/(1-PDAMeta.directexc(i)))+(1./(1+(R_grid./PDAMeta.R0(i)).^6)))./(1-(1./(1+(R_grid./PDAMeta.R0(i)).^6))))).^(-1);
                
                %%% new: use linear distribution of eps since the
                %%% conversion of P(R) to P(eps) returns a probility
                %%% density, that would have to be converted to a
                %%% probability by multiplying with the bin width.
                %%% Instead, usage of a linear grid of eps ensures that the
                %%% returned P(eps) is directly a probabilty
                eps_min = 1-(1+PDAMeta.crosstalk(i)+PDAMeta.gamma(i)*((0+PDAMeta.directexc(i)/(1-PDAMeta.directexc(i)))./(1-0))).^(-1);
                eps_grid = linspace(eps_min,1,NobinsE+1);
                [NF, N, eps] = meshgrid(0:maxN,1:maxN,eps_grid);
                % generates a grid cube:
                % NF all possible number of FRET photons
                % N all possible total number of photons
                % eps all possible FRET efficiencies
                Progress((i-1)/sum(PDAMeta.Active),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Preparing Probability Library...');
                Progress((i-1)/sum(PDAMeta.Active),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Preparing Probability Library...');
                % generate a P(NF) cube given fixed initial values of NF, N and given particular values of eps 
                pause(0.2)
                tic;
                PNF = calc_PNF(NF(:),N(:),eps(:),numel(NF));
                PNF = reshape(PNF,size(eps,1),size(eps,2),size(eps,3));
                toc
                %PNF = binopdf(NF, N, eps);
                % binopdf(X,N,P) returns the binomial probability density function with parameters N and P at the values in X.
                %%% Also calculate distribution for donor only
                PNF_donly = binopdf(NF(:,:,1),N(:,:,1),PDAMeta.crosstalk(i)/(1+PDAMeta.crosstalk(i)));
            end
            if ~UserValues.PDA.DeconvoluteBackground
                % histogram NF+NG into maxN+1 bins
                PN = histcounts((PDAData.Data{i}.NF(PDAMeta.valid{i})+PDAData.Data{i}.NG(PDAMeta.valid{i})),1:(maxN+1));
            else
                PN = deconvolute_PofF(PDAData.Data{i}.NF(PDAMeta.valid{i})+PDAData.Data{i}.NG(PDAMeta.valid{i}),(PDAMeta.BGdonor(i)+PDAMeta.BGacc(i))*PDAData.timebin(i)*1E3);
                PN = PN(1:maxN).*sum(PDAMeta.valid{i} &  ~((PDAData.Data{i}.NG == 0) & (PDAData.Data{i}.NF == 0)));
            end
            % assign current file to global cell
            %PDAMeta.E_grid{i} = E_grid;
            %PDAMeta.R_grid{i} = R_grid;
            PDAMeta.eps_grid{i} = eps_grid;
            %PDAMeta.epsRgrid{i} = epsRgrid;
            PDAMeta.PN{i} = PN;
            PDAMeta.PNF{i} = PNF;
            PDAMeta.PNF_donly{i} = PNF_donly;
            PDAMeta.Grid.NF{i} = NF;
            PDAMeta.Grid.N{i} = N;
            PDAMeta.Grid.eps{i} = eps;
            PDAMeta.maxN{i} = maxN;
            
            %% Calculate Histogram Library (CalcHistLib)
            Progress(0,h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Calculating Histogram Library...');
            Progress(0,h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Calculating Histogram Library...');
            PDAMeta.HistLib = [];
            P = cell(1,numel(eps_grid));
            PN_dummy = PN';
            %% Calculate shot noise limited histogram
            % case 1, no background in either channel
            if NBG == 0 && NBR == 0
                for j = 1:numel(eps_grid)
                    %for a particular value of E
                    P_temp = PNF(:,:,j);
                    E_temp = NF(:,:,j)./N(:,:,j);
                    [~,~,bin] = histcounts(E_temp(:),linspace(0,1,Nobins+1));
                    validd = (bin ~= 0);
                    P_temp = P_temp(:);
                    bin = bin(validd);
                    P_temp = P_temp(validd);
                    % Progress(j/numel(E_grid),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Calculating Histogram Library...');
                    % Progress(j/numel(E_grid),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Calculating Histogram Library...');
                    %%% Store bin,valid and P_temp variables for brightness correction
                    PDAMeta.HistLib.bin{i}{j} = bin;
                    PDAMeta.HistLib.P_array{i}{j} = P_temp;
                    PDAMeta.HistLib.valid{i}{j} = validd;

                    PN_trans = repmat(PN_dummy,1,maxN+1);
                    PN_trans = PN_trans(:);
                    PN_trans = PN_trans(PDAMeta.HistLib.valid{i}{j});
                    P{1,j} = accumarray(PDAMeta.HistLib.bin{i}{j},PDAMeta.HistLib.P_array{i}{j}.*PN_trans);
                end
            else
                for j = 1:numel(eps_grid)
                    bin = cell((NBG+1)*(NBR+1),1);
                    P_array = cell((NBG+1)*(NBR+1),1);
                    validd = cell((NBG+1)*(NBG+1),1);
                    count = 1;
                    for g = 0:NBG
                        for r = 0:NBR
                            P_temp = PBG(g+1)*PBR(r+1)*PNF(1:end-g-r,:,j); %+1 since also zero is included
                            E_temp = (NF(1:end-g-r,:,j)+r)./(N(1:end-g-r,:,j)+g+r);
                            [~,~,bin{count}] = histcounts(E_temp(:),linspace(0,1,Nobins+1));
                            validd{count} = (bin{count} ~= 0);
                            P_temp = P_temp(:);
                            bin{count} = bin{count}(validd{count});
                            P_temp = P_temp(validd{count});
                            P_array{count} = P_temp;
                            count = count+1;
                        end
                    end
                    
                    %%% Store bin,valid and P_array variables for brightness
                    %%% correction
                    PDAMeta.HistLib.bin{i}{j} = bin;
                    PDAMeta.HistLib.P_array{i}{j} = P_array;
                    PDAMeta.HistLib.valid{i}{j} = validd;
                            
                    P{1,j} = zeros(Nobins,1);
                    count = 1;
                    if ~UserValues.PDA.DeconvoluteBackground
                        for g = 0:NBG
                            for r = 0:NBR
                                %%% Approximation of P(F) ~= P(S), i.e. use
                                %%% P(S) with S = F + BG
                                PN_trans = repmat(PN_dummy(1+g+r:end),1,maxN+1);%the total number of fluorescence photons is reduced
                                PN_trans = PN_trans(:);
                                PN_trans = PN_trans(validd{count});
                                P{1,j} = P{1,j} + accumarray(bin{count},P_array{count}.*PN_trans);
                                count = count+1;
                            end
                        end
                    else
                        for g = 0:NBG
                            for r = 0:NBR
                                %%% Use the deconvolved P(F)
                                PN_trans = repmat(PN_dummy(1:end-g-r),1,maxN+1);%the total number of fluorescence photons is reduced
                                PN_trans = PN_trans(:);
                                PN_trans = PN_trans(validd{count});
                                P{1,j} = P{1,j} + accumarray(bin{count},P_array{count}.*PN_trans);
                                count = count+1;
                            end
                        end
                    end
                    %Progress(j/numel(E_grid),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Calculating Histogram Library...');
                    %Progress(j/numel(E_grid),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Calculating Histogram Library...');
                end
            end
            %% Caclulate shot noise limited histogram for Donly
            if NBG == 0 && NBR == 0
                %for a particular value of E
                P_temp = PNF_donly;
                E_temp = NF(:,:,1)./N(:,:,1);
                [~,~,bin] = histcounts(E_temp(:),linspace(0,1,Nobins+1));
                validd = (bin ~= 0);
                P_temp = P_temp(:);
                bin = bin(validd);
                P_temp = P_temp(validd);

                PN_trans = repmat(PN_dummy,1,maxN+1);
                PN_trans = PN_trans(:);
                PN_trans = PN_trans(validd);
                P_donly = accumarray(bin,P_temp.*PN_trans);
            else
                bin = cell((NBG+1)*(NBR+1),1);
                P_array = cell((NBG+1)*(NBR+1),1);
                validd = cell((NBG+1)*(NBG+1),1);
                count = 1;
                for g = 0:NBG
                    for r = 0:NBR
                        P_temp = PBG(g+1)*PBR(r+1)*PNF_donly(1:end-g-r,:); %+1 since also zero is included
                        E_temp = (NF(1:end-g-r,:,1)+r)./(N(1:end-g-r,:,1)+g+r);
                        [~,~,bin{count}] = histcounts(E_temp(:),linspace(0,1,Nobins+1));
                        validd{count} = (bin{count} ~= 0);
                        P_temp = P_temp(:);
                        bin{count} = bin{count}(validd{count});
                        P_temp = P_temp(validd{count});
                        P_array{count} = P_temp;
                        count = count+1;
                    end
                end

                P_donly = zeros(Nobins,1);
                count = 1;
                if ~UserValues.PDA.DeconvoluteBackground
                    for g = 0:NBG
                        for r = 0:NBR
                            %%% Approximation of P(F) ~= P(S), i.e. use
                            %%% P(S) with S = F + BG
                            PN_trans = repmat(PN_dummy(1+g+r:end),1,maxN+1);%the total number of fluorescence photons is reduced
                            PN_trans = PN_trans(:);
                            PN_trans = PN_trans(validd{count});
                            P_donly = P_donly + accumarray(bin{count},P_array{count}.*PN_trans);
                            count = count+1;
                        end
                    end
                else
                    for g = 0:NBG
                        for r = 0:NBR
                            %%% Use the deconvolved P(F)
                            PN_trans = repmat(PN_dummy(1:end-g-r),1,maxN+1);%the total number of fluorescence photons is reduced
                            PN_trans = PN_trans(:);
                            PN_trans = PN_trans(validd{count});
                            P_donly = P_donly + accumarray(bin{count},P_array{count}.*PN_trans);
                            count = count+1;
                        end
                    end
                end
            end
            % different files = different rows
            % different Ps = different columns
            PDAMeta.P(i,:) = P;
            PDAMeta.P_donly{i} = P_donly;
            PDAMeta.PreparationDone(i) = 1;
        end
        counter = counter + 1;
    end
end
%% Store fit parameters globally
PDAMeta.Fixed = cell2mat(h.FitTab.Table.Data(1:end-3,3:3:end-1));
PDAMeta.Global = cell2mat(h.FitTab.Table.Data(end-2,4:3:end-1));
LB = h.FitTab.Table.Data(end-1,2:3:end-1);
PDAMeta.LB = cellfun(@str2double,LB);
UB = h.FitTab.Table.Data(end  ,2:3:end-1);
PDAMeta.UB = cellfun(@str2double,UB);
FitTable = cellfun(@str2double,h.FitTab.Table.Data);
PDAMeta.FitParams = FitTable(1:end-3,2:3:end-1);
        
clear LB UB FitTable

if any(isnan(PDAMeta.FitParams(:)))
    disp('There were NaNs in the fit parameters. Aborting');
    h.Menu.Fit.Enable = 'on';
    return;
end

% generate a cell array, with each cell a file, and the contents of the
% cell is the gaussian components that are used per file during fitting.
Comp = cell(numel(PDAData.FileName));
for i = find(PDAMeta.Active)'
    comp = [];
    % the used gaussian fit components
    for c = 1:5
        if PDAMeta.Fixed(i,3*c-2)==false || PDAMeta.FitParams(i,3*c-2)~=0
            % Amp ~= fixed || Amp ~= 0
            comp = [comp c];
        end
    end
    Comp{i} = comp;
end
PDAMeta.Comp = Comp;

PDAMeta.chi2 = [];
PDAMeta.ConfInt = [];
PDAMeta.MCMC_mean = [];
%%
% In general, 3 ways can used for fixing parameters
% passing them into the fit function, but fixing them again to their initial value in the fit function (least elegant)
% passing them into the fit function and fixing their UB&LB to their initial value (used in PDAFit)
% not passing them into the fit function, but just calling their values inside the fit function (used in FCSFit and global PDAFit)

if sum(PDAMeta.Global) == 0
    %% One-curve-at-a-time fitting
    fit_counter = 0;
    for i = find(PDAMeta.Active)'
        fit_counter = fit_counter + 1;
        LB = PDAMeta.LB;
        UB = PDAMeta.UB;
        h.SingleTab.Popup.Value = i;
        Update_Plots([],[],2); %to ensure the correct data is plotted on single tab during fitting
        PDAMeta.file = i;
        fitpar = PDAMeta.FitParams(i,:);
        fixed = PDAMeta.Fixed(i,:);
        LB(fixed) = fitpar(fixed);
        UB(fixed) = fitpar(fixed);
        
        %%% If sigma is fixed at fraction of R, add the parameter here
        if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
            fitpar(end+1) = str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String);
            fixed(end+1) = h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value;
            if h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value %%% Value should be fixed
                LB(end+1) = fitpar(end);
                UB(end+1) = fitpar(end);
            else
                LB(end+1) = 0;
                UB(end+1) = 1;
            end
        end 
        % Fixed for Patternsearch and fmincon
        if sum(fixed) == 0 %nothing is Fixed
            A = [];
            b = [];
        elseif sum(fixed(:)) > 0
            A = zeros(numel(fixed)); %NxN matrix with zeros
            b = zeros(numel(fixed),1);
            for j = 1:numel(fixed)
                if fixed(j) == 1 %set diagonal to 1 and b to value --> 1*x = b
                    A(j,j) = 1;
                    b(j) = fitpar(j);
                end
            end
        end
        
        switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
            case 'Histogram Library'
                fitfun = @(x) PDAHistogramFit_Single(x,h);
            case 'MLE'
                %msgbox('doesnt work yet')
                %return
                fitfun = @(x) PDA_MLE_Fit_Single(x,h);
                if strcmp(h.SettingsTab.FitMethod_Popupmenu.String{h.SettingsTab.FitMethod_Popupmenu.Value},'Gradient-based (lsqnonlin)')
                    disp('Gradient-based (lsqnonlin) does not work for MLE. Choose fmincon instead.');
                    Progress(1, h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Done');
                    Progress(1, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Done');
                    %%% re-enable Fit Menu
                    h.FitTab.Table.Enable='on';
                    PDAMeta.FitInProgress = 0;
                    return;
                end
            case 'MonteCarlo'
                %msgbox('doesnt work yet')
                %return
                fitfun = @(x) PDAMonteCarloFit_Single(x);
        end
                
        switch obj
            case h.Menu.ViewFit
                %% Check if View_Curve was pressed
                %%% Only Update Plot and break
                Progress((fit_counter-1)/sum(PDAMeta.Active),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Simulating Histograms...');
                Progress((fit_counter-1)/sum(PDAMeta.Active),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Simulating Histograms...');
                switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
                    case {'MLE','MonteCarlo'}
                        %%% For Updating the Result Plot, use MC sampling
                        PDAMonteCarloFit_Single(fitpar);
                    case 'Histogram Library'
                        PDAHistogramFit_Single(fitpar,h);
                end
            case h.Menu.StartFit
                %% evaluate once to make plots available
                switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
                    case {'MLE','MonteCarlo'}
                        %%% For Updating the Result Plot, use MC sampling
                        PDAMonteCarloFit_Single(fitpar);
                    case 'Histogram Library'
                        PDAHistogramFit_Single(fitpar,h);
                end
                %% Do Fit
                Progress((fit_counter-1)/sum(PDAMeta.Active),h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Fitting Histograms...');
                Progress((fit_counter-1)/sum(PDAMeta.Active),h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Fitting Histograms...');
                
                switch h.SettingsTab.FitMethod_Popupmenu.String{h.SettingsTab.FitMethod_Popupmenu.Value}
                    case 'Simplex'
                        fitopts = optimset('MaxFunEvals', 1E4,'Display','iter','TolFun',1E-6,'TolX',1E-3);%,'PlotFcns',@optimplotfvalPDA);
                        fitpar = fminsearchbnd(fitfun, fitpar, LB, UB, fitopts);
                    case 'Gradient-based (lsqnonlin)'
                        PDAMeta.FitInProgress = 2; % indicate that we want a vector of residuals, instead of chi2, and that we only pass non-fixed parameters
                        fitopts = optimoptions('lsqnonlin','MaxFunEvals', 1E4,'Display','iter');
                        fitpar(~fixed) = lsqnonlin(fitfun,fitpar(~fixed),LB(~fixed),UB(~fixed),fitopts);
                    case 'Gradient-based (fmincon)'
                        fitopts = optimoptions('fmincon','MaxFunEvals',1E4,'Display','iter');%,'PlotFcns',@optimplotfvalPDA);
                        fitpar = fmincon(fitfun, fitpar,[],[],A,b,LB,UB,[],fitopts);
                    case 'Patternsearch'
                        opts = psoptimset('Cache','on','Display','iter','PlotFcns',@psplotbestf);%,'UseParallel','always');
                        fitpar = patternsearch(fitfun, fitpar, [],[],A,b,LB,UB,[],opts);
                    case 'Gradient-based (global)'
                        opts = optimoptions(@fmincon,'Algorithm','interior-point','Display','iter');%,'PlotFcns',@optimplotfvalPDA);
                        problem = createOptimProblem('fmincon','objective',fitfun,'x0',fitpar,'Aeq',A,'beq',b,'lb',LB,'ub',UB,'options',opts);
                        gs = GlobalSearch;
                        fitpar = run(gs,problem);
                end
            case {h.Menu.EstimateErrorHessian,h.Menu.EstimateErrorMCMC}
                alpha = 0.05; %95% confidence interval
                %%% get error bars from jacobian
                PDAMeta.FitInProgress = 2; % set to two to indicate error estimation based on gradient (only compute hessian with respect to non-fixed parameters)
                %call fminunc at final point with 1 iteration to get hessian
                PDAMeta.Fixed = fixed;
                fitopts = optimoptions('lsqnonlin','MaxIter',1);
                [~,~,residual,~,~,~,jacobian] = lsqnonlin(fitfun,fitpar(~fixed),LB(~fixed),UB(~fixed),fitopts);
                ci = nlparci(fitpar(~fixed),residual,'jacobian',jacobian,'alpha',alpha);
                ci = (ci(:,2)-ci(:,1))/2;
                PDAMeta.ConfInt_Jac(:,i) = ci;
                %%% Alternative implementations using fminunc and fmincon to estimate the hessian
                % fitopts = optimoptions('fminunc','MaxIter',1,'Algorithm','quasi-newton');
                % [~,~,~,~,~,hessian] = fminunc(fitfun,fitpar(~fixed),fitopts);
                % fitopts = optimoptions('fmincon','MaxFunEvals',1E4,'Display','iter');%,'PlotFcns',@optimplotfvalPDA);
                % [~,~,~,~,~,~,hessian] = fmincon(fitfun, fitpar,[],[],A,b,LB,UB,[],fitopts);
                %err = sqrt(diag(inv(hessian)));
                if obj == h.Menu.EstimateErrorMCMC %%% refine by doing MCMC sampling
                        PDAMeta.FitInProgress = 3; %%% indicate that we need a loglikelihood instead of chi2 value
                        % use MCMC sampling to get errorbar estimates
                        %%% query sampling parameters
                        data = inputdlg({'Number of samples:','Spacing for statistical independence:'},'Specify MCMC sampling parameters',1,{'1000','10'});
                        data = cellfun(@str2double,data);
                        nsamples = data(1); spacing = data(2);
                        proposal = ci'/10;
                        [samples,prob,acceptance] =  MHsample(nsamples,fitfun,@(x) 1,proposal,LB,UB,fitpar',fixed',~fixed',cellfun(@(x) x(11:end-4),h.FitTab.Table.ColumnName(2:3:end-1),'UniformOutput',false));
                        v = numel(residual)-numel(fitpar(~fixed)); % number of degrees of freedom
                        perc = tinv(1-alpha/2,v);
                        PDAMeta.ConfInt_MCMC(:,i) = perc*std(samples(1:spacing:end,~fixed))';
                        PDAMeta.MCMC_mean(:,i) = mean(samples(1:spacing:end,~fixed))';
                end
                PDAMeta.FitInProgress = 0; % disable fit
        end
        %Calculate chi^2
        switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
            case 'Histogram Library'
                %PDAMeta.chi2 = PDAHistogramFit_Single(fitpar);
            case 'MLE'
                %%% For Updating the Result Plot, use MC sampling
                PDAMeta.chi2(i) = PDAMonteCarloFit_Single(fitpar);
                %%% Update Plots
                h.FitTab.Bar.YData = PDAMeta.hFit;
                h.Res_Bar.YData = PDAMeta.w_res;
                for c = comp
                    h.FitTab.BarInd{i}.YData = PDAMeta.hFit_Ind{c};
                end
                if isfield(PDAMeta,'Last_logL')
                    PDAMeta = rmfield(PDAMeta,'Last_logL');
                end
            case 'MonteCarlo'
                %PDAMeta.chi2 = PDAMonteCarloFit_Single(fitpar);
            otherwise
                PDAMeta.chi2(i) = 0;
        end
        
        % display final mean chi^2
        set(PDAMeta.Chi2_All, 'Visible','on','String', ['avg. \chi^2_{red.} = ' sprintf('%1.2f',mean(PDAMeta.chi2))]);
        
        %%% If sigma was fixed at fraction of R, update edit box here and
        %%% remove from fitpar array
        %%% if sigma is fixed at fraction of, read value here before reshape
        if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
            h.SettingsTab.SigmaAtFractionOfR_edit.String = num2str(fitpar(end));
            fitpar(end) = [];
            %%% if sigma is fixed at fraction of, change its value here
            fraction = str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String);
            fitpar(3:3:end) = fraction.*fitpar(2:3:end);
        end
        % put optimized values back in table
        try
            h.FitTab.Table.Data(i,2:3:end) = cellfun(@num2str, num2cell([fitpar PDAMeta.chi2(i)]),'Uniformoutput',false);
        catch
            h.FitTab.Table.Data(i,2:3:end) = cellfun(@num2str, num2cell([fitpar NaN]),'Uniformoutput',false);
        end
    end
else
    %% Global fitting
    %%% Sets initial value and bounds for global parameters
    % PDAMeta.Global    = 1     x 16 logical
    % PDAMeta.Fixed     = files x 16 logical
    % PDAMeta.FitParams = files x 16 double
    % PDAMeta.UB/LB     = 1     x 16 double
    
    % check 'Half Global' if you want to globally link a parameter between
    % the first part of the files, and globally link the same parameter for the
    % last part of the files. Do not F that parameter but G it in the UI.
    if UserValues.PDA.HalfGlobal
        PDAMeta.SecondHalf = 5; %index of the first file of the second part of the dataset
        %define which parameters are partly global
        PDAMeta.HalfGlobal = false(1,16); 
        %PDAMeta.HalfGlobal(1) = true; %half globally link k12
        %PDAMeta.HalfGlobal(4) = true; %half globally link k21
        %PDAMeta.HalfGlobal(7) = true; %half globally link Area3
        %PDAMeta.HalfGlobal(2) = true; %half globally link R1
        %PDAMeta.HalfGlobal(5) = true; %half globally link R2
        %PDAMeta.HalfGlobal(3) = true; %half globally link sigma1
        %PDAMeta.HalfGlobal(6) = true; %half globally link sigma2
    end
    
    %%% If sigma is fixed at fraction of R, add the parameter here
    if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
        PDAMeta.FitParams(:,end+1) = str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String);
        %%% Set either not fixed and global, or fixed and not global
        PDAMeta.Global(:,end+1) = 1-h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value;
        PDAMeta.Fixed(:,end+1) = h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value;
        PDAMeta.LB(:,end+1) = 0;
        PDAMeta.UB(:,end+1) = 1;
    end 
    
    fitpar = PDAMeta.FitParams(1,PDAMeta.Global);
    LB = PDAMeta.LB(PDAMeta.Global);
    UB = PDAMeta.UB(PDAMeta.Global); 
    if UserValues.PDA.HalfGlobal
        % put the half-globally linked parameter after the global ones
        fitpar = [fitpar PDAMeta.FitParams(PDAMeta.SecondHalf, PDAMeta.HalfGlobal)];
        LB = [LB PDAMeta.LB(PDAMeta.HalfGlobal)];
        UB = [UB PDAMeta.UB(PDAMeta.HalfGlobal)];
    end
    PDAMeta.hProxGlobal = [];
    for i=find(PDAMeta.Active)'
        %%% Concatenates y data of all active datasets
        PDAMeta.hProxGlobal = [PDAMeta.hProxGlobal PDAMeta.hProx{i}];
        %%% Concatenates initial values and bounds for non fixed parameters
        fitpar = [fitpar PDAMeta.FitParams(i, ~PDAMeta.Fixed(i,:)& ~PDAMeta.Global)];
        LB=[LB PDAMeta.LB(~PDAMeta.Fixed(i,:) & ~PDAMeta.Global)];
        UB=[UB PDAMeta.UB(~PDAMeta.Fixed(i,:) & ~PDAMeta.Global)];
    end
    
    switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
        case 'Histogram Library'
            fitfun = @(x) PDAHistogramFit_Global(x,h);
        case 'MLE'
            fitfun = @(x) PDAMLEFit_Global(x,h);
        otherwise
            msgbox('Use Histogram Library, others dont work yet for global')
            return
    end
    %% Check if View_Curve was pressed
    switch obj
        case h.Menu.ViewFit
             %%% Only Update Plot and break
            Progress(0,h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Simulating Histograms...');
            Progress(0,h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Simulating Histograms...');
            switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
                case {'MLE','MonteCarlo'}
                    %%% For Updating the Result Plot, use MC sampling
                    PDAMonteCarloFit_Global(fitpar);
                case 'Histogram Library'
                    PDAHistogramFit_Global(fitpar,h);
            end
        case h.Menu.StartFit
            %% Do Fit
            switch h.SettingsTab.FitMethod_Popupmenu.String{h.SettingsTab.FitMethod_Popupmenu.Value}
                case 'Simplex'
                    fitopts = optimset('MaxFunEvals', 1E4,'Display','iter','TolFun',1E-6,'TolX',1E-3);%,'PlotFcns',@optimplotfvalPDA);
                    fitpar = fminsearchbnd(fitfun, fitpar, LB, UB, fitopts);
                case 'Gradient-based (lsqnonlin)'
                    PDAMeta.FitInProgress = 2; % indicate that we want a vector of residuals, instead of chi2, and that we only pass non-fixed parameters
                    fitopts = optimoptions('lsqnonlin','MaxFunEvals', 1E4,'Display','iter');
                    fitpar = lsqnonlin(fitfun,fitpar,LB,UB,fitopts);
                case 'Gradient-based (fmincon)'
                    fitopts = optimoptions('fmincon','MaxFunEvals',1E4,'Display','iter');%,'PlotFcns',@optimplotfvalPDA);
                    fitpar = fmincon(fitfun, fitpar,[],[],[],[],LB,UB,[],fitopts);
                case 'Patternsearch'
                    opts = psoptimset('Cache','on','Display','iter','PlotFcns',@psplotbestf);%,'UseParallel','always');
                    fitpar = patternsearch(fitfun, fitpar, [],[],[],[],LB,UB,[],opts);
                case 'Gradient-based (global)'
                    opts = optimoptions(@fmincon,'Algorithm','interior-point','Display','iter');%,'PlotFcns',@optimplotfvalPDA);
                    problem = createOptimProblem('fmincon','objective',fitfun,'x0',fitpar,'Aeq',[],'beq',[],'lb',LB,'ub',UB,'options',opts);
                    gs = GlobalSearch;
                    fitpar = run(gs,problem);
            end

            %Calculate chi^2
            switch h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value}
                case 'Histogram Library'
                    %PDAMeta.chi2 = PDAHistogramFit_Single(fitpar);
                case 'MLE'
                    %%% For Updating the Result Plot, use MC sampling
                    PDAMeta.FitInProgress = 1;
                    PDAMonteCarloFit_Global(fitpar);
                    PDAMeta.FitInProgress = 0;
                    if isfield(PDAMeta,'Last_logL')
                        PDAMeta = rmfield(PDAMeta,'Last_logL');
                    end
                case 'MonteCarlo'
                    %PDAMeta.chi2 = PDAMonteCarloFit_Single(fitpar);
                otherwise
                    PDAMeta.chi2 = 0;
            end


            %%% Sort optimized fit parameters back into table
            PDAMeta.FitParams(:,PDAMeta.Global)=repmat(fitpar(1:sum(PDAMeta.Global)),[size(PDAMeta.FitParams,1) 1]) ;
            fitpar(1:sum(PDAMeta.Global))=[];
            if UserValues.PDA.HalfGlobal
                PDAMeta.FitParams(PDAMeta.SecondHalf:end,PDAMeta.HalfGlobal)=repmat(fitpar(1:sum(PDAMeta.HalfGlobal)),[(size(PDAMeta.FitParams,1)-PDAMeta.SecondHalf+1) 1]) ;
                fitpar(1:sum(PDAMeta.HalfGlobal))=[];
            end

            for i=find(PDAMeta.Active)'
                PDAMeta.FitParams(i, ~PDAMeta.Fixed(i,:) & ~PDAMeta.Global) = fitpar(1:sum(~PDAMeta.Fixed(i,:) & ~PDAMeta.Global));
                fitpar(1:sum(~PDAMeta.Fixed(i,:)& ~PDAMeta.Global))=[];
            end

            %%% If sigma was fixed at fraction of R, update edit box here and
            %%% remove from fitpar array
            %%% if sigma is fixed at fraction of, read value here before reshape
            if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
                 fraction = PDAMeta.FitParams(1,end);
                 h.SettingsTab.SigmaAtFractionOfR_edit.String = num2str(fraction);
                 PDAMeta.FitParams(:,end) = [];
                 PDAMeta.Global(:,end) = [];
                 PDAMeta.Fixed(:,end) = [];
            end

            for i = find(PDAMeta.Active)'
                %%% if sigma is fixed at fraction of, change its value here
                if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
                    PDAMeta.FitParams(i,3:3:end) = fraction.*PDAMeta.FitParams(i,2:3:end);
                end
                h.FitTab.Table.Data(i,2:3:end) = cellfun(@num2str,num2cell([PDAMeta.FitParams(i,:) PDAMeta.chi2(i)]),'UniformOutput',false);
            end
        case {h.Menu.EstimateErrorHessian,h.Menu.EstimateErrorMCMC}
            alpha = 0.05; %95% confidence interval
            %%% get error bars from jacobian
            PDAMeta.FitInProgress = 2; % set to two to indicate error estimation based on gradient (only compute hessian with respect to non-fixed parameters)
            fitopts = optimoptions('lsqnonlin','MaxIter',1);
            [~,~,residual,~,~,~,jacobian] = lsqnonlin(fitfun,fitpar,LB,UB,fitopts);
            ci = nlparci(fitpar,residual,'jacobian',jacobian,'alpha',alpha);
            ci = (ci(:,2)-ci(:,1))/2; ci = ci';PDAMeta.ConfInt_Jac = ci;
            if obj ==  h.Menu.EstimateErrorMCMC %%% additionally, refine by doing mcmc sampling
                PDAMeta.FitInProgress = 3; %%% indicate to get loglikelihood instead chi2
                % get parameter names in correct order
                param_names = repmat(h.FitTab.Table.ColumnName(2:3:end-1)',size(PDAMeta.FitParams,1),1);
                param_names = cellfun(@(x) x(11:end-4),param_names,'UniformOutput',false);
                names = param_names(1,PDAMeta.Global); 
                if UserValues.PDA.HalfGlobal
                    % put the half-globally linked parameter after the global ones
                    names = [names param_names(PDAMeta.SecondHalf, PDAMeta.HalfGlobal)];
                end
                for i=find(PDAMeta.Active)'
                    %%% Concatenates initial values and bounds for non fixed parameters
                    names = [names param_names(i, ~PDAMeta.Fixed(i,:)& ~PDAMeta.Global)];
                end
                % use MCMC sampling to get errorbar estimates
                proposal = ci/10; 
                %%% Sample
                nsamples = 1E3; spacing = 10;
                [samples,prob,acceptance] =  MHsample(nsamples,fitfun,@(x) 1,proposal,LB,UB,fitpar',zeros(numel(fitpar),1),ones(numel(fitpar),1),names);
                v = numel(residual)-numel(fitpar); % number of degrees of freedom
                perc = tinv(1-alpha/2,v);
                ci= perc*std(samples(1:spacing:end,:)); m_mc = mean(samples(1:spacing:end,:));
            end
            %%% Sort confidence intervals back to fitparameters
            err(:,PDAMeta.Global)=repmat(ci(1:sum(PDAMeta.Global)),[size(PDAMeta.FitParams,1) 1]) ;
            ci(1:sum(PDAMeta.Global))=[];
            if UserValues.PDA.HalfGlobal
                err(PDAMeta.SecondHalf:end,PDAMeta.HalfGlobal)=repmat(ci(1:sum(PDAMeta.HalfGlobal)),[(size(PDAMeta.FitParams,1)-PDAMeta.SecondHalf+1) 1]) ;
                ci(1:sum(PDAMeta.HalfGlobal))=[];
            end

            for i=find(PDAMeta.Active)'
                err(i, ~PDAMeta.Fixed(i,:) & ~PDAMeta.Global) = ci(1:sum(~PDAMeta.Fixed(i,:) & ~PDAMeta.Global));
                ci(1:sum(~PDAMeta.Fixed(i,:)& ~PDAMeta.Global))=[];
            end
            PDAMeta.ConfInt_MCMC = err;
            if obj == h.Menu.EstimateErrorMCMC
                %%% Sort MCMC_mean value back to fit parameters
                MCMC_mean(:,PDAMeta.Global)=repmat(m_mc(1:sum(PDAMeta.Global)),[size(PDAMeta.FitParams,1) 1]) ;
                m_mc(1:sum(PDAMeta.Global))=[];
                if UserValues.PDA.HalfGlobal
                    MCMC_mean(PDAMeta.SecondHalf:end,PDAMeta.HalfGlobal)=repmat(m_mc(1:sum(PDAMeta.HalfGlobal)),[(size(PDAMeta.FitParams,1)-PDAMeta.SecondHalf+1) 1]) ;
                    m_mc(1:sum(PDAMeta.HalfGlobal))=[];
                end

                for i=find(PDAMeta.Active)'
                    MCMC_mean(i, ~PDAMeta.Fixed(i,:) & ~PDAMeta.Global) = m_mc(1:sum(~PDAMeta.Fixed(i,:) & ~PDAMeta.Global));
                    m_mc(1:sum(~PDAMeta.Fixed(i,:)& ~PDAMeta.Global))=[];
                end
                MCMC_mean(MCMC_mean == 0) = PDAMeta.FitParams(MCMC_mean == 0);
                PDAMeta.MCMC_mean = MCMC_mean;
            end
            PDAMeta.FitInProgress = 0; % disable fit
    end
end
% make confidence intervals available in base workspace
if any(obj == [h.Menu.EstimateErrorHessian,h.Menu.EstimateErrorMCMC])
    assignin('base','ConfInt_Jac',PDAMeta.ConfInt_Jac);
    if obj == h.Menu.EstimateErrorMCMC
        assignin('base','ConfInt_MCMC',PDAMeta.ConfInt_MCMC);
        assignin('base','MCMC_mean',PDAMeta.MCMC_mean);
    end
end
    
Progress(1, h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Done');
Progress(1, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Done');
Update_Plots([],[],1)
%%% re-enable Fit Menu
h.FitTab.Table.Enable='on';
PDAMeta.FitInProgress = 0;

% File menu - stop fitting
function Stop_PDA_Fit(~,~)
global PDAMeta
h = guidata(findobj('Tag','GlobalPDAFit'));
PDAMeta.FitInProgress = 0;
h.FitTab.Table.Enable='on';

% model for normal histogram library fitting (not global)
function [chi2] = PDAHistogramFit_Single(fitpar,h)
global PDAMeta PDAData
%h = guidata(findobj('Tag','GlobalPDAFit'));
i = PDAMeta.file;

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    chi2 = 0;
    return;
end

if PDAMeta.FitInProgress == 2 %%% we are estimating errors based on hessian, so input parameters are only the non-fixed parameters
    % only the non-fixed parameters are passed, reconstruct total fitpar
    % array from dummy data
    if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
        %%% add sigma fraction to end
        fitpar_dummy = [PDAMeta.FitParams(i,:), str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String)];
        fixed = [PDAMeta.Fixed(i,:), h.SettingsTab.FixSigmaAtFractionOfR_Fix.Value];
        fitpar_dummy(~fixed) = fitpar;
    else
        fitpar_dummy = PDAMeta.FitParams(i,:);
        fitpar_dummy(~PDAMeta.Fixed(i,:)) = fitpar;
    end
    fitpar = fitpar_dummy;
end
%%% if sigma is fixed at fraction of, change its value here, and remove the
%%% amplitude fit parameter so it does not mess up further uses of fitpar
if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
    fraction = fitpar(end); fitpar(end) = [];
    fitpar(3:3:end) = fraction.*fitpar(2:3:end);
end

%%% create individual histograms
hFit_Ind = cell(5,1);
if ~h.SettingsTab.DynamicModel.Value %%% no dynamic model
    %%% do not normalize Amplitudes; user can do this himself if he wants
    % fitpar(3*PDAMeta.Comp{i}-2) = fitpar(3*PDAMeta.Comp{i}-2)./sum(fitpar(3*PDAMeta.Comp{i}-2));
    
    for c = PDAMeta.Comp{i}
        if h.SettingsTab.Use_Brightness_Corr.Value
            %%% If brightness correction is to be performed, determine the relative
            %%% brightness based on current distance and correction factors
            Qr = calc_relative_brightness(fitpar(3*c-1),i);
            %%% Rescale the PN;
            PN_scaled = scalePN(PDAData.BrightnessReference.PN,Qr);
            %%% fit PN_scaled to match PN of file
            PN_scaled = PN_scaled(1:numel(PDAMeta.PN{i}));
            PN_scaled = PN_scaled./sum(PN_scaled).*sum(PDAMeta.PN{i});
            %%% Recalculate the P array of this file
            PDAMeta.P(i,:) = recalculate_P(PN_scaled,i,str2double(h.SettingsTab.NumberOfBins_Edit.String),str2double(h.SettingsTab.NumberOfBinsE_Edit.String));
        end
        
        [Pe] = Generate_P_of_eps(fitpar(3*c-1), fitpar(3*c), i); %Pe is area-normalized
        P_eps = fitpar(3*c-2).*Pe;
        hFit_Ind{c} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
        for k = 1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
            hFit_Ind{c} = hFit_Ind{c} + P_eps(k).*PDAMeta.P{i,k};
        end
    end
    %%% Combine histograms
    hFit = sum(horzcat(hFit_Ind{:}),2)';
else %%% dynamic model
    %%% calculate PofT
    dT = PDAData.timebin(i)*1E3; % time bin in milliseconds
    N = 100;
    k1 = fitpar(3*1-2);
    k2 = fitpar(3*2-2);
    PofT = calc_dynamic_distribution(dT,N,k1,k2);
    %%% generate P(eps) distribution for both components
    PE = cell(2,1);
    for c = 1:2
        PE{c} = Generate_P_of_eps(fitpar(3*c-1), fitpar(3*c), i);
    end
    %%% read out brightnesses of species
    Q = ones(2,1);
    %if h.SettingsTab.Use_Brightness_Corr.Value
        for c = 1:2
            Q(c) = calc_relative_brightness(fitpar(3*c-1),i);
        end
    %end
    %%% calculate mixtures with brightness correction (always active!)
    Peps = mixPE_c(PDAMeta.eps_grid{i},PE{1},PE{2},PofT,numel(PofT),numel(PDAMeta.eps_grid{i}),Q(1),Q(2));
    Peps = reshape(Peps,numel(PDAMeta.eps_grid{i}),numel(PofT));
    %%% for some reason Peps becomes "ripply" at the extremes... Correct by replacing with ideal distributions
    Peps(:,end) = PE{1};
    Peps(:,1) = PE{2};
    %%% normalize
    Peps = Peps./repmat(sum(Peps,1),size(Peps,1),1);
    %%% combine mixtures, weighted with PofT (probability to see a certain
    %%% combination)
    hFit_Ind_dyn = cell(numel(PofT),1);
    for t = 1:numel(PofT)
        hFit_Ind_dyn{t} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
        for k =1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
            %%% construct sum of histograms
            hFit_Ind_dyn{t} = hFit_Ind_dyn{t} + Peps(k,t).*PDAMeta.P{i,k};
        end
        %%% weight by probability of occurence
        hFit_Ind_dyn{t} = PofT(t)*hFit_Ind_dyn{t};
    end
    hFit_Ind{1} = hFit_Ind_dyn{1};
    hFit_Ind{2} = hFit_Ind_dyn{end};
    hFit_Dyn = sum(horzcat(hFit_Ind_dyn{:}),2);
    %%% Add static models
    if numel(PDAMeta.Comp{i}) > 2
        %%% normalize Amplitudes
        % amplitudes of the static components are normalized to the total area 
        % 'norm' = area3 + area4 + area5 + k21/(k12+k21) + k12/(k12+k21) 
        % the k12 and k21 parameters are left untouched here so they will 
        % appear in the table. The area fractions are calculated in Update_Plots
        norm = (sum(fitpar(3*PDAMeta.Comp{i}(3:end)-2))+1);
        fitpar(3*PDAMeta.Comp{i}(3:end)-2) = fitpar(3*PDAMeta.Comp{i}(3:end)-2)./norm;
        
        for c = PDAMeta.Comp{i}(3:end)
            [Pe] = Generate_P_of_eps(fitpar(3*c-1), fitpar(3*c), i);
            P_eps = fitpar(3*c-2).*Pe;
            hFit_Ind{c} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
            for k = 1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
                hFit_Ind{c} = hFit_Ind{c} + P_eps(k).*PDAMeta.P{i,k};
            end
        end
        hFit_Dyn = hFit_Dyn./norm;
        hFit_Ind{1} = hFit_Ind{1}./norm;
        hFit_Ind{2} = hFit_Ind{2}./norm;
    end
    hFit = sum(horzcat(hFit_Dyn,horzcat(hFit_Ind{3:end})),2)';
    
    % the whole dynamic part
    %PDAMeta.hFit_onlyDyn{i} = hFit_Dyn;
    % only the dynamic bursts
    PDAMeta.hFit_onlyDyn{i} = sum(horzcat(hFit_Ind_dyn{2:end-1}),2);
end


if fitpar(end) > 0
    %%% Add donor only species
    PDAMeta.hFit_Donly{i} = fitpar(end)*PDAMeta.P_donly{i}';
    % the sum of areas will > 1 this way?
    hFit = (1-fitpar(end))*hFit + fitpar(end)*PDAMeta.P_donly{i}';
    for k = 1:numel(hFit_Ind)
        hFit_Ind{k} = hFit_Ind{k}*(1-fitpar(end));
    end
end

%%% correct for slight number deviations between hFit and hMeasured
%hFit = (hFit./sum(hFit)).*sum(PDAMeta.hProx{i});

%%% Calculate Chi2
switch h.SettingsTab.Chi2Method_Popupmenu.Value
    case 2 %%% Assume gaussian error on data, normal chi2
        error = sqrt(PDAMeta.hProx{i});
        error(error == 0) = 1;
        w_res = (PDAMeta.hProx{i}-hFit)./error;
    case 1 %%% Assume poissonian error on data, MLE poissonian
        %%%% see:
        %%% Laurence, T. A. & Chromy, B. A. Efficient maximum likelihood estimator fitting of histograms. Nat Meth 7, 338?339 (2010).
        log_term = -2*PDAMeta.hProx{i}.*log(hFit./PDAMeta.hProx{i});
        log_term(isnan(log_term)) = 0;
        dev_mle = 2*(hFit-PDAMeta.hProx{i})+log_term;
        w_res = sign(hFit-PDAMeta.hProx{i}).*sqrt(dev_mle);
end
usedBins = sum(PDAMeta.hProx{i} ~= 0);
if ~h.SettingsTab.OuterBins_Fix.Value
    chi2 = sum((w_res.^2))/(usedBins-sum(~PDAMeta.Fixed(i,:))-1);
else
    chi2 = sum(((w_res(2:end-1)).^2))/(usedBins-sum(~PDAMeta.Fixed(i,:))-1);
    w_res(1) = 0;
    w_res(end) = 0;
end
        
PDAMeta.w_res{i} = w_res;
PDAMeta.hFit{i} = hFit;
PDAMeta.chi2(i) = chi2;
for c = PDAMeta.Comp{i}
    PDAMeta.hFit_Ind{i,c} = hFit_Ind{c};
end
set(PDAMeta.Chi2_All, 'Visible','on','String', ['\chi^2_{red.} = ' sprintf('%1.2f',chi2)]);
set(PDAMeta.Chi2_Single, 'Visible', 'on','String', ['\chi^2_{red.} = ' sprintf('%1.2f',chi2)]);

if h.SettingsTab.LiveUpdate.Value
    Update_Plots([],[],5)
end
tex = ['Fitting Histogram ' num2str(i) ' of ' num2str(sum(PDAMeta.Active))];

if PDAMeta.FitInProgress == 2 %%% return the residuals instead of chi2
    chi2 = w_res;
elseif PDAMeta.FitInProgress == 3 %%% return the loglikelihood
    switch h.SettingsTab.Chi2Method_Popupmenu.Value
        case 2 %%% Assume gaussian error on data, normal chi2
            loglikelihood = (-1/2)*sum(w_res.^2); %%% loglikelihood is the negative of chi2 divided by two
        case 1 %%% Assume poissonian error on data, MLE poissonian
            %%% compute loglikelihood without normalization to P(x|x)
            log_term = PDAMeta.hProx{i}.*log(hFit);log_term(isnan(log_term)) = 0;
            loglikelihood = sum(log_term-hFit);
    end
    chi2 = loglikelihood;
end
%Progress(1/chi2, h.AllTab.Progress.Axes, h.AllTab.Progress.Text, tex);
%Progress(1/chi2, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text, tex);

% model for normal histogram library fitting (global)
function [mean_chi2] = PDAHistogramFit_Global(fitpar,h)
global PDAMeta PDAData UserValues

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    mean_chi2 = 0;
    return;
end

FitParams = PDAMeta.FitParams;
Global = PDAMeta.Global;
Fixed = PDAMeta.Fixed;

P=zeros(numel(Global),1);

%%% Assigns global parameters
P(Global)=fitpar(1:sum(Global));
fitpar(1:sum(Global))=[];
    
for j=1:sum(PDAMeta.Active)
    Active = find(PDAMeta.Active)';
    i = Active(j);
    PDAMeta.file = i;
    if UserValues.PDA.HalfGlobal
        if j == PDAMeta.SecondHalf
            P(PDAMeta.HalfGlobal)=fitpar(1:sum(PDAMeta.HalfGlobal));
            fitpar(1:sum(PDAMeta.HalfGlobal))=[];
        end
    end
    %%% Sets non-fixed parameters
    P(~Fixed(i,:) & ~Global)=fitpar(1:sum(~Fixed(i,:) & ~Global));
    fitpar(1:sum(~Fixed(i,:)& ~Global))=[];
    %%% Sets fixed parameters
    P(Fixed(i,:) & ~Global) = FitParams(i, (Fixed(i,:) & ~Global));
    %%% Calculates function for current file
    
    %%% if sigma is fixed at fraction of, change its value here
    if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
        P(3:3:end) = P(end).*P(2:3:end-1);
        fraction_Donly = P(end-1);
    else
        fraction_Donly = P(end);
    end

    %%% create individual histograms
    hFit_Ind = cell(5,1);
    if ~h.SettingsTab.DynamicModel.Value %%% no dynamic model
        %%% do not normalize Amplitudes, user can do this himself if he
        %%% wants
        %P(3*PDAMeta.Comp{i}-2) = P(3*PDAMeta.Comp{i}-2)./sum(P(3*PDAMeta.Comp{i}-2));
        
        for c = PDAMeta.Comp{i}
            [Pe] = Generate_P_of_eps(P(3*c-1), P(3*c), i);
            P_eps = P(3*c-2).*Pe;
            hFit_Ind{c} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
            for k = 1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
                hFit_Ind{c} = hFit_Ind{c} + P_eps(k).*PDAMeta.P{i,k};
            end
        end
        hFit = sum(horzcat(hFit_Ind{:}),2)';
    else % dynamic model
        %%% calculate PofT
        dT = PDAData.timebin(i)*1E3; % time bin in milliseconds
        N = 100;
        k1 = P(3*1-2);
        k2 = P(3*2-2);
        PofT = calc_dynamic_distribution(dT,N,k1,k2);
        %%% generate P(eps) distribution for both components
        PE = cell(2,1);
        for c = 1:2
            PE{c} = Generate_P_of_eps(P(3*c-1), P(3*c), i);
        end
        %%% read out brightnesses of species
        Q = ones(2,1);
        %if h.SettingsTab.Use_Brightness_Corr.Value
            for c = 1:2
                Q(c) = calc_relative_brightness(P(3*c-1),i);
            end
        %end
        %%% calculate mixtures with brightness correction (always active!)
        Peps = mixPE_c(PDAMeta.eps_grid{i},PE{1},PE{2},PofT,numel(PofT),numel(PDAMeta.eps_grid{i}),Q(1),Q(2));
        Peps = reshape(Peps,numel(PDAMeta.eps_grid{i}),numel(PofT));
        %%% for some reason Peps becomes "ripply" at the extremes... Correct by replacing with ideal distributions
        Peps(:,end) = PE{1};
        Peps(:,1) = PE{2};
        %%% normalize
        Peps = Peps./repmat(sum(Peps,1),size(Peps,1),1);
        %%% combine mixtures, weighted with PofT (probability to see a certain
        %%% combination)
        hFit_Ind_dyn = cell(numel(PofT),1);
        for t = 1:numel(PofT)
            hFit_Ind_dyn{t} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
            for k =1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
                %%% construct sum of histograms
                hFit_Ind_dyn{t} = hFit_Ind_dyn{t} + Peps(k,t).*PDAMeta.P{i,k};
            end
            %%% weight by probability of occurence
            hFit_Ind_dyn{t} = PofT(t)*hFit_Ind_dyn{t};
        end
        % bursts that did not leave state 1 during the burst: to indicate
        % where state 1 is in the Epr plot
        hFit_Ind{1} = hFit_Ind_dyn{1};
        % bursts that did not leave state 2 during the burst: to indicate
        % where state 2 is in the Epr plot
        hFit_Ind{2} = hFit_Ind_dyn{end};
        
        hFit_Dyn = sum(horzcat(hFit_Ind_dyn{:}),2);
        %%% Add static models
        if numel(PDAMeta.Comp{i}) > 2
            %%% normalize Amplitudes
            % amplitudes of the static components are normalized to the total area
            % 'norm' = area3 + area4 + area5 + k21/(k12+k21) + k12/(k12+k21)
            % the k12 and k21 parameters are left untouched here so they will
            % appear in the table. The area fractions are calculated in Update_Plots
            norm = (sum(P(3*PDAMeta.Comp{i}(3:end)-2))+1);
            P(3*PDAMeta.Comp{i}(3:end)-2) = P(3*PDAMeta.Comp{i}(3:end)-2)./norm;
            for c = PDAMeta.Comp{i}(3:end)
                [Pe] = Generate_P_of_eps(P(3*c-1), P(3*c), i); %Pe is area-normalized
                P_eps = P(3*c-2).*Pe;
                hFit_Ind{c} = zeros(str2double(h.SettingsTab.NumberOfBins_Edit.String),1);
                for k = 1:str2double(h.SettingsTab.NumberOfBinsE_Edit.String)+1
                    hFit_Ind{c} = hFit_Ind{c} + P_eps(k).*PDAMeta.P{i,k};
                end
            end
            hFit_Dyn = hFit_Dyn./norm;
        end
        % sum the static and dynamic components
        hFit = sum(horzcat(hFit_Dyn,horzcat(hFit_Ind{3:end})),2)';
        
        % the whole dynamic part
        %PDAMeta.hFit_onlyDyn{i} = hFit_Dyn;
        % only the dynamic bursts
        PDAMeta.hFit_onlyDyn{i} = sum(horzcat(hFit_Ind_dyn{2:end-1}),2);
    end

    if fraction_Donly > 0
        %%% Add donor only species
        PDAMeta.hFit_Donly = fraction_Donly*PDAMeta.P_donly{i}';
        hFit = (1-fraction_Donly)*hFit + fraction_Donly*PDAMeta.P_donly{i}';
        for k = 1:numel(hFit_Ind)
            hFit_Ind{k} = hFit_Ind{k}*(1-fraction_Donly);
        end
    end

    %%% correct for slight number deviations between hFit and hMeasured
%     for c = PDAMeta.Comp{i}
%         hFit_Ind{c} = hFit_Ind{c}./sum(hFit).*sum(PDAMeta.hProx{i});
%     end
%     hFit = (hFit./sum(hFit)).*sum(PDAMeta.hProx{i});
    
    
    %%% Calculate Chi2
    switch h.SettingsTab.Chi2Method_Popupmenu.Value
        case 2 %%% Assume gaussian error on data, normal chi2
            error = sqrt(PDAMeta.hProx{i});
            error(error == 0) = 1;
            PDAMeta.w_res{i} = (hFit-PDAMeta.hProx{i})./error;
            if PDAMeta.FitInProgress == 3 %%% return the correct loglikelihood instead
                loglikelihood(i) = (-1/2)*sum(PDAMeta.w_res{i}.^2); %%% loglikelihood is the negative of chi2 divided by two
            end
        case 1 %%% Assume poissonian error on data, MLE poissonian
            %%%% see:
            %%% Laurence, T. A. & Chromy, B. A. Efficient maximum likelihood estimator fitting of histograms. Nat Meth 7, 338?339 (2010).
            log_term = -2*PDAMeta.hProx{i}.*log(hFit./PDAMeta.hProx{i});
            log_term(isnan(log_term)) = 0;
            dev_mle = 2*(hFit-PDAMeta.hProx{i})+log_term;
            PDAMeta.w_res{i} = sign(hFit-PDAMeta.hProx{i}).*sqrt(dev_mle);
            if PDAMeta.FitInProgress == 3 %%% return the correct loglikelihood instead
                %%% compute loglikelihood without normalization to P(x|x)
                log_term = PDAMeta.hProx{i}.*log(hFit);log_term(isnan(log_term)) = 0;
                loglikelihood(i) = sum(log_term-hFit);
            end
    end   
    PDAMeta.hFit{i} = hFit;
    usedBins = sum(PDAMeta.hProx{i} ~= 0);
    if ~h.SettingsTab.OuterBins_Fix.Value
        PDAMeta.chi2(i) = sum(((PDAMeta.w_res{i}).^2))/(usedBins-sum(~Fixed(i,:))-1);
    else
        % disregard last bins
        PDAMeta.chi2(i) = sum(((PDAMeta.w_res{i}(2:end-1)).^2))/(usedBins-sum(~Fixed(i,:))-3);
        PDAMeta.w_res{i}(1) = 0;
        PDAMeta.w_res{i}(end) = 0;
    end
    if j == h.SingleTab.Popup.Value
        set(PDAMeta.Chi2_Single, 'Visible', 'on','String', ['\chi^2_{red.} = ' sprintf('%1.2f',PDAMeta.chi2(i))]);
    end
    for c = PDAMeta.Comp{i}
        PDAMeta.hFit_Ind{i,c} = hFit_Ind{c};
    end
    if h.SettingsTab.LiveUpdate.Value
        Update_Plots([],[],5)
    end 
end
mean_chi2 = mean(PDAMeta.chi2);
%Progress(1/mean_chi2, h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Fitting Histograms...');
%Progress(1/mean_chi2, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Fitting Histograms...');
set(PDAMeta.Chi2_All, 'Visible','on','String', ['avg. \chi^2_{red.} = ' sprintf('%1.2f',mean_chi2)]);
if PDAMeta.FitInProgress == 2 %%% return concatenated array of w_res instead of chi2
    mean_chi2 = horzcat(PDAMeta.w_res{:});
elseif PDAMeta.FitInProgress == 3 %%% return the correct loglikelihood instead
    mean_chi2 = sum(loglikelihood);
end

% function that generates Equation 10 from Antonik 2006 J Phys Chem B
function [Pe] = Generate_P_of_eps(RDA, sigma, i)
global PDAMeta
eps = PDAMeta.eps_grid{i};
if PDAMeta.directexc(i) == 0
    % generate gaussian distributions of PDA.epsilon weights
    % Eq 10 in Antonik 2006 c Phys Chem B
    Pe = PDAMeta.R0(i)/(6*sqrt(2*pi)*sigma)*...
        (PDAMeta.gamma(i))^(1/6)*...
        1./(1-eps).^2 .* ...
        (1./(1-eps) - (1+PDAMeta.crosstalk(i))).^(-7/6) .* ...
        exp(...
        -1/(2*sigma^2)*...
        (PDAMeta.R0(i).*...
        (PDAMeta.gamma(i))^(1/6).*...
        (1./(1-eps)-(1+PDAMeta.crosstalk(i))).^(-1/6)- ...
        RDA).^2);
elseif PDAMeta.directexc(i) ~= 0
    old = 0;
    if old
        dRdeps = -((PDAMeta.R0(i)^6*PDAMeta.gamma(i))./(PDAMeta.crosstalk(i)...
            - eps - PDAMeta.crosstalk(i)*PDAMeta.directexc(i) - PDAMeta.crosstalk(i)*eps...
            + PDAMeta.directexc(i)*eps + PDAMeta.directexc(i)*PDAMeta.gamma(i)...
            + PDAMeta.crosstalk(i)*PDAMeta.directexc(i)*eps - PDAMeta.directexc(i)*eps*PDAMeta.gamma(i))...
            - ((PDAMeta.R0(i)^6*PDAMeta.gamma(i) - PDAMeta.R0(i)^6*eps*PDAMeta.gamma(i))*(PDAMeta.crosstalk(i)...
            - PDAMeta.directexc(i) - PDAMeta.crosstalk(i)*PDAMeta.directexc(i) + PDAMeta.directexc(i)*PDAMeta.gamma(i) + 1))./...
            (PDAMeta.crosstalk(i) - eps - PDAMeta.crosstalk(i)*PDAMeta.directexc(i)...
            - PDAMeta.crosstalk(i)*eps + PDAMeta.directexc(i)*eps + PDAMeta.directexc(i)*PDAMeta.gamma(i)...
            + PDAMeta.crosstalk(i)*PDAMeta.directexc(i)*eps - PDAMeta.directexc(i)*eps*PDAMeta.gamma(i)).^2)./...
            (6*(-(PDAMeta.R0(i)^6*PDAMeta.gamma(i) - PDAMeta.R0(i)^6*eps*PDAMeta.gamma(i))./(PDAMeta.crosstalk(i)...
            - eps - PDAMeta.crosstalk(i)*PDAMeta.directexc(i) - PDAMeta.crosstalk(i)*eps + PDAMeta.directexc(i)*eps...
            + PDAMeta.directexc(i)*PDAMeta.gamma(i) + PDAMeta.crosstalk(i)*PDAMeta.directexc(i)*eps -...
            PDAMeta.directexc(i)*eps*PDAMeta.gamma(i))).^(5/6));
        P_Rofeps = (1/(sqrt(2*pi)*sigma)).*...
            exp(-(RDA - (-(PDAMeta.R0(i)^6*PDAMeta.gamma(i) - PDAMeta.R0(i)^6*eps*PDAMeta.gamma(i))./...
            (PDAMeta.crosstalk(i) - eps - PDAMeta.crosstalk(i)*PDAMeta.directexc(i) - PDAMeta.crosstalk(i)*eps...
            + PDAMeta.directexc(i)*eps + PDAMeta.directexc(i)*PDAMeta.gamma(i) +...
            PDAMeta.crosstalk(i)*PDAMeta.directexc(i)*eps - PDAMeta.directexc(i)*eps*PDAMeta.gamma(i))).^(1/6)).^2./(2*sigma^2));
        Pe = dRdeps.*P_Rofeps;
    else
        %%% redone formula derivation by hand, easier to read
        R0 = PDAMeta.R0(i);
        d = PDAMeta.directexc(i)/(1-PDAMeta.directexc(i));
        ct = PDAMeta.crosstalk(i);
        gamma = PDAMeta.gamma(i);
        epsilon = eps;
        Rofeps = R0*( (gamma*(1+d)) ./ ( (1./(1-epsilon)) -1 -ct -gamma*d) ).^(1/6);
        dRdeps = (R0/6)*...
            ( (gamma*(1+d)) ./ ( (1./(1-epsilon)) -1 -ct -gamma*d) ).^(-5/6).*...
            gamma.*(1+d).*...
            ( (1./(1-epsilon)) -1 -ct -gamma*d).^(-2).*...
            (1-epsilon).^(-2);
        dRdeps(1) = 0;
        PRofeps = (1/(sqrt(2*pi)*sigma))*...
            exp((-1/(2*sigma^2)).*...
            (Rofeps-RDA).^2);
        Pe = dRdeps.*PRofeps;
    end
end
Pe(~isfinite(Pe)) = 0;
Pe = Pe./sum(Pe); %area-normalized Pe

% model for MLE fitting (not global)
function logL = PDA_MLE_Fit_Single(fitpar,h)
global PDAMeta PDAData

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    logL = 0;
    return;
end

file = PDAMeta.file;
if PDAMeta.FitInProgress == 2 %%% we are estimating errors based on hessian, so input parameters are only the non-fixed parameters
    % only the non-fixed parameters are passed, reconstruct total fitpar
    % array from dummy data
    fitpar_dummy = PDAMeta.FitParams(file,:);
    fitpar_dummy(~PDAMeta.Fixed(file,:)) = fitpar;
    fitpar = fitpar_dummy;
end
%%% if sigma is fixed at fraction of, read value here before reshape
if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
    fraction = fitpar(end);fitpar(end) = [];
end
%%% remove donor only fraction, not implemented here
fitpar= fitpar(1:end-1);
fitpar = reshape(fitpar',[3,numel(fitpar)/3]); fitpar = fitpar';
%%% if sigma is fixed at fraction of, change its value here
if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
    fitpar(:,3) = fraction.*fitpar(:,2);
end

% Parameters
cr = PDAMeta.crosstalk(file);
R0 = PDAMeta.R0(file);
de = PDAMeta.directexc(file);
gamma = PDAMeta.gamma(file);

if h.SettingsTab.Use_Brightness_Corr.Value
        %%% If brightness correction is to be performed, determine the relative
        %%% brightness based on current distance and correction factors
        PN_scaled = cell(5,1);
        for c = PDAMeta.Comp{file}
            Qr = calc_relative_brightness(fitpar(c,2),file);
            %%% Rescale the PN;
            PN_scaled{c} = scalePN(PDAData.BrightnessReference.PN,Qr);
            PN_scaled{c} = smooth(PN_scaled{c},10);
            PN_scaled{c} = PN_scaled{c}./sum(PN_scaled{c});
        end
        %%% calculate the relative probabilty
        P_norm = sum(horzcat(PN_scaled{:}),2);
        for c = PDAMeta.Comp{file}
            PN_scaled{c}(P_norm~=0) = PN_scaled{c}(P_norm~=0)./P_norm(P_norm~=0);
            %%% We don't want zero probabilities here!
            PN_scaled{c}(PN_scaled{c} == 0) = eps;
        end
end
    
NG = PDAData.Data{file}.NG(PDAMeta.valid{file});
NF = PDAData.Data{file}.NF(PDAMeta.valid{file});

steps = 10;
n_sigma = 3; %%% how many sigma to sample distribution width?
L = cell(5,1); %%% Likelihood per Gauss
for j = PDAMeta.Comp{file}
    %%% define Gaussian distribution of distances
    xR = (fitpar(j,2)-n_sigma*fitpar(j,3)):(2*n_sigma*fitpar(j,3)/steps):(fitpar(j,2)+n_sigma*fitpar(j,3));
    PR = normpdf(xR,fitpar(j,2),fitpar(j,3));
    PR = PR'./sum(PR);
    %%% Calculate E values for R grid
    E = 1./(1+(xR./R0).^6);
    epsGR = 1-(1+cr+(((de/(1-de)) + E) * gamma)./(1-E)).^(-1);
    
    %%% Calculate the vector of likelihood values
    P = eval_prob_2c_bg(NG,NF,...
        PDAMeta.NBG{file},PDAMeta.NBR{file},...
        PDAMeta.PBG{file}',PDAMeta.PBR{file}',...
        epsGR');
    P = log(P) + repmat(log(PR'),numel(NG),1);
    Lmax = max(P,[],2);
    P = Lmax + log(sum(exp(P-repmat(Lmax,1,numel(PR))),2));
    
    if h.SettingsTab.Use_Brightness_Corr.Value
        %%% Add Brightness Correction Probabilty here
        P = P + log(PN_scaled{j}(NG + NF));
    end
    %%% Treat case when all burst produced zero probability
    P(isnan(P)) = -Inf;
    L{j} = P;
end

%%% normalize amplitudes
fitpar(PDAMeta.Comp{file},1) = fitpar(PDAMeta.Comp{file},1)./sum(fitpar(PDAMeta.Comp{file},1));
PA = fitpar(PDAMeta.Comp{file},1);


L = horzcat(L{:});
L = L + repmat(log(PA'),numel(NG),1);
Lmax = max(L,[],2);
L = Lmax + log(sum(exp(L-repmat(Lmax,1,numel(PA))),2));
%%% P_res has NaN values if Lmax was -Inf (i.e. total of zero probability)!
%%% Reset these values to -Inf
L(isnan(L)) = -Inf;
logL = sum(L);
%%% since the algorithm minimizes, it is important to minimize the negative
%%% log likelihood, i.e. maximize the likelihood
logL = -logL;

% model for MLE fitting (global)
function [mean_logL] = PDAMLEFit_Global(fitpar,h)
global PDAMeta

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    mean_logL = 0;
    return;
end


FitParams = PDAMeta.FitParams;
Global = PDAMeta.Global;
Fixed = PDAMeta.Fixed;

P=zeros(numel(Global),1);

%%% Assigns global parameters
P(Global)=fitpar(1:sum(Global));
fitpar(1:sum(Global))=[];

for i=find(PDAMeta.Active)'
    PDAMeta.file = i;
    %%% Sets non-fixed parameters
    P(~Fixed(i,:) & ~Global)=fitpar(1:sum(~Fixed(i,:) & ~Global));
    fitpar(1:sum(~Fixed(i,:)& ~Global))=[];
    %%% Sets fixed parameters
    P(Fixed(i,:) & ~Global) = FitParams(i, (Fixed(i,:) & ~Global));
    
    %%% normalize Amplitudes
    P(3*PDAMeta.Comp{i}-2) = P(3*PDAMeta.Comp{i}-2)./sum(P(1:3:end));
    
    %%% calculate individual likelihoods
    PDAMeta.chi2(i) = PDA_MLE_Fit_Single(P,h);   
end
mean_logL = mean(PDAMeta.chi2);

%%% if second iteration or more, update Progress Bar
if isfield(PDAMeta,'Last_logL')
    progress = exp(mean_logL-PDAMeta.Last_logL);
    if progress > 1
        progress = 0.99;
    end
    Progress(progress, h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Fitting Histograms...');
    Progress(progress, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Fitting Histograms...');
end
set(PDAMeta.Chi2_All, 'Visible','on','String', ['avg. logL = ' sprintf('%1.2f',mean_logL)]);
%%% store logL in PDAMeta
PDAMeta.Last_logL = mean_logL;

% Model for Monte Carle based fitting (not global) 
function [chi2] = PDAMonteCarloFit_Single(fitpar)
global PDAMeta PDAData
h = guidata(findobj('Tag','GlobalPDAFit'));

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    if ~strcmp(h.SettingsTab.PDAMethod_Popupmenu.String{h.SettingsTab.PDAMethod_Popupmenu.Value},'MLE')
        chi2 = 0;
        return;
    end
    %%% else continue
end

file = PDAMeta.file;
if PDAMeta.FitInProgress == 2 %%% we are estimating errors based on hessian, so input parameters are only the non-fixed parameters
    % only the non-fixed parameters are passed, reconstruct total fitpar
    % array from dummy data
    fitpar_dummy = PDAMeta.FitParams(file,:);
    fitpar_dummy(~PDAMeta.Fixed(file,:)) = fitpar;
    fitpar = fitpar_dummy;
end
%%% if sigma is fixed at fraction of, read value here before reshape
if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
    fraction = fitpar(end);fitpar(end) = [];
end
%%% remove donor only fraction, not implemented here
fitpar= fitpar(1:end-1);
%%% fitpar vector is linearized by fminsearch, restructure
fitpar = reshape(fitpar',[3,numel(fitpar)/3]); fitpar = fitpar';

%%% normalize Amplitudes
fitpar(PDAMeta.Comp{file},1) = fitpar(PDAMeta.Comp{file},1)./sum(fitpar(PDAMeta.Comp{file},1));
A = fitpar(:,1);

%%% if sigma is fixed at fraction of, change its value here
if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1
    fitpar(:,3) = fraction.*fitpar(:,2);
end

%Parameters
mBG_gg = PDAMeta.BGdonor(file);
mBG_gr = PDAMeta.BGacc(file);
dur = PDAData.timebin(file)*1E3;
cr = PDAMeta.crosstalk(file);
R0 = PDAMeta.R0(file);
de = PDAMeta.directexc(file);
gamma = PDAMeta.gamma(file);
Nobins = str2double(h.SettingsTab.NumberOfBins_Edit.String);
sampling =str2double(h.SettingsTab.OverSampling_Edit.String);

if h.SettingsTab.Use_Brightness_Corr.Value
        %%% If brightness correction is to be performed, determine the relative
        %%% brightness based on current distance and correction factors
        BSD_scaled = cell(5,1);
        for c = PDAMeta.Comp{file}
            Qr = calc_relative_brightness(fitpar(c,2),file);
            %%% Rescale the PN;
            PN_scaled = scalePN(PDAData.BrightnessReference.PN,Qr);
            %%% fit PN_scaled to match PN of file
            PN_scaled = PN_scaled(1:numel(PDAMeta.PN{file}));
            PN_scaled = PN_scaled./sum(PN_scaled).*sum(PDAMeta.PN{file});
            
            PN_scaled = ceil(PN_scaled); % round to integer
            BSD_scaled{c} = zeros(sum(PN_scaled),1);
            count = 0;
            for i = 1:numel(PN_scaled)
                BSD_scaled{c}(count+1:count+PN_scaled(i)) = i;
                count = count+PN_scaled(i);
            end
            %%% BSD_scaled contains too many bursts now, remove randomly
            BSD_scaled{c} = BSD_scaled{c}(randperm(numel(BSD_scaled{c})));
            BSD_scaled{c} = BSD_scaled{c}(1:numel(PDAMeta.BSD{file}));
        end  
end

BSD = PDAMeta.BSD{file};

H_meas = PDAMeta.hProx{file}';
%pool = gcp;
%sampling = pool.NumWorkers;
PRH = cell(sampling,5);
for j = PDAMeta.Comp{file}
    if h.SettingsTab.Use_Brightness_Corr.Value
        BSD = BSD_scaled{j};
    end
    if size(BSD,2) > size(BSD,1)
        BSD = BSD';
    end
    for k = 1:sampling
        r = normrnd(fitpar(j,2),fitpar(j,3),numel(BSD),1);
        E = 1./(1+(r./R0).^6);
        eps = 1-(1+cr+(((de/(1-de)) + E) * gamma)./(1-E)).^(-1);
        BG_gg = poissrnd(mBG_gg.*dur,numel(BSD),1);
        BG_gr = poissrnd(mBG_gr.*dur,numel(BSD),1);
        BSD_bg = BSD-BG_gg-BG_gr;
        PRH{k,j} = (binornd(BSD_bg,eps)+BG_gr)./BSD;
    end
end
H_res_dummy = zeros(numel(PDAMeta.hProx{file}),5);
for j = PDAMeta.Comp{file}
    H_res_dummy(:,j) = histcounts(vertcat(PRH{:,j}),linspace(0,1,Nobins+1))./sampling;
end
hFit = zeros(numel(PDAMeta.hProx{file}),1);
for j = PDAMeta.Comp{file}
    hFit = hFit + A(j).*H_res_dummy(:,j);
end
    
%hFit = sum(H_meas)*hFit./sum(hFit);
%%% Calculate Chi2
switch h.SettingsTab.Chi2Method_Popupmenu.Value
    case 2 %%% Assume gaussian error on data, normal chi2
        error = sqrt(H_meas);
        error(error == 0) = 1;
        w_res = (H_meas-hFit)./error;
    case 1 %%% Assume poissonian error on data, MLE poissonian
        %%%% see:
        %%% Laurence, T. A. & Chromy, B. A. Efficient maximum likelihood estimator fitting of histograms. Nat Meth 7, 338?339 (2010).
        log_term = -2*H_meas.*log(hFit./H_meas);
        log_term(isnan(log_term)) = 0;
        log_term(~isfinite(log_term)) = 0;
        dev_mle = 2*(hFit-H_meas)+log_term;
        w_res = sign(hFit-H_meas).*sqrt(dev_mle);
end
usedBins = sum(H_meas ~= 0);
if ~h.SettingsTab.OuterBins_Fix.Value
    chi2 = sum((w_res.^2))/(usedBins-numel(fitpar)-1);
else
    % disregard outer bins
    chi2 = sum((w_res(2:end-1).^2))/(usedBins-numel(fitpar)-3);
    w_res(1) = 0;
    w_res(end) = 0;
end
hFit_Ind = cell(5,1);
for j = PDAMeta.Comp{file}
    hFit_Ind{j} = sum(H_meas).*A(j).*H_res_dummy(:,j)./sum(H_res_dummy(:,1));
end

PDAMeta.w_res{file} = w_res';
PDAMeta.hFit{file} = hFit';
PDAMeta.chi2(file) = chi2;
for c = PDAMeta.Comp{file};
    PDAMeta.hFit_Ind{file,c} = hFit_Ind{c};
end
set(PDAMeta.Chi2_All, 'Visible','on','String', ['\chi^2_{red.} = ' sprintf('%1.2f',chi2)]);
set(PDAMeta.Chi2_Single, 'Visible', 'on','String', ['\chi^2_{red.} = ' sprintf('%1.2f',chi2)]);

if h.SettingsTab.LiveUpdate.Value
    Update_Plots([],[],5)
end
tex = ['Fitting Histogram ' num2str(file) ' of ' num2str(sum(PDAMeta.Active))];
Progress(1/chi2, h.AllTab.Progress.Axes, h.AllTab.Progress.Text, tex);
Progress(1/chi2, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text, tex);

% Model for Monte Carle based fitting (global) 
function [mean_chi2] = PDAMonteCarloFit_Global(fitpar)
global PDAMeta
h = guidata(findobj('Tag','GlobalPDAFit'));

%%% Aborts Fit
drawnow;
if ~PDAMeta.FitInProgress
    mean_chi2 = 0;
    return;
end

FitParams = PDAMeta.FitParams;
Global = PDAMeta.Global;
Fixed = PDAMeta.Fixed;

P=zeros(numel(Global),1);

%%% Assigns global parameters
P(Global)=fitpar(1:sum(Global));
fitpar(1:sum(Global))=[];

for i=find(PDAMeta.Active)'
    PDAMeta.file = i;
    %%% Sets non-fixed parameters
    P(~Fixed(i,:) & ~Global)=fitpar(1:sum(~Fixed(i,:) & ~Global));
    fitpar(1:sum(~Fixed(i,:)& ~Global))=[];
    %%% Sets fixed parameters
    P(Fixed(i,:) & ~Global) = FitParams(i, (Fixed(i,:) & ~Global));
    %%% Calculates function for current file
    
    %%% normalize Amplitudes
    P(3*PDAMeta.Comp{i}-2) = P(3*PDAMeta.Comp{i}-2)./sum(P(1:3:end));

    %%% create individual histograms
    [PDAMeta.chi2(i)] = PDAMonteCarloFit_Single(P);
end
mean_chi2 = mean(PDAMeta.chi2);
Progress(1/mean_chi2, h.AllTab.Progress.Axes,h.AllTab.Progress.Text,'Fitting Histograms...');
Progress(1/mean_chi2, h.SingleTab.Progress.Axes,h.SingleTab.Progress.Text,'Fitting Histograms...');
set(PDAMeta.Chi2_All, 'Visible','on','String', ['avg. \chi^2_{red.} = ' sprintf('%1.2f',mean_chi2)]);

% Function to export the figures, figure data, and table data
function Export_Figure(~,~)
global PDAData UserValues PDAMeta
h = guidata(findobj('Tag','GlobalPDAFit'));

Path = uigetdir(fullfile(UserValues.File.PDAPath),...
    'Specify directory name');

if Path == 0
    return
else
    Path = GenerateName(fullfile(Path, [datestr(now,'yymmdd') ' GlobalPDAFit']),2);
    % All tab
    fig = figure('Position',[100 ,100 ,900, 425],...
        'Color',[1 1 1],...
        'Resize','off');
    main_ax = copyobj(h.AllTab.Main_Axes,fig);
    res_ax = copyobj(h.AllTab.Res_Axes,fig);
    gauss_ax = copyobj(h.AllTab.Gauss_Axes,fig);
    main_ax.Children(end).Position = [1.35,1.09];
    main_ax.Color = [1 1 1];
    res_ax.Color = [1 1 1];
    main_ax.XColor = [0 0 0];
    main_ax.YColor = [0 0 0];
    res_ax.XColor = [0 0 0];
    res_ax.YColor = [0 0 0];
    main_ax.XLabel.Color = [0 0 0];
    main_ax.YLabel.Color = [0 0 0];
    res_ax.XLabel.Color = [0 0 0];
    res_ax.YLabel.Color = [0 0 0];
    main_ax.Units = 'pixel';
    res_ax.Units = 'pixel';
    main_ax.Position = [75 70 475 290];
    res_ax.Position = [75 360 475 50];
    main_ax.YTickLabel = main_ax.YTickLabel(1:end-1);
    main_ax.YTick(end) = [];
    gauss_ax.Color = [1 1 1];
    gauss_ax.XColor = [0 0 0];
    gauss_ax.YColor = [0 0 0];
    gauss_ax.XLabel.Color = [0 0 0];
    gauss_ax.YLabel.Color = [0 0 0];
    gauss_ax.Units = 'pixel';
    gauss_ax.Position = [650 70 225 290];
    %gauss_ax.GridAlpha = 0.1;
    %res_ax.GridAlpha = 0.1;
    gauss_ax.FontSize = 15;
    main_ax.Children(end).Units = 'pixel';
    
    set(fig,'PaperPositionMode','auto');
    print(fig,GenerateName(fullfile(Path, 'All.tif'),1),'-dtiff','-r150','-painters')
    close(fig)
    
    % Active files
    Active = find(cell2mat(h.FitTab.Table.Data(1:end-3,1)))';
    
    for i = 1:numel(Active)
        fig = figure('Position',[100 ,100 ,900, 425],...
            'Color',[1 1 1],...
            'Resize','off');
        h.SingleTab.Popup.Value = i;
        Update_Plots([],[],2)
        main_ax = copyobj(h.SingleTab.Main_Axes,fig);
        res_ax = copyobj(h.SingleTab.Res_Axes,fig);
        gauss_ax = copyobj(h.SingleTab.Gauss_Axes,fig);
        main_ax.Children(end).Position = [1.35,1.09];
        main_ax.Color = [1 1 1];
        res_ax.Color = [1 1 1];
        main_ax.XColor = [0 0 0];
        main_ax.YColor = [0 0 0];
        res_ax.XColor = [0 0 0];
        res_ax.YColor = [0 0 0];
        main_ax.XLabel.Color = [0 0 0];
        main_ax.YLabel.Color = [0 0 0];
        res_ax.XLabel.Color = [0 0 0];
        res_ax.YLabel.Color = [0 0 0];
        main_ax.Units = 'pixel';
        res_ax.Units = 'pixel';
        main_ax.Position = [75 70 475 290];
        res_ax.Position = [75 360 475 50];
        main_ax.YTickLabel = main_ax.YTickLabel(1:end-1);
        main_ax.YTick(end) = [];
        gauss_ax.Color = [1 1 1];
        gauss_ax.XColor = [0 0 0];
        gauss_ax.YColor = [0 0 0];
        gauss_ax.XLabel.Color = [0 0 0];
        gauss_ax.YLabel.Color = [0 0 0];
        gauss_ax.Units = 'pixel';
        gauss_ax.Position = [650 70 225 290];
        %gauss_ax.GridAlpha = 0.1;
        %res_ax.GridAlpha = 0.1;
        gauss_ax.FontSize = 15;
        main_ax.Children(end).Units = 'pixel';
        set(fig,'PaperPositionMode','auto');
        print(fig,'-dtiff','-r150',GenerateName(fullfile(Path, [PDAData.FileName{Active(i)}(1:end-4) '.tif']),1),'-painters')
        close(fig)
    end
    
    % Function to export all figure and table data to a structure (for external use)
    
    % save file info
    tmp = struct;
    tmp.file = PDAData.FileName;
    tmp.path = PDAData.PathName;
    tmp.active = Active;
    h = guidata(findobj('Tag','GlobalPDAFit'));
    
    % save the fit table
    tmp.fittable = cell(size(h.FitTab.Table.Data, 1)-2, size(h.FitTab.Table.Data(1,2:3:end), 2));
    tmp.fittable(1,:) = h.FitTab.Table.ColumnName(2:3:end);
    tmp.fittable(2:end,:) = h.FitTab.Table.Data(1:end-3,2:3:end);
    
    % save the parameters table
    tmp.parameterstable = cell(size(h.ParametersTab.Table.Data));
    tmp.parameterstable(1,:) = h.ParametersTab.Table.ColumnName;
    tmp.parameterstable(2:end,:) = h.ParametersTab.Table.Data(1:end-1,:);
    
    % save the Gauss plots
    datasize = size(PDAMeta.Plots.Gauss_All,1);
    gausx = size(PDAMeta.Plots.Gauss_All{1,1}.XData,2);
    data = [];
    header = cell(1,datasize*7);
    for i = 1:datasize
        %x
        data(1:gausx,7*i-6) = PDAMeta.Plots.Gauss_All{i,1}.XData;
        for j = 1:6
            %gauss
            data(1:gausx,7*i-6+j) = PDAMeta.Plots.Gauss_All{i,j}.YData;
        end
        header(7*i-6:7*i) = {'x','gauss_sum','gauss1','gauss2','gauss3','gauss4','gauss5'};
    end
    tmp.gauss = data;
    tmp.gaussheader = header;
    
    % save Epr histograms, fit and res
    datax = size(PDAMeta.Plots.Data_All{1,1}.XData,2);
    data = [];
    header = cell(1,datasize*9);
    for i = 1:datasize
        %x axis
        data(1:datax,11*i-10) = PDAMeta.Plots.Data_All{i,1}.XData;
        % data
        data(1:datax,11*i-9) = PDAMeta.Plots.Data_All{i,1}.YData;
        % res
        data(1:datax,11*i-8) = PDAMeta.Plots.Res_All{i,1}.YData;
        for j = 1:8
            %fit
            data(1:datax,11*i-8+j) = PDAMeta.Plots.Fit_All{i,j}.YData;
        end
        header(11*i-10:11*i) = {'x','data','res','fit_sum','fit1','fit2','fit3','fit4','fit5','Donly','dynamic'};
    end
    tmp.epr = data;
    tmp.eprheader = header;
    
    % save the settings
    tmp.settings = UserValues.PDA;
    assignin('base','DataTableStruct',tmp);
    save(GenerateName(fullfile(Path, 'figure_table_data.mat'),1), 'tmp')
    
    %%% save everything to an excel table
    fitResult = cell(size(tmp.fittable,1),size(tmp.fittable,2));
    fitResult{1,1} = 'FileNames';
    fitResult(2:numel(tmp.file)+1,1) = tmp.file';
    tmp.fittable(2:end,:) = num2cell(cellfun(@str2double,tmp.fittable(2:end,:)));
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<HTML><b> ',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<HTML><b>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<b>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'</b>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<sub>','_'),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'</sub>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'&',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,';',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<html>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'</html>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'<sup>','^'),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'</sup>',''),tmp.fittable(1,:),'UniformOutput',false);
    tmp.fittable(1,:) = cellfun(@(x) strrep(x,'Aring','A'),tmp.fittable(1,:),'UniformOutput',false);    
    fitResult(1:size(tmp.fittable,1),2:size(tmp.fittable,2)+1) = tmp.fittable;
    %%% write to text file
    fID  = fopen(GenerateName(fullfile(Path, 'PDAresult.txt'),1),'w');
    fprintf(fID,[repmat('%s\t',1,17),'%s\n'],fitResult{1,:});
    for i = 2:size(fitResult,1)
        fprintf(fID,['%s' repmat('\t%.3f',1,17) '\n\n'],fitResult{i,:});
    end
    fprintf(fID,'Parameters:\n');
    fprintf(fID,[repmat('%s\t',1,6) '%s\n'],tmp.parameterstable{1,:});
    fprintf(fID,[repmat('%.3f\t',1,6) '%.3f\n'],tmp.parameterstable{2,:});
    fprintf(fID,'\nSettings:\n');
    settings = [fieldnames(tmp.settings), struct2cell(tmp.settings)];
    for i = 1:size(settings,1)
        if ischar(settings{i,2})
            settings{i,2} = str2double(settings{i,2});
        end
    end
    for i = 1:size(settings,1)-2
        fprintf(fID,'%s\t%d\n',settings{i,:});
    end
    fprintf(fID,'%s\t%.3f\n',settings{end-1,:});
    fprintf(fID,'%s\t%.3f\n',settings{end,:});
    fclose(fID);
    %%% save plot data also
    fID  = fopen(GenerateName(fullfile(Path, 'Plots.txt'),1),'w');
    data = [tmp.eprheader; num2cell(tmp.epr)];
    fprintf(fID,[repmat('%s\t',1,size(data,2)-1) '%s\n'],data{1,:});
    formatSpec = [repmat('%.3f\t',1,size(data,2)-1) '%.3f\n'];
    for i = 2:size(data,1)
        fprintf(fID,formatSpec,data{i,:});
    end
    fclose(fID);
end

% Update the Fit Tab
function Update_FitTable(~,e,mode)
h = guidata(findobj('Tag','GlobalPDAFit'));
global PDAMeta PDAData
switch mode
    case 0 %%% Updates whole table (Open UI)
        %%% Disables cell callbacks, to prohibit double callback
        h.FitTab.Table.CellEditCallback=[];
        %%% Column namges & widths
        Columns=cell(50,1);
        Columns{1}='Active';
        for i=1:5
            Columns{9*i-7}=['<HTML><b> A<sub>' num2str(i) '</sub></b>'];
            Columns{9*i-6}='F';
            Columns{9*i-5}='G';
            Columns{9*i-4}=['<HTML><b> R<sub>' num2str(i) '</sub> [&Aring;]</b>'];
            Columns{9*i-3}='F';
            Columns{9*i-2}='G';
            Columns{9*i-1}=['<HTML><b> &sigma;<sub>'  num2str(i) '</sub> [&Aring;]</b>'];
            Columns{9*i}='F';
            Columns{9*i+1}='G';
        end
        Columns{47} = '<HTML><b>D<sub>only</sub></b>';
        Columns{48} = 'F';
        Columns{49} = 'G';
        Columns{end}='<html><b>&chi;<sup>2</sup><sub>red.</sub></b></html>';
        ColumnWidth=zeros(numel(Columns),1);
        ColumnWidth(2:3:end-3)=40;
        ColumnWidth(2:9:end-12)=40;
        ColumnWidth(3:3:end-2)=15;
        ColumnWidth(4:3:end-1)=15;
        ColumnWidth(1)=40;
        ColumnWidth(end-1)=15;
        ColumnWidth(end)=40;
        h.FitTab.Table.ColumnName=Columns;
        h.FitTab.Table.ColumnWidth=num2cell(ColumnWidth');
        %%% Sets row names to file names
        Rows=cell(numel(PDAData.Data)+3,1);
        Rows(1:numel(PDAData.Data))=deal(PDAData.FileName);
        Rows{end-2}='ALL';
        Rows{end-1}='Lower bound';
        Rows{end}='Upper bound';
        h.FitTab.Table.RowName=Rows;
        
        %%% Create table data:
        %%% 1           = Active
        %%% 2:3:end-3   = Parameter value
        %%% 3:3:end-2   = Checkbox to fix parameter
        %%% 4:3:end-1   = Checkbox to fit parameter globally
        %%% 47          = chi^2
        Data=num2cell(zeros(numel(Rows),numel(Columns)));
        % put in data if it exists
        %Data(1:end-3,9:3:end)=deal(num2cell(PDAData.FitTable)');
        % fill in the all row
        tmp = [1; 50; 5; 1; 50; 5; 0; 50; 5; 0; 50; 5; 0; 50; 5; 0];
        Data(end-2,2:3:end-3)=deal(num2cell(tmp)');
        % fill in boundaries
        Data(end-1,2:3:end)=deal({0});
        Data(end,2:3:end)=deal({inf});
        Data=cellfun(@num2str,Data,'UniformOutput',false);
        % active checkbox
        Data(:,1)=deal({true});
        Data(2:end,1)=deal({[]});
        % fix checkboxes
        Data(1,3:3:end)=deal({false});
        Data(2:end,3:3:end)=deal({[]});
        % put the last three gaussians to fixed and zero amplitude
        Data(1,21:3:end)=deal({true});
        Data(1,20:9:end)=deal({'0'});
        % global checkboxes
        Data(1,4:3:end)=deal({false});
        Data(2:end,4:3:end)=deal({[]});
        h.FitTab.Table.Data=Data;
        h.FitTab.Table.ColumnEditable=[true(1,numel(Columns)-1),false];
        %%% Enables cell callback again
        h.FitTab.Table.CellEditCallback={@Update_FitTable,3};
    case 1 %%% Updates tables when new data is loaded
        h.FitTab.Table.CellEditCallback=[];
        %%% Sets row names to file names
        Rows=cell(numel(PDAData.Data)+3,1);
        tmp = PDAData.FileName;
        %%% Cuts the filename up if too long
        for i = 1:numel(tmp)
           try 
               tmp{i} = [tmp{i}(1:10) '...' tmp{i}(end-10:end)];
           end
        end
        Rows(1:numel(tmp))=deal(tmp);
        Rows{end-2}='ALL';
        Rows{end-1}='Lower bound';
        Rows{end}='Upper bound';
        h.FitTab.Table.RowName=Rows;
        Data=cell(numel(Rows),size(h.FitTab.Table.Data,2));
        %%% Sets previously loaded files
        Data(1:(size(h.FitTab.Table.Data,1)-3),:)=h.FitTab.Table.Data(1:end-3,:);
        %%% Set last 3 row to ALL, lb and ub
        Data(end-2:end,:)=h.FitTab.Table.Data(end-2:end,:);
        %%% Add FitTable data of new files in between old data and ALL row
        a = size(h.FitTab.Table.Data,1)-2; %if open data had 3 sets, new data has 3+2 sets, then a = 4
        for i = a:(size(Data,1)-3) % i = 4:5
            %%% Added D only fraction, so check old data for compatibility
            if (numel(PDAData.FitTable{i}) ~= 50)
                dummy = cell(50,1);
                dummy(1:46) = PDAData.FitTable{i}(1:46);
                dummy(47:49) = {'0',true,false};
                dummy(50) = PDAData.FitTable{i}(end);
                PDAData.FitTable{i} = dummy;
            end
            Data(i,:) = PDAData.FitTable{i};
        end
        for i = 1:15 % all fittable parameters
            if all(cell2mat(Data(1:end-3,3*i+1)))
                % this parameter is global for all files
                % so make the ALL row also global
                Data(end-2,3*i+1) = {true};
                % make the fix checkbox false
                Data(end-2,3*i) = {false};
                % make the ALL row the mean of all values for that parameter
                Data(end-2,3*i-1) = {num2str(mean(cellfun(@str2double,Data(1:end-3,3*i-1))))};
            else
                % this parameter is not global for all files
                % so make it not global for all files
                Data(1:end-2,3*i+1) = {false};
            end
            if all(cell2mat(Data(1:end-3,3*i)))
                % all of the fix checkboxes are true
                % make the ALL fix checkbox true
                Data(end-2,3*i) = {true};
            else
                Data(end-2,3*i) = {false};
            end           
        end
        h.FitTab.Table.Data=Data;
        %%% Enables cell callback again
        h.FitTab.Table.CellEditCallback={@Update_FitTable,3};
        PDAMeta.PreparationDone = zeros(numel(PDAData.Data),1);
    case 2 %%% Re-loads table from loaded data upon File menu - load fit parameters
        for i = 1:numel(PDAData.FileName)
            h.FitTab.Table.Data(i,:) = PDAData.FitTable{i};
        end
    case 3 %%% Individual cells callbacks
        %%% Disables cell callbacks, to prohibit double callback
        % when user touches the all row, value is applied to all cells
        h.FitTab.Table.CellEditCallback=[];
        %pause(0.25) %leave here, otherwise matlab will magically prohibit cell callback even before you click the cell
        if strcmp(e.EventName,'CellSelection') %%% No change in Value, only selected
            if isempty(e.Indices) || (e.Indices(1)~=(size(h.FitTab.Table.Data,1)-2) && e.Indices(2)~=1)
                h.FitTab.Table.CellEditCallback={@Update_FitTable,3};
                return;
            end
            NewData = h.FitTab.Table.Data{e.Indices(1),e.Indices(2)};
        end
        if isprop(e,'NewData')
            NewData = e.NewData;
        end
        if e.Indices(1)==size(h.FitTab.Table.Data,1)-2
            %% ALL row was used => Applies to all files
            h.FitTab.Table.Data(1:end-2,e.Indices(2))=deal({NewData});
            if mod(e.Indices(2)-2,3)==0 && e.Indices(2)>=1
                %% Value was changed => Apply value to global variables
            elseif mod(e.Indices(2)-3,3)==0 && e.Indices(2)>=2 && NewData==1
                %% Value was fixed => Uncheck global
            elseif mod(e.Indices(2)-4,3)==0 && e.Indices(2)>=3 && NewData==1
                %% Global was change
                %%% Apply value to all files
                h.FitTab.Table.Data(1:end-2,e.Indices(2)-2)=h.FitTab.Table.Data(e.Indices(1),e.Indices(2)-2);
                %%% Unfixes all files to prohibit fixed and global
                h.FitTab.Table.Data(1:end-2,e.Indices(2)-1)=deal({false});
            end
        elseif mod(e.Indices(2)-4,3)==0 && e.Indices(2)>=4 && e.Indices(1)<size(h.FitTab.Table.Data,1)-1
            %% Global was changed => Applies to all files
            h.FitTab.Table.Data(1:end-2,e.Indices(2))=deal({NewData});
            if NewData
                %%% Apply value to all files
                h.FitTab.Table.Data(1:end-2,e.Indices(2)-2)=h.FitTab.Table.Data(e.Indices(1),e.Indices(2)-2);
                %%% Unfixes all file to prohibit fixed and global
                h.FitTab.Table.Data(1:end-2,e.Indices(2)-1)=deal({false});
            end
        elseif mod(e.Indices(2)-3,3)==0 && e.Indices(2)>=3 && e.Indices(1)<size(h.FitTab.Table.Data,1)-1
            %% Value was fixed
            %%% if an amplitude was clicked, check if it is zero
            %%% -if it is zero and was disabled before, enable all related
            %%% parameters
            %%% -otherwise, disable all
            if any(e.Indices(2) == 3:9:size(h.FitTab.Table.Data,2)-11)
                if strcmp(h.FitTab.Table.Data(e.Indices(1),e.Indices(2)-1),'0')
                    if NewData == true
                        h.FitTab.Table.Data(e.Indices(1),[e.Indices(2)+3,e.Indices(2)+6]) = deal({true});
                    elseif NewData == false
                        h.FitTab.Table.Data(e.Indices(1),[e.Indices(2)+3,e.Indices(2)+6]) = deal({false});
                    end
                end
            end
            %%% Updates ALL row
            if all(cell2mat(h.FitTab.Table.Data(1:end-3,e.Indices(2))))
                h.FitTab.Table.Data{end-2,e.Indices(2)}=true;
            else
                h.FitTab.Table.Data{end-2,e.Indices(2)}=false;
            end
            %%% Unchecks global to prohibit fixed and global
            h.FitTab.Table.Data(1:end-2,e.Indices(2)+1)=deal({false;});
        elseif mod(e.Indices(2)-2,3)==0 && e.Indices(2)>=2 && e.Indices(1)<size(h.FitTab.Table.Data,1)-1
            %% Value was changed
            if h.FitTab.Table.Data{e.Indices(1),e.Indices(2)+2}
                %% Global => changes value of all files
                h.FitTab.Table.Data(1:end-2,e.Indices(2))=deal({NewData});
            else
                %% Not global => only changes value
            end
        elseif e.Indices(2)==1
            %% Active was changed
            %%% check if at least one fit is still active
            if sum(cell2mat(h.FitTab.Table.Data(1:end-3,1))) > 0
                h.FitTab.Table.Enable='off';
                pause(0.2)
                Update_Plots([],[],4)
                Update_Plots([],[],2) % to display the correct one on the single tab
                h.FitTab.Table.Enable='on';
            else
                %%% reset status
                h.FitTab.Table.Data{e.Indices(1),e.Indices(2)} = true;
            end
        end
        %%% Mirror the table in PDAData.FitTable
        %PDAData.FitTable = h.FitTab.Table.Data(1:end-3,:);
        %%% Enables cell callback again
        h.FitTab.Table.CellEditCallback={@Update_FitTable,3};
        %PDAMeta.PreparationDone = 0;
end

if h.SettingsTab.FixSigmaAtFractionOfR.Value == 1 %%% Fix Sigma at Fraction of R
    %%% Disables cell callbacks, to prohibit double callback
    h.FitTab.Table.CellEditCallback=[];
    %%% Get Table Data
    Data = h.FitTab.Table.Data;
    %%% Read out fraction
    fraction = str2double(h.SettingsTab.SigmaAtFractionOfR_edit.String);
    for i = 1:(size(Data,1)-2)
        %%% Fix all sigmas
        Data(i,9:9:end) = deal({true});
        %%% set to fraction times distance
        Data(i,8:9:end) = cellfun(@(x) num2str(fraction.*str2double(x)),Data(i,5:9:end-1),'UniformOutput',false);
    end
    %%% Set Table Data
    h.FitTab.Table.Data = Data;
    %%% Enables cell callback again
    h.FitTab.Table.CellEditCallback={@Update_FitTable,3};
end

% Update the Parameters Tab
function Update_ParamTable(~,e,mode)
h = guidata(findobj('Tag','GlobalPDAFit'));
global PDAMeta PDAData
switch mode
    case 0 %%% Updates whole table - when calling GlobalPDAFit
        %%% Disables cell callbacks, to prohibit double callback
        h.ParametersTab.Table.CellEditCallback=[];
        %%% Column names & widths
        Columns=cell(6,1);
        Columns{1}='Gamma';
        Columns{2}='Direct Exc';
        Columns{3}='Crosstalk';
        Columns{4}='BGD [kHz]';
        Columns{5}='BGA [kHz]';
        Columns{6}='R0 [A]';
        Columns{7}='Bin [ms]';
        ColumnWidth=zeros(numel(Columns),1);
        ColumnWidth(:) = 80;
        h.ParametersTab.Table.ColumnName=Columns;
        h.ParametersTab.Table.ColumnWidth=num2cell(ColumnWidth');
        %%% Sets row names to file names
        %Rows=cell(numel(PDAData.Data)+1,1);
        Rows = cell(1);
        %Rows(1:numel(PDAData.Data))=deal(PDAData.FileName);
        Rows{1}='ALL';
        h.ParametersTab.Table.RowName=Rows;
        %%% Create table data:
        % fill in the all row
        tmp = [1; 0; 0.02; 0; 0; 50; 1];
        Data=deal(num2cell(tmp)');
        Data{end} = [];
        %Data=cellfun(@num2str,Data,'UniformOutput',false);
        h.ParametersTab.Table.Data=Data;
        h.ParametersTab.Table.ColumnEditable = [true(1,numel(Columns)-1), false];
    case 1 %%% Updates tables when new data is loaded
        h.ParametersTab.Table.CellEditCallback=[];
        %%% Sets row names to file names
        Rows=cell(numel(PDAData.Data)+1,1);
        tmp = PDAData.FileName;
        %%% Cuts the filename up if too long
        for i = 1:numel(tmp)
           try 
               tmp{i} = [tmp{i}(1:10) '...' tmp{i}(end-10:end)];
           end
        end
        Rows(1:numel(tmp))=deal(tmp);
        Rows{end}='ALL';
        h.ParametersTab.Table.RowName=Rows;
        Data = cell(numel(Rows),size(h.ParametersTab.Table.Data,2));
        %%% Sets previous files
        Data(1:(size(h.ParametersTab.Table.Data,1)-1),:) = h.ParametersTab.Table.Data(1:end-1,:);
        %%% Set last row to ALL
        Data(end,:) = h.ParametersTab.Table.Data(end,:);
        %%% Add parameters of new files in between old data and ALL row
        tmp = zeros(numel(PDAData.FileName),7);
        for i = 1:numel(PDAData.FileName)
            tmp(i,1) = PDAData.Corrections{i}.Gamma_GR;
            % direct excitation correction in Burst analysis is NOT the
            % same as PDA, therefore we put it to zero. In PDA, this factor
            % is either the extcoeffA/(extcoeffA+extcoeffD) at donor laser,
            % or the ratio of Int(A)/(Int(A)+Int(D)) for a crosstalk, gamma
            % corrected double labeled molecule having no FRET at all.
            if isfield(PDAData.Corrections{i},'DirectExcitationProb')
                tmp(i,2) = PDAData.Corrections{i}.DirectExcitationProb;
            else
                tmp(i,2) = 0; %PDAData.Corrections{i}.DirectExcitation_GR;
            end
            tmp(i,3) = PDAData.Corrections{i}.CrossTalk_GR;
            tmp(i,4) = PDAData.Background{i}.Background_GGpar + PDAData.Background{i}.Background_GGperp;
            tmp(i,5) = PDAData.Background{i}.Background_GRpar + PDAData.Background{i}.Background_GRperp;
            tmp(i,6) = PDAData.Corrections{i}.FoersterRadius;
            tmp(i,7) = PDAData.timebin(i)*1000;
        end
        Data(size(h.ParametersTab.Table.Data,1):(end-1),:) = num2cell(tmp(size(h.ParametersTab.Table.Data,1):end,:));
        % put the ALL row to the mean of the loaded data 
        Data(end,1:end-1) = num2cell(mean(cell2mat(Data(1:end-1,1:end-1)),1));
        %%% Adds new files
        h.ParametersTab.Table.Data = Data;
        PDAMeta.PreparationDone = zeros(numel(PDAData.Data),1);
    case 2 %%% Loading params again from data
        h.ParametersTab.Table.CellEditCallback=[];
        for i = 1:numel(PDAData.FileName)
            tmp(i,1) = PDAData.Corrections{i}.Gamma_GR;
            if ~isfield(PDAData.Corrections{i},'DirectExcitationProb') % value was not yet set in PDA
                tmp(i,2) = 0; %see above for explanation! PDAData.Corrections{i}.DirectExcitation_GR;
            else
                tmp(i,2) = PDAData.Corrections{i}.DirectExcitationProb;
            end
            tmp(i,3) = PDAData.Corrections{i}.CrossTalk_GR;
            tmp(i,4) = PDAData.Background{i}.Background_GGpar + PDAData.Background{i}.Background_GGperp;
            tmp(i,5) = PDAData.Background{i}.Background_GRpar + PDAData.Background{i}.Background_GRperp;
            tmp(i,6) = PDAData.Corrections{i}.FoersterRadius;
            tmp(i,7) = PDAData.timebin(i)*1000;
        end
        h.ParametersTab.Table.Data(1:end-1,:) = num2cell(tmp);
        PDAMeta.PreparationDone = zeros(numel(PDAData.FileName),1);
    case 3 %%% Individual cells callbacks
        %%% Disables cell callbacks, to prohibit double callback
        % touching a ALL value cell applies that value everywhere
        h.ParametersTab.Table.CellEditCallback=[];
        if strcmp(e.EventName,'CellSelection') %%% No change in Value, only selected
            if isempty(e.Indices) || (e.Indices(1)~=size(h.ParametersTab.Table.Data,1) && e.Indices(2)~=1)                                                                                             
                h.ParametersTab.Table.CellEditCallback={@Update_ParamTable,3};
                return;
            end
            NewData = h.ParametersTab.Table.Data{e.Indices(1),e.Indices(2)};
        end
        if isprop(e,'NewData')
            if e.Indices(2) ~= 7
                NewData = e.NewData;
            else
                NewData = e.PreviousData; %used in the all row
                h.ParametersTab.Table.Data{e.Indices(1),e.Indices(2)} = e.PreviousData; % the bin column was touched
            end
        end
        if e.Indices(1)==size(h.ParametersTab.Table.Data,1)
            if e.Indices(2) ~= 7 % do not do for the Bin column
                %% ALL row was used => Applies to all files
                h.ParametersTab.Table.Data(:,e.Indices(2))=deal({NewData});
            end
            PDAMeta.PreparationDone(:) = 0;
        else
            PDAMeta.PreparationDone(e.Indices(1)) = 0;
        end
        
        
        %%% Values were changed, store this in PDAData structure so it is
        %%% saved with the files
        Data = h.ParametersTab.Table.Data;
        for i = 1:numel(PDAData.Corrections)
            PDAData.Corrections{i}.Gamma_GR = Data{i,1};
            PDAData.Corrections{i}.DirectExcitationProb = Data{i,2};
            PDAData.Corrections{i}.CrossTalk_GR = Data{i,3};
            % left out background countrates here because they should
            % barely ever change
            PDAData.Corrections{i}.FoersterRadius = Data{i,6};
        end
end

%%% Enables cell callback again
h.ParametersTab.Table.CellEditCallback={@Update_ParamTable,3};

% Function that generates random data when there is nothing to show
function SampleData
global PDAMeta
h = guidata(findobj('Tag','GlobalPDAFit'));

% generate data
% main plot
x = linspace(0,1,51);
y{1} = abs(sum(peaks(51),1));
f{1} = y{1}.*(1 + 0.15*randn(1,51));
r{1} = (y{1}-f{1})./sqrt(y{1});
y{2} = y{1}(end:-1:1);
f{2} = f{1}(end:-1:1);
r{2} = r{1}(end:-1:1);

color = lines(5);
% results plot
gauss_dummy{1} = zeros(5,150*10+1);
for i = 1:5
    gauss_dummy{1}(i,:) = normpdf(0:0.1:150,40+10*i,i);
end

for i = 1:5
    gauss_dummy{2}(i,:) = gauss_dummy{1}(i,end:-1:1);
end
% BSD plot
expon{1} = exp(-(0:200)/50)*1000;
expon{2} = exp(-(0:200)/100)*1000;

% fill plots
PDAMeta.Plots.Data_Single = bar(h.SingleTab.Main_Axes,...
    x,...
    y{1},...
    'EdgeColor','none',...
    'FaceColor',[0.4 0.4 0.4],...
    'BarWidth',1);
PDAMeta.Plots.Res_Single = bar(h.SingleTab.Res_Axes,...
    x,...
    r{1},...
    'FaceColor','none',...
    'EdgeColor',[0 0 0],...
    'BarWidth',1,...
    'LineWidth',2);
PDAMeta.Plots.Fit_Single = bar(h.SingleTab.Main_Axes,...
    x,f{1},...
    'EdgeColor',[0 0 0],...
    'FaceColor','none',...
    'BarWidth',1,...
    'LineWidth',2);
PDAMeta.Plots.BSD_Single = plot(h.SingleTab.BSD_Axes,...
    0:200,...
    expon{1},...
    'Color','k',...
    'LineWidth',2);
PDAMeta.Plots.PF_Deconvolved_Single = plot(h.SingleTab.BSD_Axes,...
    0:200,...
    expon{1},...
    'Color','k',...
    'LineWidth',2,...
    'LineStyle','--',...
    'Visible','off');
axis('tight');
PDAMeta.Plots.ES_Single = plot(h.SingleTab.ES_Axes,...
    0,...
    0,...
    'Color','k',...
    'LineStyle','none',...
    'Marker','.');
axis('tight');
PDAMeta.Plots.Gauss_Single{1} = plot(h.SingleTab.Gauss_Axes,...
    0:0.1:150,...
    sum(gauss_dummy{1},1),...
    'Color','k',...
    'LineWidth',2);
axis('tight');
for i = 2:6
    PDAMeta.Plots.Gauss_Single{i} = plot(h.SingleTab.Gauss_Axes,...
        0:0.1:150,...
        gauss_dummy{1}(i-1,:),...
        'Color',color(i-1,:),...
        'LineWidth',2,...
        'LineStyle', '-');
end
xlim(h.SingleTab.Gauss_Axes,[40 120]);

x = x-mean(diff(x))/2; %to make the stairs graph appear similar to the bar graph

%All Data
hold on
for i = 1:2
    PDAMeta.Plots.Data_All = cell(2,1);
    PDAMeta.Plots.Res_All = cell(2,1);
    PDAMeta.Plots.Fit_All = cell(2,1);
    PDAMeta.Plots.Data_All{i} = stairs(h.AllTab.Main_Axes,...
        x, y{i},...
        'Color',(3.*color(i,:)+1)./4,...
        'LineWidth', 1);
    PDAMeta.Plots.Res_All{i} = stairs(h.AllTab.Res_Axes,...
        x, r{i},...
        'Color',color(i,:),...
        'LineWidth', 1);
    PDAMeta.Plots.Fit_All{i} = stairs(h.AllTab.Main_Axes,...
        x, f{i},...
        'Color',color(i,:),...
        'LineWidth', 2,...
        'LineStyle', '--');
end
for i = 1:2
    PDAMeta.Plots.BSD_All{i} = plot(h.AllTab.BSD_Axes,...
        0:200,...
        expon{i},...
        'Color',color(i,:),...
        'LineWidth',2);
    axis('tight');
    PDAMeta.Plots.ES_All{i} = plot(h.AllTab.ES_Axes,...
    0,...
    0,...
    'Color','k',...
    'LineStyle','none',...
    'Marker','.');
end
for i = 1:2
    c = color(i,:);
    PDAMeta.Plots.Gauss_All{i,1} = plot(h.AllTab.Gauss_Axes,...
        0:0.1:150,...
        sum(gauss_dummy{i},1),...
        'Color',color(i,:),...
        'LineWidth',2);
    for j = 2:6
        c = (3.*c + 1)./4;
        PDAMeta.Plots.Gauss_All{i,j} = plot(h.AllTab.Gauss_Axes,...
            0:0.1:150,...
            gauss_dummy{i}(j-1,:),...
            'Color',c,...
            'LineWidth',2);
    end
    
end
axis('tight');
xlim(h.AllTab.Gauss_Axes,[40 120]);

% Info menu - To do list
function Todolist(~,~)
msgbox({...
    'allow to set Epr limits for plotting and analysis';...
    'remove everything from global that is not needed in global';...
    'add a legend in the plots';...
    'sigma cannot be zero or a very small number';...
    'possibility to plot the actual E instead of Epr';...
    'brightness corrected PDA';...
    'put the optimplotfval into the gauss plot, so fitting can be evaluated per iteration, rather than per function sampling';...
    'fix the ignore outer limits for MLE fitting';...
    '';...
    '';...
    ''} ,'To do list','modal');

% Info menu - Manual callback
function Manual(~,~)
if ismac
    inp = '/Global PDA Fitting.docx';
    %MACOPEN Open a file or directory using the OPEN terminal utility on the MAC.
    %   MACOPEN FILENAME opens the file or directory FILENAME using the
    %   the OPEN terminal command.
    %
    %   Examples:
    %
    %     If you have Microsoft Word installed, then
    %     macopen('/myDoc.docx')
    %     opens that file in Microsoft Word if the file exists, and errors if
    %     it doesn't.
    %
    %     macopen('/Applications')
    %     opens a new Finder window, showing the contents of your /Applications
    %     folder.
    %
    %   See also WINOPEN, OPEN, DOS, WEB.
    
    % Copyright 2012 - 2013 The MathWorks, Inc.
    % Written: 16-Apr-2012, Varun Gandhi
    if strcmpi('.',inp)
        inp = pwd;
    end
    syscmd = ['open ', inp, ' &'];
    %disp(['Running the following in the Terminal: "', syscmd,'"']);
    system(syscmd);
else
    winopen('Global PDA Fitting.docx')
end

% Database management
function Database(~,e,mode)
global UserValues PDAData
LSUserValues(0);
h = guidata(findobj('Tag','GlobalPDAFit'));

if mode == 0
    switch e.Key
        case 'delete'
            mode = 1;
    end
end

switch mode
    case 1 
        %% Delete files from database
        %remove rows from list
        h.PDADatabase.List.String(h.PDADatabase.List.Value) = [];
        %remove data from PDAData
        PDAData.FileName(h.PDADatabase.List.Value) = [];
        PDAData.PathName(h.PDADatabase.List.Value) = [];
        PDAData.Data(h.PDADatabase.List.Value) = [];
        PDAData.timebin(h.PDADatabase.List.Value) = [];
        PDAData.Corrections(h.PDADatabase.List.Value) = [];
        PDAData.Background(h.PDADatabase.List.Value) = [];
        PDAData.FitTable(h.PDADatabase.List.Value) = [];
        PDAData.OriginalFitParams = PDAData.FitTable;
        h.FitTab.Table.RowName(h.PDADatabase.List.Value)=[];
        h.FitTab.Table.Data(h.PDADatabase.List.Value,:)=[];
        h.ParametersTab.Table.RowName(h.PDADatabase.List.Value)=[];
        h.ParametersTab.Table.Data(h.PDADatabase.List.Value,:)=[];
        
        h.PDADatabase.List.Value = 1;
        if size(h.PDADatabase.List.String, 1) < 1
            % no files are left
            h.PDADatabase.Save.Enable = 'off';
            SampleData
        else
            Update_FitTable([],[],1);
            Update_ParamTable([],[],1);
            Update_Plots([],[],3);
        end
    case 2 
        %% Load database
        [FileName, Path] = uigetfile({'*.pab', 'PDA Database file (*.pab)'}, 'Choose PDA database to load',UserValues.File.PDAPath,'MultiSelect', 'off');
        load('-mat',fullfile(Path,FileName));
        if FileName ~= 0
            PDAData.FileName = s.file;
            PDAData.PathName = s.path;
            Load_PDA([],[],3);
            %h.PDADatabase.List.String = s.str;
            clear s;
            if size(h.PDADatabase.List.String, 1) > 0
                % files are left
                h.PDADatabase.Save.Enable = 'on';
            else
                SampleData
            end
        end
    case 3 
        %% Save complete database
        [File, Path] = uiputfile({'*.pab', 'PDA Database file (*.pab)'}, 'Save PDA database', UserValues.File.PDAPath);
        s = struct;
        s.file = PDAData.FileName;
        s.path = PDAData.PathName;
        %s.str = h.PDADatabase.List.String;
        save(fullfile(Path,File),'s');
end

% Updates GUI elements
function Update_GUI(obj,~)
h = guidata(obj);

if obj == h.SettingsTab.FixSigmaAtFractionOfR
    switch obj.Value
        case 1
            %%% Enable Check Box
            h.SettingsTab.SigmaAtFractionOfR_edit.Enable = 'on';
            h.SettingsTab.FixSigmaAtFractionOfR_Fix.Enable = 'on';
            %%% Update FitParameter Table (fix all sigmas, set to value
            %%% according to number in edit box)
            Update_FitTable([],[],4);
            %%% Disable Columns
            h.FitTab.Table.ColumnEditable(8:9:end) = deal(false);
            h.FitTab.Table.ColumnEditable(9:9:end) = deal(false);
            h.FitTab.Table.ColumnEditable(10:9:end) = deal(false);
        case 0
            h.SettingsTab.SigmaAtFractionOfR_edit.Enable = 'off';
            h.SettingsTab.FixSigmaAtFractionOfR_Fix.Enable = 'off';
            %%% Reset the fixed status of the fit table
            Data = h.FitTab.Table.Data;
            for i = 1:(size(Data,1)-2)
                %%% Fix all sigmas
                Data(i,9:9:end) = deal({false});
            end
            h.FitTab.Table.Data = Data;
            %%% Reenable Columns
            h.FitTab.Table.ColumnEditable(8:9:end) = deal(true);
            h.FitTab.Table.ColumnEditable(9:9:end) = deal(true);
            h.FitTab.Table.ColumnEditable(10:9:end) = deal(true);
    end
elseif obj == h.SettingsTab.DynamicModel
    switch h.SettingsTab.DynamicModel.Value
        case 1 %%% switched to dynamic
            %%% Change label of Fit Parameter Table
            h.FitTab.Table.ColumnName{2} = '<HTML><b>k<sub>12</sub> [ms<sup>-1</sup>]</b>';
            h.FitTab.Table.ColumnName{11} = '<HTML><b>k<sub>21</sub> [ms<sup>-1</sup>]</b>';
            h.FitTab.Table.ColumnWidth{2} = 70;
            h.FitTab.Table.ColumnWidth{11} = 70;
            %%% Only enable Histogram Library in PDA Method
            h.SettingsTab.PDAMethod_Popupmenu.Value = 1;
            h.SettingsTab.PDAMethod_Popupmenu.String = {'Histogram Library'};
        case 0 %%% switched back to static
            %%% Revert Label of Fit Parameter Table
            h.FitTab.Table.ColumnName{2} = '<HTML><b>A<sub>1</sub></b>';
            h.FitTab.Table.ColumnName{11} = '<HTML><b>A<sub>2</sub></b>';
            h.FitTab.Table.ColumnWidth{2} = 40;
            h.FitTab.Table.ColumnWidth{11} = 40;
            %%% Revert to all PDA Methods
            if ~h.SettingsTab.DeconvoluteBackground.Value
                h.SettingsTab.PDAMethod_Popupmenu.String = {'Histogram Library','MLE','MonteCarlo'};
            end
    end
end

% function for loading of brightness reference, i.e. donor only sample
function Load_Brightness_Reference(obj,~,mode)
global PDAData UserValues PDAMeta

load_file = 0;
if ~isempty(PDAData)
    switch mode
        case 1
            if obj.Value == 1
                if isempty(PDAData.BrightnessReference)
                    load_file = 1;
                end
                PDAMeta.Plots.BSD_Reference.Visible = 'on';
            else
                PDAMeta.Plots.BSD_Reference.Visible = 'off';
            end
        case 2
            load_file = 1;
    end
end         
            
if load_file
    %%% Load data
    [FileName,p] = uigetfile({'*.pda','*.pda file'},'Select *.pda file containing a Donor only measurement',...
        UserValues.File.PDAPath,'Multiselect','off');
    
    if all(FileName==0)
        return
    end
    
    load(fullfile(p,FileName),'-mat');
    PDAData.BrightnessReference.N = PDA.NG;
    PDAData.BrightnessReference.PN = histcounts(PDAData.BrightnessReference.N,1:(max(PDAData.BrightnessReference.N)+1));
    
    %%% Update Plot
    PDAMeta.Plots.BSD_Reference.XData = 1:max(PDAData.BrightnessReference.N);
    PDAMeta.Plots.BSD_Reference.YData = PDAData.BrightnessReference.PN;
end

%%% Scale Photon Count Distribution to lower brightness (linear scaling,
%%% approximately correct)
function [ PN_scaled ] = scalePN(PN, scale_factor)
PN_scaled = interp1(scale_factor*[1:1:numel(PN)],PN,[1:1:numel(PN)]);
PN_scaled(isnan(PN_scaled)) = 0;

%%% Calculate the relative brightness based on FRET value
function Qr = calc_relative_brightness(R,file)
global PDAMeta
de = PDAMeta.directexc(file);
ct = PDAMeta.crosstalk(file);
gamma = PDAMeta.gamma(file);
E = 1/(1+(R/PDAMeta.R0(file)).^6);
Qr = (1-de)*(1-E) + (gamma/(1+ct))*(de+E*(1-de));

%%% Re-calculate the P array based on changed PN (brightness correction)
function P = recalculate_P(PN_scaled,file, Nobins, NobinsE)
global PDAMeta

PN  = PN_scaled';
P = cell(1,NobinsE);
if PDAMeta.NBG{file} == 0 && PDAMeta.NBR{file} == 0
    for j = 1:NobinsE+1
        PN_trans = repmat(PN,1,PDAMeta.maxN{file}+1);
        PN_trans = PN_trans(:);
        PN_trans = PN_trans(PDAMeta.HistLib.valid{file}{j});
        P{1,j} = accumarray(PDAMeta.HistLib.bin{file}{j},PDAMeta.HistLib.P_array{file}{j}.*PN_trans);
    end
else
    for j = 1:NobinsE+1
        P{1,j} = zeros(Nobins,1);
        count = 1;
        for g = 0:PDAMeta.NBG{file}
            for r = 0:PDAMeta.NBR{file}
                PN_trans = repmat(PN(1+g+r:end),1,PDAMeta.maxN{file}+1);%the total number of fluorescence photons is reduced
                PN_trans = PN_trans(:);
                PN_trans = PN_trans(PDAMeta.HistLib.valid{file}{j}{count});
                %%% Now uses C-code
                P{1,j} = P{1,j} + accumarray_c(PDAMeta.HistLib.bin{file}{j}{count},PDAMeta.HistLib.P_array{file}{j}{count}.*PN_trans,max(PDAMeta.HistLib.bin{file}{j}{count}),numel(PDAMeta.HistLib.bin{file}{j}{count}))';
                % P{1,j} = P{1,j} + accumarray(PDAMeta.HistLib.bin{file}{j}{count},PDAMeta.HistLib.P_array{file}{j}{count}.*PN_trans);
                count = count+1;
            end
        end
    end
end
        
function PofT = calc_dynamic_distribution(dT,N,k1,k2)
%%% Calculates probability distribution of dynamic mixing of states for
%%% two-state kinetic scheme
%%% Inputs:
%%% dT  -   Bin time
%%% N   -   Number of time steps to compute
%%% k1  -   Rate from state 1 to state 2
%%% k2  -   Rate from state 2 to state 1

% Split in N+1 time bins
PofT = zeros(1,N+1);
dt = dT/N;

%%% catch special case where k1 = k2 = 0
if (k1 == 0) && (k2 == 0)
    %%% No dynamics, i.e. equal weights
    PofT(1) = 0.5;
    PofT(end) = 0.5;
    return;
end
%%% first and last bin are special cases
PofT(1) = k1/(k1+k2)*exp(-k2*dT) + calcPofT(k1,k2,dt/2,dT-dt/2,dt/2);
PofT(end) = k2/(k1+k2)*exp(-k1*dT) + calcPofT(k1,k2,dT-dt/2,dt/2,dt/2);

%%% rest is determined by formula (2d) in paper giving P(i*dt-dt/2 < T < i*dt+dt/2)
for i = 1:N-1
    T1 = i*dt;
    T2 = dT-T1;
    PofT(i+1) = calcPofT(k1,k2,T1,T2,dt); 
end
PofT = PofT./sum(PofT);


function PofT = calcPofT(k1,k2,T1,T2,dt)
%%% calculates probability for cumulative time spent in state 1(T1) to lie
%%% in range T1-dt, T1+dt based on formula from Seidel paper
%%% besseli is the MODIFIED bessel function of first kind
PofT = (...
       (2*k1*k2/(k1+k2))*besseli(0,2*sqrt(k1*k2*T1*T2)) + ...
       ((k2*T1+k1*T2)/(k1+k2))*(sqrt(k1*k2)/sqrt(T1*T2))*...
       besseli(1,2*sqrt(k1*k2*T1*T2)) ...
       ) * exp(-k1*T1-k2*T2)*dt;
     
function PofF = deconvolute_PofF(S,bg,resolution)
%%% deconvolutes input PofF using a sum of Poisson distributios as kernel
%%% to obtain background-free fluorescence signal distribution PofF
%%%
%%% See: Kalinin, S., Felekyan, S., Antonik, M. & Seidel, C. A. M. Probability Distribution Analysis of Single-Molecule Fluorescence Anisotropy and Resonance Energy Transfer. J. Phys. Chem. B 111, 10253?10262 (2007).

%%% Input parameter:
%%% S   -   the experimentally observed burst sizes
%%% bg  -   the total background
%%% resolution - resolution for brightness vector

if nargin < 3
    resolution = 200;
end
%%% Construct the histogram PF
xS = 0:1:max(S)+1;
PS= histcounts(S,xS);
xS = xS(1:end-1);
%%% vector of brightnesses to consider
b = linspace(0,max(S),resolution);

%%% Establish Poisson library based on brightness vector INCLUDING background
%%% convolution of model PofF with Poissonian background simplifies to
%%% using a modified brightness b' = b + bg
%%% This follows because the convolution of two Poissonian distributions
%%% equals again a Poissonian with sum of rate parameters.
%%% see equation 12 of reference
PS_ind = poisspdf(repmat(xS,numel(b),1),repmat(bg+b',1,numel(xS)));

%%% Calculate error estimate based on poissonian counting statistics
error = sqrt(PS); error(error == 0) = 1;

%%% equation 12 of reference to calculate PofS from library
% sum(PS_ind.*repmat(p,1,numel(xS),1)) = P(S)
%%% scaling parameter for the entropy term
v = 10;
mem = @(p) -(v*sum(p-p.*log(p)) - sum( (PS-sum(PS_ind.*repmat(p,1,numel(xS),1)).*numel(S)).^2./error.^2)./(numel(PS)));
%%% initialize p
p0 = ones(numel(b),1)./numel(b);
p=p0;

%%% initialize boundaries
Aieq = -eye(numel(p0)); bieq = zeros(numel(p0),1);
lb = zeros(numel(p0),1); ub = inf(numel(p0),1);

%%% specify fit options
opts = optimoptions(@fmincon,'MaxFunEvals',1E5,'Display','iter','TolFun',1E-4);
p = fmincon(mem,p,Aieq,bieq,[],[],lb,ub,@nonlcon,opts); 

%%% construct distribution PofF from distribution over brightnesses
%%% this time, we exculde background to obtain the "purified" fluorescence
%%% count distribution
PF_ind = poisspdf(repmat(xS,numel(b),1),repmat(b',1,numel(xS)));
PofF = sum(PF_ind.*repmat(p,1,numel(xS),1));
PofF = PofF./sum(PofF);

function [c,ceq] = nonlcon(x)
%%% nonlinear constraint for deconvolution
c = [];
ceq = sum(x) - 1;

function Files = GetMultipleFiles(FilterSpec,Title,PathName)
FileName = 1;
count = 0;
Files = [];
while FileName ~= 0
    [FileName,PathName] = uigetfile(FilterSpec,Title, PathName, 'MultiSelect', 'on');
    if ~iscell(FileName)
        if FileName ~= 0
            count = count+1;
            Files{count,1} = FileName;
            Files{count,2} = PathName;
        end
    elseif iscell(FileName)
        for i = 1:numel(FileName)
            if FileName{i} ~= 0
                count = count+1;
                Files{count,1} = FileName{i};
                Files{count,2} = PathName;
            end
        end
        FileName = FileName{end};
    end
    PathName= fullfile(PathName,'..',filesep);%%% go one layer above since .*pda files are nested
end