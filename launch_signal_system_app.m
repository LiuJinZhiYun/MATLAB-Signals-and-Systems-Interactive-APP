function app = launch_signal_system_app(varargin)
    parser = inputParser;
    addParameter(parser, "Visible", true, @(x) islogical(x) || isnumeric(x));
    addParameter(parser, "AutoDemo", false, @(x) islogical(x) || isnumeric(x));
    parse(parser, varargin{:});

    isVisible = logical(parser.Results.Visible);
    autoDemo = logical(parser.Results.AutoDemo);
    visibilityState = "on";
    if ~isVisible
        visibilityState = "off";
    end

    stageOrder = ["original", "noisy", "filtered", "enhanced", "effect", "encrypted", "encoded", "modulated", "channel", "demodulated", "decoded", "decrypted", "restored"];
    stageLabels = struct( ...
        "original", "原始信号", ...
        "noisy", "加噪信号", ...
        "filtered", "滤波结果", ...
        "enhanced", "高级增强", ...
        "effect", "变声结果", ...
        "encrypted", "加密语音", ...
        "encoded", "编码序列", ...
        "decrypted", "解密语音", ...
        "modulated", "调制结果", ...
        "channel", "信道输出", ...
        "demodulated", "解调结果", ...
        "decoded", "译码结果", ...
        "restored", "恢复信号");

    state = struct();
    state.baseDir = string(fileparts(mfilename("fullpath")));
    state.fs = [];
    state.sourceLabel = "未加载";
    state.currentStage = "original";
    state.stageOrder = stageOrder;
    state.stageLabels = stageLabels;
    state.signals = struct();
    state.stageMeta = struct();
    state.cryptoInfo = [];
    state.recorder = [];
    state.isRecording = false;
    state.recordingBuffer = zeros(0, 1);
    state.recordingFs = 16000;
    state.recordingMaxDuration = 8;
    state.recordingElapsedSeconds = 0;
    state.recordingPeak = 0;
    state.recordingStatus = "空闲";
    state.liveAnalysis = struct( ...
        "captureMode", "限时实时采集", ...
        "listenBufferSeconds", 8, ...
        "frameBands", [0, 300, 1200, 3400, 8000], ...
        "frameTrend", zeros(0, 5), ...
        "latestFrameInfo", struct(), ...
        "latestSpectrogram", struct(), ...
        "previewSignal", zeros(0, 1), ...
        "previewMetrics", struct(), ...
        "isPreviewEnabled", true, ...
        "lastCommInfo", struct(), ...
        "lastCommChain", struct());
    state.playback = struct( ...
        "player", [], ...
        "currentMode", "idle");
    state.recommendation = struct( ...
        "filterType", "Butterworth低通", ...
        "cutoffHz", 2200, ...
        "order", 6, ...
        "reason", "尚未执行智能分析。", ...
        "enhancementMethod", "小波去噪", ...
        "enhancementStrength", 0.60, ...
        "summary", "尚未执行智能分析。先读取信号，再点击“分析当前信号”。");
    state.logMessages = "应用已启动。请先载入样例语音、本地音频或合成信号。";

    state.stageLabels = struct( ...
        "original", "原始信号", ...
        "noisy", "加噪信号", ...
        "filtered", "滤波结果", ...
        "enhanced", "高级增强", ...
        "effect", "变声结果", ...
        "encrypted", "加密语音", ...
        "encoded", "编码序列", ...
        "decrypted", "解密语音", ...
        "modulated", "调制结果", ...
        "channel", "信道输出", ...
        "demodulated", "解调结果", ...
        "decoded", "译码结果", ...
        "restored", "恢复信号");
    state.sourceLabel = "未加载";
    state.recordingStatus = "空闲";
    state.liveAnalysis.captureMode = "限时实时采集";
    state.recommendation.filterType = "Butterworth低通";
    state.recommendation.reason = "尚未执行智能分析。";
    state.recommendation.enhancementMethod = "小波去噪";
    state.recommendation.summary = "尚未执行智能分析。请先读取信号，再点击“分析当前信号”。";
    state.logMessages = "应用已启动。请先载入样例语音、本地音频或合成信号。";

    theme = struct();
    theme.Bg = [244, 247, 252] / 255;
    theme.Panel = [234, 239, 247] / 255;
    theme.Card = [255, 255, 255] / 255;
    theme.Card2 = [248, 250, 253] / 255;
    theme.Primary = [56, 189, 248] / 255;
    theme.Secondary = [167, 139, 250] / 255;
    theme.Success = [34, 197, 94] / 255;
    theme.Warning = [245, 158, 11] / 255;
    theme.Error = [239, 68, 68] / 255;
    theme.Text = [33, 43, 54] / 255;
    theme.Muted = [96, 109, 128] / 255;
    theme.Grid = [205, 214, 226] / 255;
    theme.Surface = [250, 252, 255] / 255;
    theme.InputBg = [255, 255, 255] / 255;

    screenSize = get(groot, "ScreenSize");
    figureWidth = max(1500, round(screenSize(3) * 0.92));
    figureHeight = max(860, round(screenSize(4) * 0.88));
    figureLeft = max(10, round((screenSize(3) - figureWidth) / 2));
    figureBottom = max(10, round((screenSize(4) - figureHeight) / 2));

    app = struct();
    app.Figure = uifigure( ...
        "Name", "信号与系统课程大作业 APP", ...
        "Position", [figureLeft, figureBottom, figureWidth, figureHeight], ...
        "Color", theme.Bg, ...
        "Visible", visibilityState);
    app.Figure.CloseRequestFcn = @(~, ~) closeAppCallback();

    app.MainGrid = uigridlayout(app.Figure, [3, 2]);
    app.MainGrid.RowHeight = {126, "1x", 138};
    app.MainGrid.ColumnWidth = {540, "1x"};
    app.MainGrid.Padding = [14, 14, 14, 14];
    app.MainGrid.RowSpacing = 14;
    app.MainGrid.ColumnSpacing = 14;

    app.HeaderPanel = uipanel(app.MainGrid, ...
        "BorderType", "none", ...
        "BackgroundColor", theme.Bg);
    app.HeaderPanel.Layout.Row = 1;
    app.HeaderPanel.Layout.Column = [1, 2];

    headerGrid = uigridlayout(app.HeaderPanel, [1, 5]);
    headerGrid.ColumnWidth = {"2.2x", "0.9x", "0.9x", "0.9x", "0.9x"};
    headerGrid.RowHeight = {"1x"};
    headerGrid.Padding = [0, 0, 0, 0];
    headerGrid.ColumnSpacing = 12;

    titlePanel = uipanel(headerGrid, ...
        "BorderType", "none", ...
        "BackgroundColor", theme.Panel);
    titlePanel.Layout.Row = 1;
    titlePanel.Layout.Column = 1;
    titleGrid = uigridlayout(titlePanel, [3, 1]);
    titleGrid.RowHeight = {"fit", "fit", "fit"};
    titleGrid.ColumnWidth = {"1x"};
    titleGrid.Padding = [18, 14, 18, 10];
    titleGrid.RowSpacing = 4;

    app.TitleLabel = uilabel(titleGrid, ...
        "Text", "信号与系统实验大作业 APP", ...
        "FontSize", 27, ...
        "FontWeight", "bold", ...
        "FontColor", theme.Text, ...
        "FontName", "Microsoft YaHei");
    app.SubtitleLabel = uilabel(titleGrid, ...
        "Text", "读取、加噪、滤波、高级增强、变声、加密、调制解调、历史对比与智能推荐", ...
        "FontSize", 11, ...
        "FontColor", theme.Muted, ...
        "FontName", "Microsoft YaHei");

    quickGrid = uigridlayout(titleGrid, [1, 4]);
    quickGrid.Layout.Row = 3;
    quickGrid.Layout.Column = 1;
    quickGrid.ColumnWidth = {"1x", "1x", "1x", "1x"};
    quickGrid.RowHeight = {"fit"};
    quickGrid.Padding = [0, 4, 0, 0];
    quickGrid.ColumnSpacing = 8;

    app.HeaderOpenButton = uibutton(quickGrid, "push", "Text", "打开音频", ...
        "ButtonPushedFcn", @(~, ~) safeCallback("openAudio", @() quickOpenAudioCallback()));
    app.HeaderRecordButton = uibutton(quickGrid, "push", "Text", "实时录音", ...
        "ButtonPushedFcn", @(~, ~) safeCallback("recordAudio", @() quickRecordCallback()));
    app.HeaderDemoButton = uibutton(quickGrid, "push", "Text", "运行演示", ...
        "ButtonPushedFcn", @(~, ~) safeCallback("runDemo", @() quickDemoCallback()));
    app.HeaderExportButton = uibutton(quickGrid, "push", "Text", "导出报告", ...
        "ButtonPushedFcn", @(~, ~) safeCallback("exportReport", @() quickExportCallback()));
    styleButton(app.HeaderOpenButton, theme.Primary, [1, 1, 1]);
    styleButton(app.HeaderRecordButton, theme.Secondary, [1, 1, 1]);
    styleButton(app.HeaderDemoButton, [0.12, 0.40, 0.75], [1, 1, 1]);
    styleButton(app.HeaderExportButton, theme.Success, [1, 1, 1]);

    [sourceCard, app.SourceCardValue] = createStatusCard(headerGrid, 2, [0.90, 0.96, 1.00], "当前信号源", "未加载");
    [stageCard, app.StageCardValue] = createStatusCard(headerGrid, 3, [0.93, 0.98, 0.94], "当前阶段", "原始信号");
    [fsCard, app.FsCardValue] = createStatusCard(headerGrid, 4, [1.00, 0.95, 0.89], "采样率", "--");
    [scoreCard, app.ScoreCardValue] = createStatusCard(headerGrid, 5, [0.98, 0.93, 0.97], "质量评分", "--");

    sourceCard.Title = "";
    stageCard.Title = "";
    fsCard.Title = "";
    scoreCard.Title = "";

    app.ControlPanel = uipanel(app.MainGrid, ...
        "Title", "控制中心", ...
        "FontWeight", "bold", ...
        "ForegroundColor", theme.Text, ...
        "BackgroundColor", theme.Panel);
    app.ControlPanel.Layout.Row = 2;
    app.ControlPanel.Layout.Column = 1;

    app.VisualPanel = uipanel(app.MainGrid, ...
        "Title", "分析与显示中心", ...
        "FontWeight", "bold", ...
        "ForegroundColor", theme.Text, ...
        "BackgroundColor", theme.Panel);
    app.VisualPanel.Layout.Row = 2;
    app.VisualPanel.Layout.Column = 2;
    makeScrollable(app.VisualPanel);

    app.FooterPanel = uipanel(app.MainGrid, ...
        "Title", "Processing Timeline / Log", ...
        "ForegroundColor", theme.Text, ...
        "BackgroundColor", theme.Panel);
    app.FooterPanel.Layout.Row = 3;
    app.FooterPanel.Layout.Column = [1, 2];

    controlShell = uigridlayout(app.ControlPanel, [4, 1]);
    controlShell.RowHeight = {"fit", "fit", "fit", "1x"};
    controlShell.ColumnWidth = {"1x"};
    controlShell.Padding = [12, 10, 12, 12];
    controlShell.RowSpacing = 10;
    app.ControlHeaderLabel = uilabel(controlShell, ...
        "Text", "Control Center  ·  输入、降噪、变声、调制与预设", ...
        "FontSize", 13, ...
        "FontWeight", "bold", ...
        "FontColor", theme.Text, ...
        "FontName", "Microsoft YaHei");
    app.ControlHeaderLabel.Layout.Row = 1;
    app.ControlHeaderLabel.WordWrap = "on";
    app.ControlTabHintLabel = uilabel(controlShell, ...
        "Text", "信号源  |  处理链  |  高级功能  |  变声器", ...
        "FontSize", 11, ...
        "FontColor", theme.Muted, ...
        "FontName", "Microsoft YaHei");
    app.ControlTabHintLabel.Layout.Row = 2;
    app.ControlTabHintLabel.WordWrap = "on";
    controlNavGrid = uigridlayout(controlShell, [1, 4]);
    controlNavGrid.Layout.Row = 3;
    controlNavGrid.ColumnWidth = {"1x", "1x", "1x", "1x"};
    controlNavGrid.RowHeight = {"fit"};
    controlNavGrid.Padding = [0, 0, 0, 0];
    controlNavGrid.ColumnSpacing = 8;
    app.ControlNavSourceButton = uibutton(controlNavGrid, "push", "Text", "信号源", "ButtonPushedFcn", @(~, ~) selectControlTab("source"));
    app.ControlNavProcessButton = uibutton(controlNavGrid, "push", "Text", "处理链", "ButtonPushedFcn", @(~, ~) selectControlTab("process"));
    app.ControlNavAdvancedButton = uibutton(controlNavGrid, "push", "Text", "高级功能", "ButtonPushedFcn", @(~, ~) selectControlTab("advanced"));
    app.ControlNavVoiceButton = uibutton(controlNavGrid, "push", "Text", "变声器", "ButtonPushedFcn", @(~, ~) selectControlTab("voice"));
    styleButton(app.ControlNavSourceButton, [0.24, 0.45, 0.78], [1, 1, 1]);
    styleButton(app.ControlNavProcessButton, [0.78, 0.35, 0.20], [1, 1, 1]);
    styleButton(app.ControlNavAdvancedButton, [0.20, 0.55, 0.48], [1, 1, 1]);
    styleButton(app.ControlNavVoiceButton, [0.56, 0.31, 0.74], [1, 1, 1]);
    app.ControlTabs = uitabgroup(controlShell);
    app.ControlTabs.Layout.Row = 4;
    try, app.ControlTabs.BackgroundColor = theme.Card; catch, end

    app.SourceTab = uitab(app.ControlTabs, "Title", "信号源");
    app.ProcessTab = uitab(app.ControlTabs, "Title", "处理链");
    app.AdvancedTab = uitab(app.ControlTabs, "Title", "高级功能");

    app.VoiceTab = uitab(app.ControlTabs, "Title", "变声器");

    makeScrollable(app.SourceTab);
    makeScrollable(app.ProcessTab);
    makeScrollable(app.AdvancedTab);
    makeScrollable(app.VoiceTab);
    buildSourceTab();
    buildProcessTab();
    buildVoiceTab();
    buildAdvancedTab();

    visualShell = uigridlayout(app.VisualPanel, [4, 1]);
    visualShell.RowHeight = {"fit", "fit", "fit", "1x"};
    visualShell.ColumnWidth = {"1x"};
    visualShell.Padding = [12, 10, 12, 12];
    visualShell.RowSpacing = 10;
    makeScrollable(visualShell);
    app.VisualHeaderLabel = uilabel(visualShell, ...
        "Text", "Visualization Workspace  ·  Dashboard / Time-Frequency / Voice / Compare", ...
        "FontSize", 13, ...
        "FontWeight", "bold", ...
        "FontColor", theme.Text, ...
        "FontName", "Microsoft YaHei");
    app.VisualHeaderLabel.Layout.Row = 1;
    app.VisualHeaderLabel.WordWrap = "on";
    app.VisualTabHintLabel = uilabel(visualShell, ...
        "Text", "总览 Dashboard  |  高级分析  |  变声分析  |  调制通信  |  A/B 对比  |  报告导出", ...
        "FontSize", 11, ...
        "FontColor", theme.Muted, ...
        "FontName", "Microsoft YaHei");
    app.VisualTabHintLabel.Layout.Row = 2;
    app.VisualTabHintLabel.WordWrap = "on";
    visualNavGrid = uigridlayout(visualShell, [1, 6]);
    visualNavGrid.Layout.Row = 3;
    visualNavGrid.ColumnWidth = {"1x", "1x", "1x", "1x", "1x", "1x"};
    visualNavGrid.RowHeight = {"fit"};
    visualNavGrid.Padding = [0, 0, 0, 0];
    visualNavGrid.ColumnSpacing = 8;
    app.VisualNavOverviewButton = uibutton(visualNavGrid, "push", "Text", "总览", "ButtonPushedFcn", @(~, ~) selectVisualTab("overview"));
    app.VisualNavAnalysisButton = uibutton(visualNavGrid, "push", "Text", "高级分析", "ButtonPushedFcn", @(~, ~) selectVisualTab("analysis"));
    app.VisualNavVoiceButton = uibutton(visualNavGrid, "push", "Text", "变声分析", "ButtonPushedFcn", @(~, ~) selectVisualTab("voice"));
    app.VisualNavModulationButton = uibutton(visualNavGrid, "push", "Text", "调制通信", "ButtonPushedFcn", @(~, ~) selectVisualTab("modulation"));
    app.VisualNavCompareButton = uibutton(visualNavGrid, "push", "Text", "A/B 对比", "ButtonPushedFcn", @(~, ~) selectVisualTab("compare"));
    app.VisualNavExportButton = uibutton(visualNavGrid, "push", "Text", "报告导出", "ButtonPushedFcn", @(~, ~) selectVisualTab("export"));
    styleButton(app.VisualNavOverviewButton, [0.24, 0.45, 0.78], [1, 1, 1]);
    styleButton(app.VisualNavAnalysisButton, [0.30, 0.38, 0.62], [1, 1, 1]);
    styleButton(app.VisualNavVoiceButton, [0.56, 0.31, 0.74], [1, 1, 1]);
    styleButton(app.VisualNavModulationButton, [0.78, 0.35, 0.20], [1, 1, 1]);
    styleButton(app.VisualNavCompareButton, [0.20, 0.55, 0.48], [1, 1, 1]);
    styleButton(app.VisualNavExportButton, [0.18, 0.67, 0.33], [1, 1, 1]);
    app.VisualTabs = uitabgroup(visualShell);
    app.VisualTabs.Layout.Row = 4;
    makeScrollable(app.VisualTabs);
    try, app.VisualTabs.BackgroundColor = theme.Card; catch, end

    app.OverviewTab = uitab(app.VisualTabs, "Title", "总览");
    app.AnalysisTab = uitab(app.VisualTabs, "Title", "高级分析");
    app.CompareTab = uitab(app.VisualTabs, "Title", "A/B 对比");

    app.VoiceVisualTab = uitab(app.VisualTabs, "Title", "变声分析");

    makeScrollable(app.OverviewTab);
    makeScrollable(app.AnalysisTab);
    makeScrollable(app.CompareTab);
    makeScrollable(app.VoiceVisualTab);
    buildOverviewTab();
    buildAnalysisTab();
    buildCompareTab();
    buildVoiceVisualTab();
    app.ModulationVisualTab = uitab(app.VisualTabs, "Title", "调制通信");
    app.ExportVisualTab = uitab(app.VisualTabs, "Title", "报告导出");
    makeScrollable(app.ModulationVisualTab);
    makeScrollable(app.ExportVisualTab);
    buildModulationVisualTab();
    buildExportVisualTab();
    buildFooterPanel();
    app.ControlTabs.SelectedTab = app.ProcessTab;
    app.VisualTabs.SelectedTab = app.ModulationVisualTab;
    applyDarkThemeToTree(app.Figure);
    applyDarkAxesTheme();
    updateResponsiveLayout();
    if isVisible
        try
            app.Figure.WindowState = "maximized";
            drawnow;
            updateResponsiveLayout();
        catch
        end
    end

    refreshAllViews();
    if autoDemo
        runDemoCallback();
    end

    function buildSourceTab()
        sourceGrid = uigridlayout(app.SourceTab, [4, 1]);
        sourceGrid.RowHeight = {230, 330, 185, "1x"};
        sourceGrid.ColumnWidth = {"1x"};
        sourceGrid.Padding = [14, 14, 14, 14];
        sourceGrid.RowSpacing = 12;
        makeScrollable(sourceGrid);

        inputPanel = uipanel(sourceGrid, "Title", "1. 信号读取模块", "BackgroundColor", [1, 1, 1]);
        inputPanel.Layout.Row = 1;
        inputPanel.Layout.Column = 1;
        inputGrid = uigridlayout(inputPanel, [6, 2]);
        inputGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "fit"};
        inputGrid.ColumnWidth = {"1x", "1x"};
        inputGrid.Padding = [12, 10, 12, 10];
        inputGrid.RowSpacing = 8;
        inputGrid.ColumnSpacing = 10;

        uilabel(inputGrid, "Text", "样例语音", "FontWeight", "bold");
        app.SampleDropDown = uidropdown(inputGrid, ...
            "Items", ["样例语音 1", "样例语音 2"], ...
            "ItemsData", ["sample1", "sample2"], ...
            "Value", "sample1");
        app.SampleDropDown.Layout.Row = 1;
        app.SampleDropDown.Layout.Column = 2;

        app.LoadSampleButton = uibutton(inputGrid, "push", ...
            "Text", "载入样例", ...
            "ButtonPushedFcn", @(~, ~) loadSampleCallback());
        app.LoadSampleButton.Layout.Row = 2;
        app.LoadSampleButton.Layout.Column = 1;
        styleButton(app.LoadSampleButton, [0.10, 0.45, 0.72], [1, 1, 1]);

        app.LoadFileButton = uibutton(inputGrid, "push", ...
            "Text", "打开本地音频", ...
            "ButtonPushedFcn", @(~, ~) loadFileCallback());
        app.LoadFileButton.Layout.Row = 2;
        app.LoadFileButton.Layout.Column = 2;
        styleButton(app.LoadFileButton, [0.18, 0.54, 0.48], [1, 1, 1]);

        uilabel(inputGrid, "Text", "合成时长 / s", "FontWeight", "bold");
        app.SyntheticDurationField = uieditfield(inputGrid, "numeric", ...
            "Value", 3, "Limits", [1, 10], "RoundFractionalValues", "off");
        app.SyntheticDurationField.Layout.Row = 3;
        app.SyntheticDurationField.Layout.Column = 2;

        uilabel(inputGrid, "Text", "合成采样率 / Hz", "FontWeight", "bold");
        app.SyntheticFsField = uieditfield(inputGrid, "numeric", ...
            "Value", 16000, "Limits", [8000, 48000], "RoundFractionalValues", "on");
        app.SyntheticFsField.Layout.Row = 4;
        app.SyntheticFsField.Layout.Column = 2;

        app.GenerateSyntheticButton = uibutton(inputGrid, "push", ...
            "Text", "生成合成信号", ...
            "ButtonPushedFcn", @(~, ~) generateSyntheticCallback());
        app.GenerateSyntheticButton.Layout.Row = 5;
        app.GenerateSyntheticButton.Layout.Column = [1, 2];
        styleButton(app.GenerateSyntheticButton, [0.58, 0.34, 0.72], [1, 1, 1]);

        app.ResetButton = uibutton(inputGrid, "push", ...
            "Text", "重置到原始信号", ...
            "ButtonPushedFcn", @(~, ~) resetToOriginalCallback());
        app.ResetButton.Layout.Row = 6;
        app.ResetButton.Layout.Column = [1, 2];
        styleButton(app.ResetButton, [0.34, 0.37, 0.44], [1, 1, 1]);

        recordPanel = uipanel(sourceGrid, "Title", "2. 录音输入 / 实时采集", "BackgroundColor", [1, 1, 1]);
        recordPanel.Layout.Row = 2;
        recordPanel.Layout.Column = 1;
        recordGrid = uigridlayout(recordPanel, [9, 4]);
        recordGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "fit", "fit", "fit", "1x"};
        recordGrid.ColumnWidth = {"1x", "0.9x", "1x", "0.9x"};
        recordGrid.Padding = [12, 10, 12, 10];
        recordGrid.RowSpacing = 8;
        recordGrid.ColumnSpacing = 10;

        app.RecordSourceLabel = uilabel(recordGrid, ...
            "Text", "输入设备：系统默认麦克风", ...
            "FontWeight", "bold", ...
            "FontColor", [0.09, 0.28, 0.46]);
        app.RecordSourceLabel.Layout.Row = 1;
        app.RecordSourceLabel.Layout.Column = [1, 4];

        uilabel(recordGrid, "Text", "采集模式", "FontWeight", "bold");
        app.CaptureModeDropDown = uidropdown(recordGrid, ...
            "Items", ["限时实时采集", "持续监听"], ...
            "Value", "限时实时采集", ...
            "ValueChangedFcn", @(~, ~) captureModeChangedCallback());
        app.CaptureModeDropDown.Layout.Row = 2;
        app.CaptureModeDropDown.Layout.Column = 2;

        uilabel(recordGrid, "Text", "录音采样率 / Hz", "FontWeight", "bold");
        app.RecordFsField = uieditfield(recordGrid, "numeric", ...
            "Value", state.recordingFs, ...
            "Limits", [8000, 48000], ...
            "RoundFractionalValues", "on");
        app.RecordFsField.Layout.Row = 3;
        app.RecordFsField.Layout.Column = 2;

        uilabel(recordGrid, "Text", "最长录音 / s", "FontWeight", "bold");
        app.RecordMaxDurationField = uieditfield(recordGrid, "numeric", ...
            "Value", state.recordingMaxDuration, ...
            "Limits", [1, 20], ...
            "RoundFractionalValues", "off");
        app.RecordMaxDurationField.Layout.Row = 3;
        app.RecordMaxDurationField.Layout.Column = 4;

        app.StartRecordButton = uibutton(recordGrid, "push", ...
            "Text", "开始采集", ...
            "ButtonPushedFcn", @(~, ~) startRecordingCallback());
        app.StartRecordButton.Layout.Row = 4;
        app.StartRecordButton.Layout.Column = 1;
        styleButton(app.StartRecordButton, [0.04, 0.49, 0.67], [1, 1, 1]);

        app.StopRecordButton = uibutton(recordGrid, "push", ...
            "Text", "停止采集", ...
            "ButtonPushedFcn", @(~, ~) stopRecordingCallback());
        app.StopRecordButton.Layout.Row = 4;
        app.StopRecordButton.Layout.Column = 2;
        styleButton(app.StopRecordButton, [0.74, 0.24, 0.20], [1, 1, 1]);

        app.LoadRecordingButton = uibutton(recordGrid, "push", ...
            "Text", "载入处理链", ...
            "ButtonPushedFcn", @(~, ~) loadRecordingAsSignalCallback());
        app.LoadRecordingButton.Layout.Row = 4;
        app.LoadRecordingButton.Layout.Column = 3;
        styleButton(app.LoadRecordingButton, [0.19, 0.56, 0.42], [1, 1, 1]);

        app.FreezeRecordingButton = uibutton(recordGrid, "push", ...
            "Text", "冻结并载入", ...
            "ButtonPushedFcn", @(~, ~) freezeRecordingCallback());
        app.FreezeRecordingButton.Layout.Row = 4;
        app.FreezeRecordingButton.Layout.Column = 4;
        styleButton(app.FreezeRecordingButton, [0.53, 0.31, 0.72], [1, 1, 1]);

        app.ClearRecordingButton = uibutton(recordGrid, "push", ...
            "Text", "清空缓存", ...
            "ButtonPushedFcn", @(~, ~) clearRecordingBufferCallback());
        app.ClearRecordingButton.Layout.Row = 5;
        app.ClearRecordingButton.Layout.Column = [1, 2];
        styleButton(app.ClearRecordingButton, [0.47, 0.47, 0.51], [1, 1, 1]);

        app.SaveRecordingButton = uibutton(recordGrid, "push", ...
            "Text", "瀵煎嚭褰曢煶", ...
            "ButtonPushedFcn", @(~, ~) saveRecordingBundleCallback());
        app.SaveRecordingButton.Layout.Row = 5;
        app.SaveRecordingButton.Layout.Column = [3, 4];
        styleButton(app.SaveRecordingButton, [0.66, 0.43, 0.12], [1, 1, 1]);

        app.RecordAutoLoadLabel = uilabel(recordGrid, ...
            "Text", "限时模式结束后自动载入处理链，监听模式可手动冻结最近一段语音。", ...
            "WordWrap", "on", ...
            "FontColor", [0.24, 0.28, 0.34]);
        app.RecordAutoLoadLabel.Layout.Row = 6;
        app.RecordAutoLoadLabel.Layout.Column = [1, 4];

        app.RecordStatusLabel = uilabel(recordGrid, ...
            "Text", "状态：空闲", ...
            "FontColor", [0.18, 0.18, 0.18], ...
            "WordWrap", "on");
        app.RecordStatusLabel.Layout.Row = 7;
        app.RecordStatusLabel.Layout.Column = [1, 2];

        app.RecordLevelLabel = uilabel(recordGrid, ...
            "Text", "峰值：0.000 | 时长：0.00 s", ...
            "HorizontalAlignment", "right", ...
            "FontColor", [0.18, 0.18, 0.18], ...
            "WordWrap", "on");
        app.RecordLevelLabel.Layout.Row = 7;
        app.RecordLevelLabel.Layout.Column = [3, 4];

        app.RecordAnalysisArea = uitextarea(recordGrid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["Live analysis status"; "STE: --"; "MainFreq: --"; "Bands: --"]);
        app.RecordAnalysisArea.Layout.Row = 8;
        app.RecordAnalysisArea.Layout.Column = [1, 4];

        app.RecordAxes = uiaxes(recordGrid);
        app.RecordAxes.Layout.Row = 9;
        app.RecordAxes.Layout.Column = [1, 4];
        app.RecordAxes.Color = [0.98, 0.99, 1.00];
        app.RecordAxes.Toolbar.Visible = "off";
        app.RecordAxes.FontName = "Microsoft YaHei";
        title(app.RecordAxes, "录音实时波形预览");
        xlabel(app.RecordAxes, "时间 / s");
        ylabel(app.RecordAxes, "幅值");
        grid(app.RecordAxes, "on");

        controlPanel = uipanel(sourceGrid, "Title", "3. 显示与导出", "BackgroundColor", [1, 1, 1]);
        controlPanel.Layout.Row = 3;
        controlPanel.Layout.Column = 1;
        controlGrid = uigridlayout(controlPanel, [5, 2]);
        controlGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit"};
        controlGrid.ColumnWidth = {"1x", "1x"};
        controlGrid.Padding = [12, 10, 12, 10];
        controlGrid.RowSpacing = 8;
        controlGrid.ColumnSpacing = 10;

        uilabel(controlGrid, "Text", "显示阶段", "FontWeight", "bold");
        app.StageDropDown = uidropdown(controlGrid, ...
            "Items", "原始信号", ...
            "ItemsData", "original", ...
            "Value", "original", ...
            "ValueChangedFcn", @(~, ~) refreshAllViews());
        app.StageDropDown.Layout.Row = 1;
        app.StageDropDown.Layout.Column = 2;

        app.PlayButton = uibutton(controlGrid, "push", ...
            "Text", "播放当前阶段", ...
            "ButtonPushedFcn", @(~, ~) playCurrentCallback());
        app.PlayButton.Layout.Row = 2;
        app.PlayButton.Layout.Column = 1;
        styleButton(app.PlayButton, [0.07, 0.48, 0.67], [1, 1, 1]);

        app.SaveButton = uibutton(controlGrid, "push", ...
            "Text", "导出 WAV", ...
            "ButtonPushedFcn", @(~, ~) saveCurrentCallback());
        app.SaveButton.Layout.Row = 2;
        app.SaveButton.Layout.Column = 2;
        styleButton(app.SaveButton, [0.25, 0.55, 0.33], [1, 1, 1]);

        app.ExportDashboardButton = uibutton(controlGrid, "push", ...
            "Text", "导出仪表盘截图", ...
            "ButtonPushedFcn", @(~, ~) exportDashboardCallback());
        app.ExportDashboardButton.Layout.Row = 3;
        app.ExportDashboardButton.Layout.Column = 1;
        styleButton(app.ExportDashboardButton, [0.72, 0.43, 0.13], [1, 1, 1]);

        app.DemoButton = uibutton(controlGrid, "push", ...
            "Text", "一键演示整条流程", ...
            "ButtonPushedFcn", @(~, ~) runDemoCallback());
        app.DemoButton.Layout.Row = 3;
        app.DemoButton.Layout.Column = 2;
        styleButton(app.DemoButton, [0.57, 0.20, 0.33], [1, 1, 1]);

        app.ExportMetricsButton = uibutton(controlGrid, "push", ...
            "Text", "导出指标 CSV", ...
            "ButtonPushedFcn", @(~, ~) exportCurrentMetricsCsvCallback());
        app.ExportMetricsButton.Layout.Row = 4;
        app.ExportMetricsButton.Layout.Column = 1;
        styleButton(app.ExportMetricsButton, [0.13, 0.55, 0.44], [1, 1, 1]);

        app.ExportMetricsSnapshotButton = uibutton(controlGrid, "push", ...
            "Text", "导出指标截图", ...
            "ButtonPushedFcn", @(~, ~) exportMetricsSnapshotCallback());
        app.ExportMetricsSnapshotButton.Layout.Row = 4;
        app.ExportMetricsSnapshotButton.Layout.Column = 2;
        styleButton(app.ExportMetricsSnapshotButton, [0.66, 0.34, 0.11], [1, 1, 1]);

        app.MetricLabel = uilabel(controlGrid, ...
            "Text", "指标：尚未载入信号", ...
            "WordWrap", "on", ...
            "FontColor", [0.18, 0.18, 0.18]);
        app.MetricLabel.Layout.Row = 5;
        app.MetricLabel.Layout.Column = [1, 2];

        infoPanel = uipanel(sourceGrid, "Title", "4. 当前任务说明", "BackgroundColor", [1, 1, 1]);
        infoPanel.Layout.Row = 4;
        infoPanel.Layout.Column = 1;
        infoGrid = uigridlayout(infoPanel, [1, 1]);
        infoGrid.Padding = [12, 10, 12, 10];

        app.SignalInfoArea = uitextarea(infoGrid, ...
            "Editable", "off", ...
            "Value", ["尚未加载信号。"; "完成处理后，这里会显示来源、阶段链路和关键指标。"], ...
            "FontName", "Consolas");
        app.SignalInfoArea.Layout.Row = 1;
        app.SignalInfoArea.Layout.Column = 1;
    end

    function buildProcessTab()
        grid = uigridlayout(app.ProcessTab, [4, 1]);
        grid.RowHeight = {500, 190, 230, 275};
        grid.ColumnWidth = {"1x"};
        grid.Padding = [14, 14, 14, 14];
        grid.RowSpacing = 12;
        makeScrollable(grid);

        noisePanel = uipanel(grid, "Title", "2. 噪声添加模块", "BackgroundColor", [1, 1, 1]);
        noisePanel.Layout.Row = 2;
        noisePanel.Layout.Column = 1;
        noiseGrid = uigridlayout(noisePanel, [4, 2]);
        noiseGrid.RowHeight = {"fit", "fit", "fit", "fit"};
        noiseGrid.ColumnWidth = {"1x", "1x"};
        noiseGrid.Padding = [12, 10, 12, 10];
        noiseGrid.RowSpacing = 8;

        uilabel(noiseGrid, "Text", "噪声类型", "FontWeight", "bold");
        app.NoiseDropDown = uidropdown(noiseGrid, ...
            "Items", ["白噪声", "工频干扰", "混合噪声"], ...
            "Value", "混合噪声");
        app.NoiseDropDown.Layout.Row = 1;
        app.NoiseDropDown.Layout.Column = 2;

        uilabel(noiseGrid, "Text", "噪声等级", "FontWeight", "bold");
        app.NoiseLevelSlider = uislider(noiseGrid, ...
            "Limits", [0.02, 0.45], ...
            "Value", 0.18, ...
            "MajorTicks", [0.05, 0.15, 0.25, 0.35, 0.45]);
        app.NoiseLevelSlider.Layout.Row = 2;
        app.NoiseLevelSlider.Layout.Column = 2;

        app.AddNoiseButton = uibutton(noiseGrid, "push", ...
            "Text", "添加噪声", ...
            "ButtonPushedFcn", @(~, ~) addNoiseCallback());
        app.AddNoiseButton.Layout.Row = 4;
        app.AddNoiseButton.Layout.Column = [1, 2];
        styleButton(app.AddNoiseButton, [0.84, 0.44, 0.18], [1, 1, 1]);

        filterPanel = uipanel(grid, "Title", "3. 滤波器去噪模块", "BackgroundColor", [1, 1, 1]);
        filterPanel.Layout.Row = 3;
        filterPanel.Layout.Column = 1;
        filterGrid = uigridlayout(filterPanel, [6, 2]);
        filterGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "fit"};
        filterGrid.ColumnWidth = {"1x", "1x"};
        filterGrid.Padding = [12, 10, 12, 10];
        filterGrid.RowSpacing = 8;

        uilabel(filterGrid, "Text", "滤波器类型", "FontWeight", "bold");
        app.FilterDropDown = uidropdown(filterGrid, ...
            "Items", ["Butterworth低通", "Chebyshev高通", "语音带通", "FIR低通", "陷波", "Median", "小波去噪"], ...
            "Value", "Butterworth低通", ...
            "ValueChangedFcn", @(~, ~) refreshAnalysisViews());
        app.FilterDropDown.Layout.Row = 1;
        app.FilterDropDown.Layout.Column = 2;

        uilabel(filterGrid, "Text", "工作模式", "FontWeight", "bold");
        app.FilterModeDropDown = uidropdown(filterGrid, ...
            "Items", ["预览", "应用"], ...
            "Value", "预览", ...
            "ValueChangedFcn", @(~, ~) refreshAnalysisViews());
        app.FilterModeDropDown.Layout.Row = 2;
        app.FilterModeDropDown.Layout.Column = 2;

        uilabel(filterGrid, "Text", "关键频率 / Hz", "FontWeight", "bold");
        app.FilterCutoffField = uieditfield(filterGrid, "numeric", ...
            "Value", 2200, "Limits", [50, 6000], "ValueChangedFcn", @(~, ~) refreshAnalysisViews());
        app.FilterCutoffField.Layout.Row = 3;
        app.FilterCutoffField.Layout.Column = 2;

        uilabel(filterGrid, "Text", "滤波器阶数", "FontWeight", "bold");
        app.FilterOrderField = uieditfield(filterGrid, "numeric", ...
            "Value", 6, "RoundFractionalValues", "on", "Limits", [2, 10], ...
            "ValueChangedFcn", @(~, ~) refreshAnalysisViews());
        app.FilterOrderField.Layout.Row = 4;
        app.FilterOrderField.Layout.Column = 2;

        uilabel(filterGrid, "Text", "通带上边界 / Hz", "FontWeight", "bold");
        app.FilterHighField = uieditfield(filterGrid, "numeric", ...
            "Value", 3400, "Limits", [300, 7000], "ValueChangedFcn", @(~, ~) refreshAnalysisViews());
        app.FilterHighField.Layout.Row = 5;
        app.FilterHighField.Layout.Column = 2;

        app.FilterButton = uibutton(filterGrid, "push", ...
            "Text", "应用滤波", ...
            "ButtonPushedFcn", @(~, ~) filterCallback());
        app.FilterButton.Layout.Row = 6;
        app.FilterButton.Layout.Column = [1, 2];
        styleButton(app.FilterButton, [0.22, 0.57, 0.37], [1, 1, 1]);

        effectPanel = uipanel(grid, "Title", "4. 变声 / 语音加密模块", "BackgroundColor", [1, 1, 1]);
        effectPanel.Layout.Row = 4;
        effectPanel.Layout.Column = 1;
        effectGrid = uigridlayout(effectPanel, [8, 2]);
        effectGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "fit", "fit", "fit"};
        effectGrid.ColumnWidth = {"1x", "1x"};
        effectGrid.Padding = [12, 10, 12, 10];
        effectGrid.RowSpacing = 8;

        uilabel(effectGrid, "Text", "功能类型", "FontWeight", "bold");
        app.EffectDropDown = uidropdown(effectGrid, ...
            "Items", ["原声", "男声", "女声", "机器人", "电话音", "回声", "怪兽音", "自定义 EQ", "语音加密", "语音解密"], ...
            "Value", "机器人");
        app.EffectDropDown.Layout.Row = 1;
        app.EffectDropDown.Layout.Column = 2;

        uilabel(effectGrid, "Text", "音调 / 半音", "FontWeight", "bold");
        app.PitchShiftSlider = uislider(effectGrid, ...
            "Limits", [-12, 12], ...
            "Value", 5, ...
            "MajorTicks", [-12, -6, 0, 6, 12]);
        app.PitchShiftSlider.Layout.Row = 2;
        app.PitchShiftSlider.Layout.Column = 2;

        uilabel(effectGrid, "Text", "语速倍数", "FontWeight", "bold");
        app.SpeedSlider = uislider(effectGrid, ...
            "Limits", [0.5, 2.0], ...
            "Value", 1.0, ...
            "MajorTicks", [0.5, 1.0, 1.5, 2.0]);
        app.SpeedSlider.Layout.Row = 3;
        app.SpeedSlider.Layout.Column = 2;

        uilabel(effectGrid, "Text", "回声强度", "FontWeight", "bold");
        app.EchoStrengthSlider = uislider(effectGrid, ...
            "Limits", [0, 0.9], ...
            "Value", 0.45, ...
            "MajorTicks", [0, 0.3, 0.6, 0.9]);
        app.EchoStrengthSlider.Layout.Row = 4;
        app.EchoStrengthSlider.Layout.Column = 2;

        uilabel(effectGrid, "Text", "调制频率 / Hz", "FontWeight", "bold");
        app.ModFreqSlider = uislider(effectGrid, ...
            "Limits", [20, 100], ...
            "Value", 85, ...
            "MajorTicks", [20, 40, 60, 80, 100]);
        app.ModFreqSlider.Layout.Row = 5;
        app.ModFreqSlider.Layout.Column = 2;

        uilabel(effectGrid, "Text", "EQ 增益 [dB]", "FontWeight", "bold");
        app.EQPresetField = uieditfield(effectGrid, "text", ...
            "Value", "0,0,3,2,1");
        app.EQPresetField.Layout.Row = 6;
        app.EQPresetField.Layout.Column = 2;

        uilabel(effectGrid, "Text", "加密帧长", "FontWeight", "bold");
        app.FrameLengthField = uieditfield(effectGrid, "numeric", ...
            "Value", 1024, "RoundFractionalValues", "on", "Limits", [256, 4096]);
        app.FrameLengthField.Layout.Row = 7;
        app.FrameLengthField.Layout.Column = 2;

        app.ApplyEffectButton = uibutton(effectGrid, "push", ...
            "Text", "应用变声/功能", ...
            "ButtonPushedFcn", @(~, ~) effectCallback());
        app.ApplyEffectButton.Layout.Row = 8;
        app.ApplyEffectButton.Layout.Column = [1, 2];
        styleButton(app.ApplyEffectButton, [0.58, 0.30, 0.73], [1, 1, 1]);

        modulationPanel = uipanel(grid, "Title", "1. 调制与解调模块", "BackgroundColor", [1, 1, 1]);
        modulationPanel.Layout.Row = 1;
        modulationPanel.Layout.Column = 1;
        makeScrollable(modulationPanel);
        modulationGrid = uigridlayout(modulationPanel, [11, 2]);
        modulationGrid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "fit", 84, "fit", "fit", "fit", "fit"};
        modulationGrid.ColumnWidth = {"1x", "1x"};
        modulationGrid.Padding = [12, 10, 12, 10];
        modulationGrid.RowSpacing = 5;
        modulationGrid.ColumnSpacing = 10;
        makeScrollable(modulationGrid);

        uilabel(modulationGrid, "Text", "调制方式", "FontWeight", "bold");
        app.ModulationDropDown = uidropdown(modulationGrid, ...
            "Items", ["AM调幅", "FM调频", "ASK", "FSK", "BPSK", "QPSK"], ...
            "Value", "AM调幅");
        app.ModulationDropDown.Layout.Row = 1;
        app.ModulationDropDown.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "载波频率 / Hz", "FontWeight", "bold");
        app.CarrierField = uieditfield(modulationGrid, "numeric", ...
            "Value", 2200, "Limits", [400, 6000]);
        app.CarrierField.Layout.Row = 2;
        app.CarrierField.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "调制度 / 频偏", "FontWeight", "bold");
        app.ModulationIndexField = uieditfield(modulationGrid, "numeric", ...
            "Value", 0.75, "Limits", [0.1, 500]);
        app.ModulationIndexField.Layout.Row = 3;
        app.ModulationIndexField.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "信道 SNR / dB", "FontWeight", "bold");
        app.ChannelSnrField = uieditfield(modulationGrid, "numeric", ...
            "Value", 18, "Limits", [0, 40]);
        app.ChannelSnrField.Layout.Row = 4;
        app.ChannelSnrField.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "符号率", "FontWeight", "bold");
        app.SymbolRateField = uieditfield(modulationGrid, "numeric", ...
            "Value", 1000, "Limits", [100, 4000]);
        app.SymbolRateField.Layout.Row = 5;
        app.SymbolRateField.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "比特数", "FontWeight", "bold");
        app.BitCountField = uieditfield(modulationGrid, "numeric", ...
            "Value", 1000, "Limits", [64, 20000], "RoundFractionalValues", "on");
        app.BitCountField.Layout.Row = 6;
        app.BitCountField.Layout.Column = 2;

        uilabel(modulationGrid, "Text", "输入比特序列（留空则随机生成）", "FontWeight", "bold");
        app.BitSequenceArea = uitextarea(modulationGrid, ...
            "FontName", "Consolas", ...
            "Value", [""], ...
            "Placeholder", "例如：101100111000");
        app.BitSequenceArea.Layout.Row = 7;
        app.BitSequenceArea.Layout.Column = 2;

        app.GenerateBitsButton = uibutton(modulationGrid, "push", ...
            "Text", "生成随机比特", ...
            "ButtonPushedFcn", @(~, ~) safeCallback("generateRandomBitsCallback", @() generateRandomBitsCallback()));
        app.GenerateBitsButton.Layout.Row = 8;
        app.GenerateBitsButton.Layout.Column = 1;
        styleButton(app.GenerateBitsButton, [0.48, 0.30, 0.74], [1, 1, 1]);

        app.ChannelNoiseButton = uibutton(modulationGrid, "push", ...
            "Text", "仅加入信道噪声", ...
            "ButtonPushedFcn", @(~, ~) safeCallback("applyChannelNoiseOnlyCallback", @() applyChannelNoiseOnlyCallback()));
        app.ChannelNoiseButton.Layout.Row = 8;
        app.ChannelNoiseButton.Layout.Column = 2;
        styleButton(app.ChannelNoiseButton, [0.62, 0.36, 0.10], [1, 1, 1]);

        app.ModulateButton = uibutton(modulationGrid, "push", ...
            "Text", "运行通信链", ...
            "ButtonPushedFcn", @(~, ~) modulateCallback());
        app.ModulateButton.Layout.Row = 9;
        app.ModulateButton.Layout.Column = 1;
        styleButton(app.ModulateButton, [0.71, 0.22, 0.24], [1, 1, 1]);

        app.DemodulateButton = uibutton(modulationGrid, "push", ...
            "Text", "仅解调模拟链", ...
            "ButtonPushedFcn", @(~, ~) demodulateCallback());
        app.DemodulateButton.Layout.Row = 9;
        app.DemodulateButton.Layout.Column = 2;
        styleButton(app.DemodulateButton, [0.11, 0.39, 0.60], [1, 1, 1]);

        app.ShowConstellationButton = uibutton(modulationGrid, "push", ...
            "Text", "显示星座图", ...
            "ButtonPushedFcn", @(~, ~) safeCallback("showConstellationCallback", @() showConstellationCallback()));
        app.ShowConstellationButton.Layout.Row = 10;
        app.ShowConstellationButton.Layout.Column = 1;
        styleButton(app.ShowConstellationButton, [0.15, 0.55, 0.48], [1, 1, 1]);

        app.CalculateBerButton = uibutton(modulationGrid, "push", ...
            "Text", "计算 BER", ...
            "ButtonPushedFcn", @(~, ~) safeCallback("calculateBerCallback", @() calculateBerCallback()));
        app.CalculateBerButton.Layout.Row = 10;
        app.CalculateBerButton.Layout.Column = 2;
        styleButton(app.CalculateBerButton, [0.63, 0.23, 0.23], [1, 1, 1]);

        app.CommStatusLabel = uilabel(modulationGrid, ...
            "Text", "通信链状态：尚未运行", ...
            "WordWrap", "on");
        app.CommStatusLabel.Layout.Row = 11;
        app.CommStatusLabel.Layout.Column = [1, 2];
    end

    function buildAdvancedTab()
        grid = uigridlayout(app.AdvancedTab, [4, 1]);
        grid.RowHeight = {190, 170, 150, "1x"};
        grid.ColumnWidth = {"1x"};
        grid.Padding = [14, 14, 14, 14];
        grid.RowSpacing = 12;
        makeScrollable(grid);

        recommendationPanel = uipanel(grid, "Title", "1. 智能推荐", "BackgroundColor", [1, 1, 1]);
        recommendationPanel.Layout.Row = 1;
        recommendationPanel.Layout.Column = 1;
        recommendationGrid = uigridlayout(recommendationPanel, [3, 2]);
        recommendationGrid.RowHeight = {90, "fit", "fit"};
        recommendationGrid.ColumnWidth = {"1x", "1x"};
        recommendationGrid.Padding = [12, 10, 12, 10];
        recommendationGrid.RowSpacing = 8;
        recommendationGrid.ColumnSpacing = 10;

        app.RecommendationArea = uitextarea(recommendationGrid, ...
            "Editable", "off", ...
            "Value", state.recommendation.summary, ...
            "FontName", "Consolas");
        app.RecommendationArea.Layout.Row = 1;
        app.RecommendationArea.Layout.Column = [1, 2];

        app.AnalyzeButton = uibutton(recommendationGrid, "push", ...
            "Text", "分析当前信号", ...
            "ButtonPushedFcn", @(~, ~) analyzeSignalCallback());
        app.AnalyzeButton.Layout.Row = 2;
        app.AnalyzeButton.Layout.Column = 1;
        styleButton(app.AnalyzeButton, [0.20, 0.47, 0.77], [1, 1, 1]);

        app.ApplyRecommendationButton = uibutton(recommendationGrid, "push", ...
            "Text", "加载推荐参数", ...
            "ButtonPushedFcn", @(~, ~) applyRecommendationCallback());
        app.ApplyRecommendationButton.Layout.Row = 2;
        app.ApplyRecommendationButton.Layout.Column = 2;
        styleButton(app.ApplyRecommendationButton, [0.18, 0.56, 0.38], [1, 1, 1]);

        app.ApplyRecommendedFilterButton = uibutton(recommendationGrid, "push", ...
            "Text", "直接应用推荐滤波", ...
            "ButtonPushedFcn", @(~, ~) applyRecommendedFilterCallback());
        app.ApplyRecommendedFilterButton.Layout.Row = 3;
        app.ApplyRecommendedFilterButton.Layout.Column = 1;
        styleButton(app.ApplyRecommendedFilterButton, [0.74, 0.35, 0.17], [1, 1, 1]);

        app.CompareRecommendedButton = uibutton(recommendationGrid, "push", ...
            "Text", "对比滤波前后", ...
            "ButtonPushedFcn", @(~, ~) compareRecommendedResultCallback());
        app.CompareRecommendedButton.Layout.Row = 3;
        app.CompareRecommendedButton.Layout.Column = 2;
        styleButton(app.CompareRecommendedButton, [0.45, 0.28, 0.67], [1, 1, 1]);

        enhancePanel = uipanel(grid, "Title", "2. 高级增强", "BackgroundColor", [1, 1, 1]);
        enhancePanel.Layout.Row = 2;
        enhancePanel.Layout.Column = 1;
        enhanceGrid = uigridlayout(enhancePanel, [4, 2]);
        enhanceGrid.RowHeight = {"fit", "fit", "fit", "fit"};
        enhanceGrid.ColumnWidth = {"1x", "1x"};
        enhanceGrid.Padding = [12, 10, 12, 10];
        enhanceGrid.RowSpacing = 8;

        uilabel(enhanceGrid, "Text", "增强方式", "FontWeight", "bold");
        app.AdvancedMethodDropDown = uidropdown(enhanceGrid, ...
            "Items", ["小波去噪", "自适应陷波", "语音均衡增强"], ...
            "Value", "小波去噪");
        app.AdvancedMethodDropDown.Layout.Row = 1;
        app.AdvancedMethodDropDown.Layout.Column = 2;

        uilabel(enhanceGrid, "Text", "增强强度", "FontWeight", "bold");
        app.AdvancedStrengthSlider = uislider(enhanceGrid, ...
            "Limits", [0.15, 1.00], ...
            "Value", 0.60, ...
            "MajorTicks", [0.2, 0.4, 0.6, 0.8, 1.0]);
        app.AdvancedStrengthSlider.Layout.Row = 2;
        app.AdvancedStrengthSlider.Layout.Column = 2;

        app.AdvancedEnhanceButton = uibutton(enhanceGrid, "push", ...
            "Text", "执行高级增强", ...
            "ButtonPushedFcn", @(~, ~) advancedEnhanceCallback());
        app.AdvancedEnhanceButton.Layout.Row = 4;
        app.AdvancedEnhanceButton.Layout.Column = [1, 2];
        styleButton(app.AdvancedEnhanceButton, [0.58, 0.29, 0.68], [1, 1, 1]);

        exportPanel = uipanel(grid, "Title", "3. 报告素材导出", "BackgroundColor", [1, 1, 1]);
        exportPanel.Layout.Row = 3;
        exportPanel.Layout.Column = 1;
        exportGrid = uigridlayout(exportPanel, [3, 1]);
        exportGrid.RowHeight = {"fit", "fit", "1x"};
        exportGrid.Padding = [12, 10, 12, 10];
        exportGrid.RowSpacing = 8;

        app.ExportMaterialsButton = uibutton(exportGrid, "push", ...
            "Text", "导出实验报告素材", ...
            "ButtonPushedFcn", @(~, ~) exportMaterialsCallback());
        app.ExportMaterialsButton.Layout.Row = 1;
        app.ExportMaterialsButton.Layout.Column = 1;
        styleButton(app.ExportMaterialsButton, [0.71, 0.42, 0.10], [1, 1, 1]);

        app.ExportInfoLabel = uilabel(exportGrid, ...
            "Text", "将导出当前阶段波形、频谱、时频图、变声图、调制图、指标表、WAV 与界面截图到 outputs 时间戳目录。", ...
            "WordWrap", "on", ...
            "FontColor", [0.25, 0.25, 0.25]);
        app.ExportInfoLabel.Layout.Row = 2;
        app.ExportInfoLabel.Layout.Column = 1;

        presetPanel = uipanel(grid, "Title", "4. 场景预设", "BackgroundColor", [1, 1, 1]);
        presetPanel.Layout.Row = 4;
        presetPanel.Layout.Column = 1;
        presetGrid = uigridlayout(presetPanel, [4, 1]);
        presetGrid.RowHeight = {"fit", "fit", "fit", "1x"};
        presetGrid.ColumnWidth = {"1x"};
        presetGrid.Padding = [12, 10, 12, 10];
        presetGrid.RowSpacing = 8;

        app.PresetDropDown = uidropdown(presetGrid, ...
            "Items", ["课堂演示模式", "语音降噪模式", "工频抑制模式", "安全通信模式", "调制通信模式"], ...
            "Value", "课堂演示模式");
        app.PresetDropDown.Layout.Row = 1;
        app.PresetDropDown.Layout.Column = 1;

        app.RunPresetButton = uibutton(presetGrid, "push", ...
            "Text", "运行预设", ...
            "ButtonPushedFcn", @(~, ~) runPresetCallback());
        app.RunPresetButton.Layout.Row = 2;
        app.RunPresetButton.Layout.Column = 1;
        styleButton(app.RunPresetButton, [0.36, 0.38, 0.46], [1, 1, 1]);

        app.PresetInfoLabel = uilabel(presetGrid, ...
            "Text", "预设说明：课堂演示重完整链路，语音降噪重实时分析，工频抑制重陷波，安全通信与调制通信重链路仿真。", ...
            "WordWrap", "on", ...
            "FontColor", [0.25, 0.25, 0.25]);
        app.PresetInfoLabel.Layout.Row = 3;
        app.PresetInfoLabel.Layout.Column = 1;
    end

    function buildVoiceTab()
        grid = uigridlayout(app.VoiceTab, [4, 1]);
        grid.RowHeight = {"fit", "fit", 140, "fit"};
        grid.ColumnWidth = {"1x"};
        grid.Padding = [14, 14, 14, 14];
        grid.RowSpacing = 12;
        makeScrollable(grid);

        modePanel = uipanel(grid, "Title", "1. 变声模式", "BackgroundColor", [1, 1, 1]);
        modePanel.Layout.Row = 1;
        modeGrid = uigridlayout(modePanel, [2, 2]);
        modeGrid.RowHeight = {"fit", "fit"};
        modeGrid.ColumnWidth = {"fit", "1x"};
        modeGrid.Padding = [12, 10, 12, 10];
        modeGrid.RowSpacing = 8;
        modeGrid.ColumnSpacing = 10;

        uilabel(modeGrid, "Text", "模式", "FontWeight", "bold");
        app.VoiceModeDropDown = uidropdown(modeGrid, ...
            "Items", ["原声", "男声", "女声", "机器人音", "电话音 / 对讲机音", "回声音 / 山谷音", "怪兽音", "自定义 EQ"], ...
            "Value", "机器人音", ...
            "ValueChangedFcn", @(~, ~) voiceModeChangedCallback());
        app.VoiceModeDropDown.Layout.Row = 1;
        app.VoiceModeDropDown.Layout.Column = 2;

        uilabel(modeGrid, "Text", "音调 / 半音", "FontWeight", "bold");
        app.VoicePitchSlider = uislider(modeGrid, ...
            "Limits", [-12, 12], ...
            "Value", 5, ...
            "MajorTicks", [-12, -6, 0, 6, 12]);
        app.VoicePitchSlider.Layout.Row = 2;
        app.VoicePitchSlider.Layout.Column = 2;

        parameterPanel = uipanel(grid, "Title", "2. 效果参数", "BackgroundColor", [1, 1, 1]);
        parameterPanel.Layout.Row = 2;
        parameterGrid = uigridlayout(parameterPanel, [2, 4]);
        parameterGrid.RowHeight = {"fit", "fit"};
        parameterGrid.ColumnWidth = {"fit", "1x", "fit", "1x"};
        parameterGrid.Padding = [12, 10, 12, 10];
        parameterGrid.RowSpacing = 8;
        parameterGrid.ColumnSpacing = 10;

        uilabel(parameterGrid, "Text", "回声强度", "FontWeight", "bold");
        app.VoiceEchoStrengthSlider = uislider(parameterGrid, ...
            "Limits", [0, 0.9], ...
            "Value", 0.45, ...
            "MajorTicks", [0, 0.3, 0.6, 0.9]);
        app.VoiceEchoStrengthSlider.Layout.Row = 1;
        app.VoiceEchoStrengthSlider.Layout.Column = 2;

        uilabel(parameterGrid, "Text", "回声延迟 / s", "FontWeight", "bold");
        app.VoiceEchoDelaySlider = uislider(parameterGrid, ...
            "Limits", [0.1, 0.8], ...
            "Value", 0.22, ...
            "MajorTicks", [0.1, 0.3, 0.5, 0.8]);
        app.VoiceEchoDelaySlider.Layout.Row = 1;
        app.VoiceEchoDelaySlider.Layout.Column = 4;

        uilabel(parameterGrid, "Text", "机器人频率 / Hz", "FontWeight", "bold");
        app.VoiceRobotFreqSlider = uislider(parameterGrid, ...
            "Limits", [20, 100], ...
            "Value", 85, ...
            "MajorTicks", [20, 40, 60, 80, 100]);
        app.VoiceRobotFreqSlider.Layout.Row = 2;
        app.VoiceRobotFreqSlider.Layout.Column = 2;

        uilabel(parameterGrid, "Text", "调制深度", "FontWeight", "bold");
        app.VoiceRobotDepthSlider = uislider(parameterGrid, ...
            "Limits", [0, 1], ...
            "Value", 0.90, ...
            "MajorTicks", [0, 0.25, 0.5, 0.75, 1.0]);
        app.VoiceRobotDepthSlider.Layout.Row = 2;
        app.VoiceRobotDepthSlider.Layout.Column = 4;

        eqPanel = uipanel(grid, "Title", "3. 5 段 EQ 增益 / dB", "BackgroundColor", [1, 1, 1]);
        eqPanel.Layout.Row = 3;
        eqGrid = uigridlayout(eqPanel, [2, 5]);
        eqGrid.RowHeight = {"fit", "1x"};
        eqGrid.ColumnWidth = {"1x", "1x", "1x", "1x", "1x"};
        eqGrid.Padding = [12, 10, 12, 10];
        eqGrid.ColumnSpacing = 8;

        uilabel(eqGrid, "Text", "60 Hz", "HorizontalAlignment", "center", "FontWeight", "bold");
        uilabel(eqGrid, "Text", "250 Hz", "HorizontalAlignment", "center", "FontWeight", "bold");
        uilabel(eqGrid, "Text", "1 kHz", "HorizontalAlignment", "center", "FontWeight", "bold");
        uilabel(eqGrid, "Text", "4 kHz", "HorizontalAlignment", "center", "FontWeight", "bold");
        uilabel(eqGrid, "Text", "8 kHz", "HorizontalAlignment", "center", "FontWeight", "bold");

        app.VoiceEQ60Slider = uislider(eqGrid, "Limits", [-12, 12], "Value", 0, "MajorTicks", [-12, 0, 12]);
        app.VoiceEQ60Slider.Layout.Row = 2; app.VoiceEQ60Slider.Layout.Column = 1;
        app.VoiceEQ250Slider = uislider(eqGrid, "Limits", [-12, 12], "Value", 0, "MajorTicks", [-12, 0, 12]);
        app.VoiceEQ250Slider.Layout.Row = 2; app.VoiceEQ250Slider.Layout.Column = 2;
        app.VoiceEQ1kSlider = uislider(eqGrid, "Limits", [-12, 12], "Value", 3, "MajorTicks", [-12, 0, 12]);
        app.VoiceEQ1kSlider.Layout.Row = 2; app.VoiceEQ1kSlider.Layout.Column = 3;
        app.VoiceEQ4kSlider = uislider(eqGrid, "Limits", [-12, 12], "Value", 2, "MajorTicks", [-12, 0, 12]);
        app.VoiceEQ4kSlider.Layout.Row = 2; app.VoiceEQ4kSlider.Layout.Column = 4;
        app.VoiceEQ8kSlider = uislider(eqGrid, "Limits", [-12, 12], "Value", 1, "MajorTicks", [-12, 0, 12]);
        app.VoiceEQ8kSlider.Layout.Row = 2; app.VoiceEQ8kSlider.Layout.Column = 5;

        buttonPanel = uipanel(grid, "Title", "4. 处理与试听", "BackgroundColor", [1, 1, 1]);
        buttonPanel.Layout.Row = 4;
        buttonGrid = uigridlayout(buttonPanel, [2, 3]);
        buttonGrid.RowHeight = {"fit", "fit"};
        buttonGrid.ColumnWidth = {"1x", "1x", "1x"};
        buttonGrid.Padding = [12, 10, 12, 10];
        buttonGrid.RowSpacing = 8;
        buttonGrid.ColumnSpacing = 10;

        app.ApplyVoiceButton = uibutton(buttonGrid, "push", ...
            "Text", "应用变声", ...
            "ButtonPushedFcn", @(~, ~) applyVoiceEffectCallback());
        app.ApplyVoiceButton.Layout.Row = 1; app.ApplyVoiceButton.Layout.Column = 1;
        styleButton(app.ApplyVoiceButton, [0.58, 0.30, 0.73], [1, 1, 1]);

        app.PlayOriginalVoiceButton = uibutton(buttonGrid, "push", ...
            "Text", "播放原声", ...
            "ButtonPushedFcn", @(~, ~) playOriginalVoiceCallback());
        app.PlayOriginalVoiceButton.Layout.Row = 1; app.PlayOriginalVoiceButton.Layout.Column = 2;
        styleButton(app.PlayOriginalVoiceButton, [0.10, 0.45, 0.72], [1, 1, 1]);

        app.PlayProcessedVoiceButton = uibutton(buttonGrid, "push", ...
            "Text", "播放变声后", ...
            "ButtonPushedFcn", @(~, ~) playProcessedVoiceCallback());
        app.PlayProcessedVoiceButton.Layout.Row = 1; app.PlayProcessedVoiceButton.Layout.Column = 3;
        styleButton(app.PlayProcessedVoiceButton, [0.72, 0.24, 0.24], [1, 1, 1]);

        app.CompareVoiceButton = uibutton(buttonGrid, "push", ...
            "Text", "A/B 对比", ...
            "ButtonPushedFcn", @(~, ~) compareVoiceCallback());
        app.CompareVoiceButton.Layout.Row = 2; app.CompareVoiceButton.Layout.Column = 1;
        styleButton(app.CompareVoiceButton, [0.24, 0.55, 0.36], [1, 1, 1]);

        app.SaveVoiceButton = uibutton(buttonGrid, "push", ...
            "Text", "保存变声音频", ...
            "ButtonPushedFcn", @(~, ~) saveVoiceResultCallback());
        app.SaveVoiceButton.Layout.Row = 2; app.SaveVoiceButton.Layout.Column = 2;
        styleButton(app.SaveVoiceButton, [0.64, 0.42, 0.10], [1, 1, 1]);

        app.VoiceInfoLabel = uilabel(buttonGrid, ...
            "Text", "原始波形/频谱与变声后对比会显示在“变声分析”和“A/B 对比”页。", ...
            "WordWrap", "on", ...
            "FontColor", [0.25, 0.25, 0.25]);
        app.VoiceInfoLabel.Layout.Row = 2;
        app.VoiceInfoLabel.Layout.Column = 3;
    end

    function buildVoiceVisualTab()
        grid = uigridlayout(app.VoiceVisualTab, [3, 2]);
        grid.RowHeight = {260, 260, "1x"};
        grid.ColumnWidth = {"1x", "1x"};
        grid.Padding = [12, 12, 12, 12];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        app.VoiceOriginalWaveAxes = uiaxes(grid);
        app.VoiceOriginalWaveAxes.Layout.Row = 1;
        app.VoiceOriginalWaveAxes.Layout.Column = 1;

        app.VoiceProcessedWaveAxes = uiaxes(grid);
        app.VoiceProcessedWaveAxes.Layout.Row = 1;
        app.VoiceProcessedWaveAxes.Layout.Column = 2;

        app.VoiceOriginalSpectrumAxes = uiaxes(grid);
        app.VoiceOriginalSpectrumAxes.Layout.Row = 2;
        app.VoiceOriginalSpectrumAxes.Layout.Column = 1;

        app.VoiceProcessedSpectrumAxes = uiaxes(grid);
        app.VoiceProcessedSpectrumAxes.Layout.Row = 2;
        app.VoiceProcessedSpectrumAxes.Layout.Column = 2;

        app.VoiceDiffSpectrumAxes = uiaxes(grid);
        app.VoiceDiffSpectrumAxes.Layout.Row = 3;
        app.VoiceDiffSpectrumAxes.Layout.Column = 1;

        app.VoiceMetricsArea = uitextarea(grid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["尚未应用变声。"; "载入语音后，在“变声器”页选择模式并点击“应用变声”。"]);
        app.VoiceMetricsArea.Layout.Row = 3;
        app.VoiceMetricsArea.Layout.Column = 2;
    end

    function buildModulationVisualTab()
        grid = uigridlayout(app.ModulationVisualTab, [4, 2]);
        grid.RowHeight = {220, 220, 220, "1x"};
        grid.ColumnWidth = {"1x", "1x"};
        grid.Padding = [12, 12, 12, 12];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        app.CommOriginalAxes = uiaxes(grid);
        app.CommOriginalAxes.Layout.Row = 1;
        app.CommOriginalAxes.Layout.Column = 1;

        app.ModWaveAxes = uiaxes(grid);
        app.ModWaveAxes.Layout.Row = 1;
        app.ModWaveAxes.Layout.Column = 2;

        app.ChannelWaveAxes = uiaxes(grid);
        app.ChannelWaveAxes.Layout.Row = 2;
        app.ChannelWaveAxes.Layout.Column = 1;

        app.DemodWaveAxes = uiaxes(grid);
        app.DemodWaveAxes.Layout.Row = 2;
        app.DemodWaveAxes.Layout.Column = 2;

        app.ModSpectrumAxes = uiaxes(grid);
        app.ModSpectrumAxes.Layout.Row = 3;
        app.ModSpectrumAxes.Layout.Column = 1;

        app.ConstellationAxes = uiaxes(grid);
        app.ConstellationAxes.Layout.Row = 3;
        app.ConstellationAxes.Layout.Column = 2;

        app.BitCompareArea = uitextarea(grid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["尚未运行通信链。"; "BPSK/QPSK/ASK/FSK 运行后，这里会显示比特预览与恢复结果。"]);
        app.BitCompareArea.Layout.Row = 4;
        app.BitCompareArea.Layout.Column = 1;

        app.CommInfoArea = uitextarea(grid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["尚未运行通信链。"; "请选择 AM/FM/ASK/FSK/BPSK/QPSK 后点击“运行通信链”。"]);
        app.CommInfoArea.Layout.Row = 4;
        app.CommInfoArea.Layout.Column = 2;
    end

    function buildExportVisualTab()
        grid = uigridlayout(app.ExportVisualTab, [2, 2]);
        grid.RowHeight = {"1x", 96};
        grid.ColumnWidth = {"1.15x", "1x"};
        grid.Padding = [14, 14, 14, 14];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        checklistPanel = uipanel(grid, "Title", "报告素材清单 Export Checklist", "BackgroundColor", theme.Card, "ForegroundColor", theme.Text);
        checklistPanel.Layout.Row = 1;
        checklistPanel.Layout.Column = 1;
        checklistGrid = uigridlayout(checklistPanel, [9, 2]);
        checklistGrid.RowHeight = repmat({"fit"}, 1, 9);
        checklistGrid.ColumnWidth = {"1x", "1x"};
        checklistGrid.Padding = [14, 12, 14, 12];
        checklistGrid.RowSpacing = 8;
        checklistGrid.ColumnSpacing = 10;

        exportItems = ["原始波形图", "原始频谱图", "加噪结果", "滤波结果", "滤波器频响", ...
            "变声对比", "调制解调结果", "BPSK/QPSK 星座图", "实时录音时频图", ...
            "A/B 对比图", "差分频谱图", "指标 CSV", "界面截图", "处理链历史", "关键 WAV 音频", "导出日志", "场景结果", "报告素材包"];
        app.ExportChecklist = gobjects(numel(exportItems), 1);
        for ii = 1:numel(exportItems)
            cb = uicheckbox(checklistGrid, "Text", exportItems(ii), "Value", true, "FontColor", theme.Text, "FontName", "Microsoft YaHei");
            cb.Layout.Row = ceil(ii / 2);
            cb.Layout.Column = 1 + mod(ii - 1, 2);
            app.ExportChecklist(ii) = cb;
        end

        infoPanel = uipanel(grid, "Title", "导出状态 Export Status", "BackgroundColor", theme.Card, "ForegroundColor", theme.Text);
        infoPanel.Layout.Row = 1;
        infoPanel.Layout.Column = 2;
        infoGrid = uigridlayout(infoPanel, [3, 1]);
        infoGrid.RowHeight = {"fit", "1x", "fit"};
        infoGrid.Padding = [14, 12, 14, 12];
        infoGrid.RowSpacing = 10;

        app.ExportPathLabel = uilabel(infoGrid, "Text", "导出路径：outputs/report_bundle_时间戳", "WordWrap", "on", "FontColor", theme.Muted, "FontName", "Microsoft YaHei");
        app.ExportPathLabel.Layout.Row = 1;
        app.ExportStatusArea = uitextarea(infoGrid, "Editable", "off", "FontName", "Consolas", ...
            "Value", ["尚未导出。"; "点击“一键导出全部素材”后，将自动生成报告素材包。"]);
        app.ExportStatusArea.Layout.Row = 2;
        app.ExportRunButton = uibutton(infoGrid, "push", "Text", "一键导出全部素材", ...
            "ButtonPushedFcn", @(~, ~) safeCallback("exportMaterialsCallback", @() exportMaterialsCallback()));
        app.ExportRunButton.Layout.Row = 3;
        styleButton(app.ExportRunButton, theme.Success, [1, 1, 1]);

        notePanel = uipanel(grid, "Title", "文件命名规范", "BackgroundColor", theme.Card, "ForegroundColor", theme.Text);
        notePanel.Layout.Row = 2;
        notePanel.Layout.Column = [1, 2];
        noteGrid = uigridlayout(notePanel, [1, 1]);
        noteGrid.Padding = [14, 8, 14, 8];
        app.ExportNamingLabel = uilabel(noteGrid, ...
            "Text", "示例：original_waveform.png / filtered_result_spectrum.png / modulation_demodulation_result.png / metrics_summary.csv / app_dashboard_snapshot.png。若某项当前不存在，程序会跳过并记录 warning，不中断导出。", ...
            "WordWrap", "on", "FontColor", theme.Muted, "FontName", "Microsoft YaHei");
    end

    function buildOverviewTab()
        grid = uigridlayout(app.OverviewTab, [3, 2]);
        grid.RowHeight = {280, 280, "1x"};
        grid.ColumnWidth = {"1x", "1x"};
        grid.Padding = [12, 12, 12, 12];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        app.WaveAxes = uiaxes(grid);
        app.WaveAxes.Layout.Row = 1;
        app.WaveAxes.Layout.Column = 1;

        app.SpectrumAxes = uiaxes(grid);
        app.SpectrumAxes.Layout.Row = 1;
        app.SpectrumAxes.Layout.Column = 2;

        app.SpectrogramAxes = uiaxes(grid);
        app.SpectrogramAxes.Layout.Row = 2;
        app.SpectrogramAxes.Layout.Column = 1;

        app.CompareAxes = uiaxes(grid);
        app.CompareAxes.Layout.Row = 2;
        app.CompareAxes.Layout.Column = 2;

        app.LogArea = uitextarea(grid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", state.logMessages);
        app.LogArea.Layout.Row = 3;
        app.LogArea.Layout.Column = [1, 2];
    end

    function buildAnalysisTab()
        grid = uigridlayout(app.AnalysisTab, [2, 2]);
        grid.RowHeight = {290, "1x"};
        grid.ColumnWidth = {"1x", "1x"};
        grid.Padding = [12, 12, 12, 12];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        filterPanel = uipanel(grid, "Title", "滤波器响应预览", "BackgroundColor", [1, 1, 1]);
        filterPanel.Layout.Row = 1;
        filterPanel.Layout.Column = 1;
        filterGrid = uigridlayout(filterPanel, [1, 2]);
        filterGrid.RowHeight = {"1x"};
        filterGrid.ColumnWidth = {"1x", "1x"};
        filterGrid.Padding = [8, 8, 8, 8];
        filterGrid.ColumnSpacing = 10;

        app.FilterResponseAxes = uiaxes(filterGrid);
        app.FilterResponseAxes.Layout.Row = 1;
        app.FilterResponseAxes.Layout.Column = 1;

        app.FilterPhaseAxes = uiaxes(filterGrid);
        app.FilterPhaseAxes.Layout.Row = 1;
        app.FilterPhaseAxes.Layout.Column = 2;

        envelopePanel = uipanel(grid, "Title", "包络与动态分析", "BackgroundColor", [1, 1, 1]);
        envelopePanel.Layout.Row = 1;
        envelopePanel.Layout.Column = 2;
        envelopeGrid = uigridlayout(envelopePanel, [1, 1]);
        envelopeGrid.Padding = [8, 8, 8, 8];

        app.EnvelopeAxes = uiaxes(envelopeGrid);
        app.EnvelopeAxes.Layout.Row = 1;
        app.EnvelopeAxes.Layout.Column = 1;

        historyPanel = uipanel(grid, "Title", "阶段历史指标", "BackgroundColor", [1, 1, 1]);
        historyPanel.Layout.Row = 2;
        historyPanel.Layout.Column = 1;
        historyGrid = uigridlayout(historyPanel, [1, 1]);
        historyGrid.Padding = [8, 8, 8, 8];

        app.StageMetricsTable = uitable(historyGrid, ...
            "ColumnName", {"阶段", "时长(s)", "RMS", "Peak", "主频(Hz)", "SNR(dB)", "相关系数", "评分"}, ...
            "ColumnEditable", false(1, 8));
        app.StageMetricsTable.Layout.Row = 1;
        app.StageMetricsTable.Layout.Column = 1;
        app.StageMetricsTable.ColumnName = {"阶段", "SNR前(dB)", "SNR后(dB)", "提升(dB)", "MSE", "RMSE", "能量前", "能量后", "主频变化(Hz)", "峰值变化(dB)", "评价"};
        app.StageMetricsTable.ColumnEditable = false(1, 11);

        notesPanel = uipanel(grid, "Title", "分析说明", "BackgroundColor", [1, 1, 1]);
        notesPanel.Layout.Row = 2;
        notesPanel.Layout.Column = 2;
        notesGrid = uigridlayout(notesPanel, [1, 1]);
        notesGrid.Padding = [8, 8, 8, 8];

        app.AnalysisNotesArea = uitextarea(notesGrid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["尚未开始分析。"; "这里会展示智能推荐、当前滤波参数和增强策略说明。"]);
        app.AnalysisNotesArea.Layout.Row = 1;
        app.AnalysisNotesArea.Layout.Column = 1;
    end

    function buildCompareTab()
        grid = uigridlayout(app.CompareTab, [5, 3]);
        grid.RowHeight = {"fit", 200, 220, 220, "1x"};
        grid.ColumnWidth = {"1x", "1x", "1x"};
        grid.Padding = [12, 12, 12, 12];
        grid.RowSpacing = 12;
        grid.ColumnSpacing = 12;

        compareControlPanel = uipanel(grid, "BorderType", "none", "BackgroundColor", [0.98, 0.99, 1.00]);
        compareControlPanel.Layout.Row = 1;
        compareControlPanel.Layout.Column = [1, 3];
        compareControlGrid = uigridlayout(compareControlPanel, [3, 5]);
        compareControlGrid.ColumnWidth = {"fit", "1x", "fit", "1x", "fit"};
        compareControlGrid.RowHeight = {"fit", "fit", "fit"};
        compareControlGrid.Padding = [0, 0, 0, 0];
        compareControlGrid.ColumnSpacing = 10;

        uilabel(compareControlGrid, "Text", "A 阶段", "FontWeight", "bold");
        app.CompareStageADropDown = uidropdown(compareControlGrid, ...
            "Items", "原始信号", ...
            "ItemsData", "original", ...
            "Value", "original", ...
            "ValueChangedFcn", @(~, ~) refreshComparisonView());
        app.CompareStageADropDown.Layout.Row = 1;
        app.CompareStageADropDown.Layout.Column = 2;

        uilabel(compareControlGrid, "Text", "B 阶段", "FontWeight", "bold");
        app.CompareStageBDropDown = uidropdown(compareControlGrid, ...
            "Items", "原始信号", ...
            "ItemsData", "original", ...
            "Value", "original", ...
            "ValueChangedFcn", @(~, ~) refreshComparisonView());
        app.CompareStageBDropDown.Layout.Row = 1;
        app.CompareStageBDropDown.Layout.Column = 4;

        app.SwapCompareButton = uibutton(compareControlGrid, "push", ...
            "Text", "交换 A/B", ...
            "ButtonPushedFcn", @(~, ~) swapCompareStagesCallback());
        app.SwapCompareButton.Layout.Row = 1;
        app.SwapCompareButton.Layout.Column = 5;
        styleButton(app.SwapCompareButton, [0.36, 0.40, 0.48], [1, 1, 1]);

        app.PlayAButton = uibutton(compareControlGrid, "push", ...
            "Text", "播放 A", ...
            "ButtonPushedFcn", @(~, ~) playCompareStageCallback("A"));
        app.PlayAButton.Layout.Row = 2;
        app.PlayAButton.Layout.Column = 1;
        styleButton(app.PlayAButton, [0.10, 0.45, 0.72], [1, 1, 1]);

        app.PlayBButton = uibutton(compareControlGrid, "push", ...
            "Text", "播放 B", ...
            "ButtonPushedFcn", @(~, ~) playCompareStageCallback("B"));
        app.PlayBButton.Layout.Row = 2;
        app.PlayBButton.Layout.Column = 2;
        styleButton(app.PlayBButton, [0.72, 0.24, 0.24], [1, 1, 1]);

        app.PlaySwitchButton = uibutton(compareControlGrid, "push", ...
            "Text", "A/B 快切", ...
            "ButtonPushedFcn", @(~, ~) playCompareStageCallback("switch"));
        app.PlaySwitchButton.Layout.Row = 2;
        app.PlaySwitchButton.Layout.Column = 3;
        styleButton(app.PlaySwitchButton, [0.56, 0.30, 0.73], [1, 1, 1]);

        app.PlayDiffButton = uibutton(compareControlGrid, "push", ...
            "Text", "播放差分", ...
            "ButtonPushedFcn", @(~, ~) playCompareStageCallback("diff"));
        app.PlayDiffButton.Layout.Row = 2;
        app.PlayDiffButton.Layout.Column = 4;
        styleButton(app.PlayDiffButton, [0.26, 0.53, 0.36], [1, 1, 1]);

        app.StopPlaybackButton = uibutton(compareControlGrid, "push", ...
            "Text", "停止试听", ...
            "ButtonPushedFcn", @(~, ~) stopPlaybackCallback());
        app.StopPlaybackButton.Layout.Row = 2;
        app.StopPlaybackButton.Layout.Column = 5;
        styleButton(app.StopPlaybackButton, [0.44, 0.44, 0.48], [1, 1, 1]);

        app.ExportCompareBundleButton = uibutton(compareControlGrid, "push", ...
            "Text", "导出对比图", ...
            "ButtonPushedFcn", @(~, ~) exportCompareBundleCallback());
        app.ExportCompareBundleButton.Layout.Row = 3;
        app.ExportCompareBundleButton.Layout.Column = 1;
        styleButton(app.ExportCompareBundleButton, [0.17, 0.54, 0.47], [1, 1, 1]);

        app.ExportCompareMetricsButton = uibutton(compareControlGrid, "push", ...
            "Text", "导出指标表", ...
            "ButtonPushedFcn", @(~, ~) exportCompareMetricsCallback());
        app.ExportCompareMetricsButton.Layout.Row = 3;
        app.ExportCompareMetricsButton.Layout.Column = 2;
        styleButton(app.ExportCompareMetricsButton, [0.62, 0.38, 0.14], [1, 1, 1]);

        app.ExportDiffSpectrumButton = uibutton(compareControlGrid, "push", ...
            "Text", "导出差分频谱", ...
            "ButtonPushedFcn", @(~, ~) exportDiffSpectrumCallback());
        app.ExportDiffSpectrumButton.Layout.Row = 3;
        app.ExportDiffSpectrumButton.Layout.Column = 3;
        styleButton(app.ExportDiffSpectrumButton, [0.55, 0.27, 0.72], [1, 1, 1]);

        app.ExportDiffAudioButton = uibutton(compareControlGrid, "push", ...
            "Text", "导出差分 WAV", ...
            "ButtonPushedFcn", @(~, ~) exportDiffAudioCallback());
        app.ExportDiffAudioButton.Layout.Row = 3;
        app.ExportDiffAudioButton.Layout.Column = 4;
        styleButton(app.ExportDiffAudioButton, [0.24, 0.52, 0.36], [1, 1, 1]);

        app.CompareWaveAAxes = uiaxes(grid);
        app.CompareWaveAAxes.Layout.Row = 2;
        app.CompareWaveAAxes.Layout.Column = 1;

        app.CompareWaveBAxes = uiaxes(grid);
        app.CompareWaveBAxes.Layout.Row = 2;
        app.CompareWaveBAxes.Layout.Column = 2;

        app.CompareDiffWaveAxes = uiaxes(grid);
        app.CompareDiffWaveAxes.Layout.Row = 2;
        app.CompareDiffWaveAxes.Layout.Column = 3;

        app.CompareOverlayAxes = uiaxes(grid);
        app.CompareOverlayAxes.Layout.Row = 3;
        app.CompareOverlayAxes.Layout.Column = [1, 3];

        app.CompareSpectrumAxes = uiaxes(grid);
        app.CompareSpectrumAxes.Layout.Row = 4;
        app.CompareSpectrumAxes.Layout.Column = 1;
        app.CompareSpectrumAAxes = app.CompareSpectrumAxes;

        app.CompareSpectrumBAxes = uiaxes(grid);
        app.CompareSpectrumBAxes.Layout.Row = 4;
        app.CompareSpectrumBAxes.Layout.Column = 2;

        app.CompareInfoArea = uitextarea(grid, ...
            "Editable", "off", ...
            "FontName", "Consolas", ...
            "Value", ["尚未加载足够的阶段数据。"; "完成处理后，可在这里比较任意两个阶段。"]);
        app.CompareInfoArea.Layout.Row = 5;
        app.CompareInfoArea.Layout.Column = [1, 3];

        app.CompareDiffAxes = uiaxes(grid);
        app.CompareDiffAxes.Layout.Row = 4;
        app.CompareDiffAxes.Layout.Column = 3;
    end

    function [panelHandle, valueLabel] = createStatusCard(parent, columnIndex, bgColor, caption, valueText)
        panelHandle = uipanel(parent, ...
            "BorderType", "none", ...
            "BackgroundColor", theme.Card2, ...
            "ForegroundColor", theme.Text);
        panelHandle.Layout.Row = 1;
        panelHandle.Layout.Column = columnIndex;

        grid = uigridlayout(panelHandle, [3, 1]);
        grid.RowHeight = {3, "fit", "fit"};
        grid.ColumnWidth = {"1x"};
        grid.Padding = [12, 8, 12, 10];
        grid.RowSpacing = 4;

        accentBar = uipanel(grid, "BorderType", "none", "BackgroundColor", bgColor);
        accentBar.Layout.Row = 1;
        accentBar.Layout.Column = 1;

        captionLabel = uilabel(grid, ...
            "Text", caption, ...
            "FontSize", 11, ...
            "FontWeight", "bold", ...
            "FontColor", theme.Muted, ...
            "FontName", "Microsoft YaHei");
        captionLabel.Layout.Row = 2;
        captionLabel.Layout.Column = 1;

        valueLabel = uilabel(grid, ...
            "Text", valueText, ...
            "FontSize", 20, ...
            "FontWeight", "bold", ...
            "FontColor", bgColor, ...
            "FontName", "Microsoft YaHei");
        valueLabel.Layout.Row = 3;
        valueLabel.Layout.Column = 1;
    end

    function buildFooterPanel()
        footerGrid = uigridlayout(app.FooterPanel, [1, 2]);
        footerGrid.ColumnWidth = {"1.35x", "1x"};
        footerGrid.RowHeight = {"1x"};
        footerGrid.Padding = [12, 8, 12, 10];
        footerGrid.ColumnSpacing = 12;
        app.FooterGrid = footerGrid;

        timelinePanel = uipanel(footerGrid, "Title", "Processing Timeline", "BackgroundColor", theme.Card, "ForegroundColor", theme.Text);
        timelinePanel.Layout.Row = 1;
        timelinePanel.Layout.Column = 1;
        app.TimelinePanel = timelinePanel;
        timelineGrid = uigridlayout(timelinePanel, [2, 1]);
        timelineGrid.RowHeight = {"fit", "1x"};
        timelineGrid.Padding = [14, 8, 14, 8];
        timelineGrid.RowSpacing = 6;
        app.TimelineLabel = uilabel(timelineGrid, ...
            "Text", "Original  鈫?  Noisy  鈫?  Filtered  鈫?  Voice FX", ...
            "FontWeight", "bold", "FontSize", 15, "FontColor", theme.Primary, "FontName", "Microsoft YaHei");
        app.TimelineLabel.Layout.Row = 1;
        app.TimelineLabel.WordWrap = "on";
        app.TimelineHintLabel = uilabel(timelineGrid, ...
            "Text", "处理链历史会跟随当前阶段更新；区域已开启滚动，放大全屏也不会直接遮挡。", ...
            "WordWrap", "on", "FontColor", theme.Muted, "FontName", "Microsoft YaHei");
        app.TimelineHintLabel.Layout.Row = 2;

        logPanel = uipanel(footerGrid, "Title", "Run Log", "BackgroundColor", theme.Card, "ForegroundColor", theme.Text);
        logPanel.Layout.Row = 1;
        logPanel.Layout.Column = 2;
        logGrid = uigridlayout(logPanel, [2, 1]);
        logGrid.RowHeight = {"fit", "1x"};
        logGrid.Padding = [8, 8, 8, 8];
        logGrid.RowSpacing = 8;
        logHeader = uigridlayout(logGrid, [1, 2]);
        logHeader.Layout.Row = 1;
        logHeader.ColumnWidth = {"1x", 110};
        logHeader.Padding = [0, 0, 0, 0];
        uilabel(logHeader, "Text", "运行日志", "FontWeight", "bold", "FontColor", theme.Text, "FontName", "Microsoft YaHei");
        app.ClearLogButton = uibutton(logHeader, "push", "Text", "清空日志", ...
            "ButtonPushedFcn", @(~, ~) clearLogCallback());
        app.ClearLogButton.Layout.Row = 1;
        app.ClearLogButton.Layout.Column = 2;
        styleButton(app.ClearLogButton, [0.29, 0.33, 0.40], [1, 1, 1]);
        app.BottomLogArea = uitextarea(logGrid, "Editable", "off", "FontName", "Consolas", "Value", state.logMessages);
        app.BottomLogArea.Layout.Row = 2;
        makeScrollable(app.BottomLogArea);
    end

    function makeScrollable(containerHandle)
        try
            if isprop(containerHandle, "Scrollable")
                containerHandle.Scrollable = "on";
            end
        catch
        end
    end

    function updateResponsiveLayout()
        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end
        screenSizeLocal = get(groot, "ScreenSize");
        availableWidth = min(app.Figure.Position(3), screenSizeLocal(3));
        controlWidth = min(620, max(480, floor(availableWidth * 0.28)));
        app.MainGrid.ColumnWidth = {controlWidth, "1x"};
    end

    function selectControlTab(tabKey)
        if ~isfield(app, "ControlTabs") || isempty(app.ControlTabs) || ~isvalid(app.ControlTabs)
            return;
        end
        switch string(tabKey)
            case "source"
                app.ControlTabs.SelectedTab = app.SourceTab;
            case "process"
                app.ControlTabs.SelectedTab = app.ProcessTab;
            case "advanced"
                app.ControlTabs.SelectedTab = app.AdvancedTab;
            case "voice"
                app.ControlTabs.SelectedTab = app.VoiceTab;
        end
    end

    function selectVisualTab(tabKey)
        if ~isfield(app, "VisualTabs") || isempty(app.VisualTabs) || ~isvalid(app.VisualTabs)
            return;
        end
        switch string(tabKey)
            case "overview"
                app.VisualTabs.SelectedTab = app.OverviewTab;
            case "analysis"
                app.VisualTabs.SelectedTab = app.AnalysisTab;
            case "voice"
                app.VisualTabs.SelectedTab = app.VoiceVisualTab;
            case "modulation"
                if isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
                    app.VisualTabs.SelectedTab = app.ModulationVisualTab;
                end
            case "compare"
                app.VisualTabs.SelectedTab = app.CompareTab;
            case "export"
                if isfield(app, "ExportVisualTab") && isvalid(app.ExportVisualTab)
                    app.VisualTabs.SelectedTab = app.ExportVisualTab;
                end
        end
    end

    function safeCallback(callbackName, callbackFcn)
        try
            callbackFcn();
        catch callbackEx
            try
                addLog(string(callbackName) + " 失败：" + string(callbackEx.message));
            catch
            end
            if isfield(app, "Figure") && ~isempty(app.Figure) && isvalid(app.Figure)
                uialert(app.Figure, string(callbackEx.message), string(callbackName));
            end
        end
    end

    function quickOpenAudioCallback()
        selectControlTab("source");
        loadFileCallback();
    end

    function quickRecordCallback()
        selectControlTab("source");
        startRecordingCallback();
    end

    function quickDemoCallback()
        selectControlTab("source");
        runDemoCallback();
    end

    function quickExportCallback()
        selectVisualTab("export");
        exportMaterialsCallback();
    end

    function clearLogCallback()
        state.logMessages = "日志已清空。";
        if isfield(app, "LogArea") && ~isempty(app.LogArea) && isvalid(app.LogArea)
            app.LogArea.Value = state.logMessages;
        end
        if isfield(app, "BottomLogArea") && ~isempty(app.BottomLogArea) && isvalid(app.BottomLogArea)
            app.BottomLogArea.Value = state.logMessages;
        end
    end

    function applyDarkThemeToTree(rootHandle)
        if isempty(rootHandle) || ~isvalid(rootHandle)
            return;
        end
        try
            className = string(class(rootHandle));
            if isprop(rootHandle, "BackgroundColor")
                if contains(className, "GridLayout") || contains(className, "TabGroup")
                    rootHandle.BackgroundColor = theme.Panel;
                elseif contains(className, "Panel") || contains(className, "Tab")
                    rootHandle.BackgroundColor = theme.Card;
                elseif contains(className, "TextArea")
                    rootHandle.BackgroundColor = theme.Surface;
                elseif contains(className, "EditField") || contains(className, "DropDown") || contains(className, "CheckBox")
                    rootHandle.BackgroundColor = theme.InputBg;
                elseif contains(className, "Slider")
                    rootHandle.BackgroundColor = theme.Card;
                elseif contains(className, "Figure")
                    rootHandle.Color = theme.Bg;
                end
            end
            if isprop(rootHandle, "FontName"), rootHandle.FontName = "Microsoft YaHei"; end
            if isprop(rootHandle, "FontColor") && ~contains(className, "Button")
                if contains(className, "Tab")
                    rootHandle.FontColor = [0.15, 0.20, 0.28];
                else
                    rootHandle.FontColor = theme.Text;
                end
            end
            if isprop(rootHandle, "ForegroundColor")
                rootHandle.ForegroundColor = theme.Text;
            end
            if isprop(rootHandle, "BorderColor")
                rootHandle.BorderColor = theme.Grid;
            end
        catch
        end
        children = [];
        try
            children = allchild(rootHandle);
        catch
        end
        for childIdx = 1:numel(children)
            applyDarkThemeToTree(children(childIdx));
        end
    end

    function applyDarkAxesTheme()
        axisHandles = findall(app.Figure, "Type", "axes");
        for axisIdx = 1:numel(axisHandles)
            ax = axisHandles(axisIdx);
            try
                ax.Color = theme.Panel;
                ax.XColor = theme.Muted;
                ax.YColor = theme.Muted;
                ax.GridColor = theme.Grid;
                ax.MinorGridColor = theme.Grid;
                ax.Title.Color = theme.Text;
                ax.XLabel.Color = theme.Muted;
                ax.YLabel.Color = theme.Muted;
                grid(ax, "on");
            catch
            end
        end
    end

    function normalizeUiText()
        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end
        applyCanonicalUiText();
        repairResidualUiText();
        return;

        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end

        app.Figure.Name = "信号与系统课程大作业 APP";
        if isfield(app, "TitleLabel") && isvalid(app.TitleLabel)
            app.TitleLabel.Text = "信号与系统实验大作业 APP";
        end
        if isfield(app, "SubtitleLabel") && isvalid(app.SubtitleLabel)
            app.SubtitleLabel.Text = "读取、加噪、滤波、高级增强、变声、加密、调制解调、历史对比与智能推荐";
        end
        if isfield(app, "ControlPanel") && isvalid(app.ControlPanel)
            app.ControlPanel.Title = "模块控制中心";
        end
        if isfield(app, "VisualPanel") && isvalid(app.VisualPanel)
            app.VisualPanel.Title = "可视化工作区";
        end
        if isfield(app, "FooterPanel") && isvalid(app.FooterPanel)
            app.FooterPanel.Title = "Processing Timeline / Log";
        end
        if isfield(app, "ControlHeaderLabel") && isvalid(app.ControlHeaderLabel)
            app.ControlHeaderLabel.Text = "Control Center  ·  输入、降噪、变声、调制与预设";
        end
        if isfield(app, "VisualHeaderLabel") && isvalid(app.VisualHeaderLabel)
            app.VisualHeaderLabel.Text = "Visualization Workspace  ·  Dashboard / Time-Frequency / Voice / Compare";
        end
        if isfield(app, "SourceTab") && isvalid(app.SourceTab)
            app.SourceTab.Title = "信号源";
        end
        if isfield(app, "ProcessTab") && isvalid(app.ProcessTab)
            app.ProcessTab.Title = "处理链";
        end
        if isfield(app, "AdvancedTab") && isvalid(app.AdvancedTab)
            app.AdvancedTab.Title = "高级功能";
        end
        if isfield(app, "VoiceTab") && isvalid(app.VoiceTab)
            app.VoiceTab.Title = "变声器";
        end
        if isfield(app, "OverviewTab") && isvalid(app.OverviewTab)
            app.OverviewTab.Title = "总览 Dashboard";
        end
        if isfield(app, "AnalysisTab") && isvalid(app.AnalysisTab)
            app.AnalysisTab.Title = "高级分析";
        end
        if isfield(app, "CompareTab") && isvalid(app.CompareTab)
            app.CompareTab.Title = "A/B 对比";
        end
        if isfield(app, "VoiceVisualTab") && isvalid(app.VoiceVisualTab)
            app.VoiceVisualTab.Title = "变声分析";
        end
        if isfield(app, "TimelineHintLabel") && isvalid(app.TimelineHintLabel)
            app.TimelineHintLabel.Text = "处理链历史会跟随当前阶段更新；区域已开启滚动，放大全屏也不会直接遮挡。";
        end
        if isfield(app, "ClearLogButton") && isvalid(app.ClearLogButton)
            app.ClearLogButton.Text = "清空日志";
        end
        if isfield(app, "TimelineLabel") && isvalid(app.TimelineLabel)
            txt = string(app.TimelineLabel.Text);
            txt = replace(txt, ["閳?", "鈫?", "锟?", "�?"], "->");
            app.TimelineLabel.Text = txt;
        end

        panelMap = {
            "淇″彿璇诲彇妯″潡", "信号读取模块";
            "褰曢煶杈撳叆 / 瀹炴椂閲囬泦", "录音输入 / 实时采集";
            "鏄剧ず涓庡鍑?", "显示与导出";
            "褰撳墠浠诲姟璇存槑", "当前任务说明";
            "鍣０娣诲姞妯″潡", "噪声添加模块";
            "婊ゆ尝鍣ㄥ幓鍣ā鍧?", "滤波器去噪模块";
            "鍙樺０ / 璇煶鍔犲瘑妯″潡", "变声 / 语音加密模块";
            "璋冨埗涓庤В璋冩ā鍧?", "调制与解调模块";
            "鏅鸿兘鎺ㄨ崘", "智能推荐";
            "楂樼骇澧炲己", "高级增强";
            "鎶ュ憡绱犳潗瀵煎嚭", "报告素材导出";
            "鍦烘櫙棰勮", "场景预设";
            "鍙樺０妯″紡", "变声模式";
            "鏁堟灉鍙傛暟", "效果参数";
            "澶勭悊涓庤瘯鍚?", "处理与试听";
            "Processing Timeline", "Processing Timeline";
            "Run Log", "Run Log"
            };
        panelHandles = findall(app.Figure, "Type", "uipanel");
        for ii = 1:numel(panelHandles)
            thisTitle = string(panelHandles(ii).Title);
            for jj = 1:size(panelMap, 1)
                if contains(thisTitle, panelMap{jj, 1})
                    panelHandles(ii).Title = panelMap{jj, 2};
                    break;
                end
            end
        end
    end

    function applyReadableUiText()
        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end
        applyCanonicalUiText();
        repairResidualUiText();
        return;

        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end

        app.Figure.Name = "信号与系统课程大作业 APP";
        if isfield(app, "TitleLabel") && isvalid(app.TitleLabel)
            app.TitleLabel.Text = "信号与系统实验大作业 APP";
        end
        if isfield(app, "SubtitleLabel") && isvalid(app.SubtitleLabel)
            app.SubtitleLabel.Text = "读取、加噪、滤波、实时录音、变声、调制解调、历史对比与智能推荐";
        end
        if isfield(app, "ControlPanel") && isvalid(app.ControlPanel)
            app.ControlPanel.Title = "模块控制中心";
        end
        if isfield(app, "VisualPanel") && isvalid(app.VisualPanel)
            app.VisualPanel.Title = "可视化工作区";
        end
        if isfield(app, "FooterPanel") && isvalid(app.FooterPanel)
            app.FooterPanel.Title = "Processing Timeline / Log";
        end
        if isfield(app, "ControlHeaderLabel") && isvalid(app.ControlHeaderLabel)
            app.ControlHeaderLabel.Text = "Control Center  ·  输入、降噪、变声、调制与预设";
        end
        if isfield(app, "ControlTabHintLabel") && isvalid(app.ControlTabHintLabel)
            app.ControlTabHintLabel.Text = "信号源  |  处理链  |  高级功能  |  变声器";
        end
        if isfield(app, "VisualHeaderLabel") && isvalid(app.VisualHeaderLabel)
            app.VisualHeaderLabel.Text = "Visualization Workspace  ·  Dashboard / Time-Frequency / Voice / Modulation / Compare / Export";
        end
        if isfield(app, "VisualTabHintLabel") && isvalid(app.VisualTabHintLabel)
            app.VisualTabHintLabel.Text = "总览 Dashboard  |  高级分析  |  变声分析  |  调制通信  |  A/B 对比  |  报告导出";
        end

        tabPairs = { ...
            "SourceTab", "信号源"; ...
            "ProcessTab", "处理链"; ...
            "AdvancedTab", "高级功能"; ...
            "VoiceTab", "变声器"; ...
            "OverviewTab", "总览 Dashboard"; ...
            "AnalysisTab", "高级分析"; ...
            "VoiceVisualTab", "变声分析"; ...
            "ModulationVisualTab", "调制通信"; ...
            "CompareTab", "A/B 对比"; ...
            "ExportVisualTab", "报告导出"};
        for ii = 1:size(tabPairs, 1)
            fieldName = tabPairs{ii, 1};
            if isfield(app, fieldName) && isvalid(app.(fieldName))
                app.(fieldName).Title = tabPairs{ii, 2};
            end
        end

        buttonPairs = { ...
            "HeaderOpenButton", "打开音频"; ...
            "HeaderRecordButton", "实时录音"; ...
            "HeaderDemoButton", "运行演示"; ...
            "HeaderExportButton", "导出报告"; ...
            "DemoButton", "一键演示整条流程"; ...
            "ModulateButton", "运行通信链"; ...
            "DemodulateButton", "仅解调模拟链"; ...
            "GenerateBitsButton", "生成随机比特"; ...
            "ChannelNoiseButton", "仅加入信道噪声"; ...
            "ShowConstellationButton", "显示星座图"; ...
            "CalculateBerButton", "计算 BER"; ...
            "ClearLogButton", "清空日志"};
        for ii = 1:size(buttonPairs, 1)
            fieldName = buttonPairs{ii, 1};
            if isfield(app, fieldName) && isvalid(app.(fieldName))
                app.(fieldName).Text = buttonPairs{ii, 2};
            end
        end

        if isfield(app, "TimelineLabel") && isvalid(app.TimelineLabel)
            updateTimelineFooter();
        end
        if isfield(app, "TimelineHintLabel") && isvalid(app.TimelineHintLabel)
            app.TimelineHintLabel.Text = "处理链历史会跟随当前阶段更新；所有区域都已开启滚动，放大全屏也不会直接遮挡。";
        end
        if isfield(app, "CommStatusLabel") && isvalid(app.CommStatusLabel) && strlength(string(app.CommStatusLabel.Text)) == 0
            app.CommStatusLabel.Text = "通信链状态：尚未运行";
        end
    end

    function applyCanonicalUiText()
        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end

        app.Figure.Name = "信号与系统课程大作业 APP";
        setTextIfValid("TitleLabel", "信号与系统实验大作业 APP");
        setTextIfValid("SubtitleLabel", "读取、加噪、滤波、实时录音、变声、加密、调制解调、历史对比与智能推荐");
        setTitleIfValid("ControlPanel", "模块控制中心");
        setTitleIfValid("VisualPanel", "可视化工作区");
        setTitleIfValid("FooterPanel", "Processing Timeline / Log");
        setTextIfValid("ControlHeaderLabel", "Control Center  •  输入、降噪、变声、调制与预设");
        setTextIfValid("ControlTabHintLabel", "信号源 | 处理链 | 高级功能 | 变声器");
        setTextIfValid("VisualHeaderLabel", "Visualization Workspace  •  Dashboard / Time-Frequency / Voice / Modulation / Compare / Export");
        setTextIfValid("VisualTabHintLabel", "总览 Dashboard | 高级分析 | 变声分析 | 调制通信 | A/B 对比 | 报告导出");

        setTextIfValid("HeaderOpenButton", "打开音频");
        setTextIfValid("HeaderRecordButton", "实时录音");
        setTextIfValid("HeaderDemoButton", "运行演示");
        setTextIfValid("HeaderExportButton", "导出报告");

        setTitleIfValid("SourceTab", "信号源");
        setTitleIfValid("ProcessTab", "处理链");
        setTitleIfValid("AdvancedTab", "高级功能");
        setTitleIfValid("VoiceTab", "变声器");
        setTitleIfValid("OverviewTab", "总览 Dashboard");
        setTitleIfValid("AnalysisTab", "高级分析");
        setTitleIfValid("VoiceVisualTab", "变声分析");
        setTitleIfValid("ModulationVisualTab", "调制通信");
        setTitleIfValid("CompareTab", "A/B 对比");
        setTitleIfValid("ExportVisualTab", "报告导出");

        setTextIfValid("ControlNavSourceButton", "信号源");
        setTextIfValid("ControlNavProcessButton", "处理链");
        setTextIfValid("ControlNavAdvancedButton", "高级功能");
        setTextIfValid("ControlNavVoiceButton", "变声器");
        setTextIfValid("VisualNavOverviewButton", "总览");
        setTextIfValid("VisualNavAnalysisButton", "高级分析");
        setTextIfValid("VisualNavVoiceButton", "变声分析");
        setTextIfValid("VisualNavModulationButton", "调制通信");
        setTextIfValid("VisualNavCompareButton", "A/B 对比");
        setTextIfValid("VisualNavExportButton", "报告导出");

        resetChoice("SampleDropDown", ["样例语音 1", "样例语音 2"]);
        resetChoice("CaptureModeDropDown", ["限时实时采集", "持续监听"]);
        resetChoice("NoiseDropDown", ["白噪声", "工频干扰", "混合噪声"]);
        resetChoice("FilterDropDown", ["Butterworth低通", "Chebyshev高通", "语音带通", "FIR低通", "陷波", "Median", "小波去噪"]);
        resetChoice("FilterModeDropDown", ["预览", "应用"]);
        resetChoice("EffectDropDown", ["原声", "男声", "女声", "机器人音", "电话音 / 对讲机音", "回声音 / 山谷音", "怪兽音", "自定义 EQ", "语音加密", "语音解密"]);
        resetChoice("ModulationDropDown", ["AM调幅", "FM调频", "ASK", "FSK", "BPSK", "QPSK"]);
        resetChoice("AdvancedMethodDropDown", ["小波去噪", "自适应陷波", "语音均衡增强"]);
        resetChoice("PresetDropDown", ["课堂演示模式", "语音降噪模式", "工频抑制模式", "安全通信模式", "调制通信模式"]);
        resetChoice("VoiceModeDropDown", ["原声", "男声", "女声", "机器人音", "电话音 / 对讲机音", "回声音 / 山谷音", "怪兽音", "自定义 EQ"]);

        setTextIfValid("LoadSampleButton", "载入样例");
        setTextIfValid("LoadFileButton", "打开本地音频");
        setTextIfValid("GenerateSyntheticButton", "生成合成信号");
        setTextIfValid("ResetButton", "重置到原始信号");
        setTextIfValid("StartRecordButton", "开始采集");
        setTextIfValid("StopRecordButton", "停止采集");
        setTextIfValid("LoadRecordingButton", "载入处理链");
        setTextIfValid("FreezeRecordingButton", "冻结并载入");
        setTextIfValid("ClearRecordingButton", "清空缓存");
        setTextIfValid("SaveRecordingButton", "导出录音");
        setTextIfValid("PlayButton", "播放当前阶段");
        setTextIfValid("SaveButton", "导出 WAV");
        setTextIfValid("ExportDashboardButton", "导出仪表盘截图");
        setTextIfValid("DemoButton", "一键演示整条流程");
        setTextIfValid("ExportMetricsButton", "导出指标 CSV");
        setTextIfValid("ExportMetricsSnapshotButton", "导出指标截图");
        setTextIfValid("AddNoiseButton", "添加噪声");
        setTextIfValid("FilterButton", "应用滤波");
        setTextIfValid("ApplyEffectButton", "应用变声/功能");
        setTextIfValid("GenerateBitsButton", "生成随机比特");
        setTextIfValid("ChannelNoiseButton", "仅加入信道噪声");
        setTextIfValid("ModulateButton", "运行通信链");
        setTextIfValid("DemodulateButton", "仅解调模拟链");
        setTextIfValid("ShowConstellationButton", "显示星座图");
        setTextIfValid("CalculateBerButton", "计算 BER");
        setTextIfValid("AnalyzeButton", "分析当前信号");
        setTextIfValid("ApplyRecommendationButton", "加载推荐参数");
        setTextIfValid("ApplyRecommendedFilterButton", "直接应用推荐滤波");
        setTextIfValid("CompareRecommendedButton", "对比滤波前后");
        setTextIfValid("AdvancedEnhanceButton", "执行高级增强");
        setTextIfValid("ExportMaterialsButton", "导出实验报告素材");
        setTextIfValid("RunPresetButton", "运行预设");
        setTextIfValid("ApplyVoiceButton", "应用变声");
        setTextIfValid("PlayOriginalVoiceButton", "播放原声");
        setTextIfValid("PlayProcessedVoiceButton", "播放变声后");
        setTextIfValid("CompareVoiceButton", "A/B 对比");
        setTextIfValid("SaveVoiceButton", "保存变声音频");
        setTextIfValid("ClearLogButton", "清空日志");

        setTextIfValid("RecordSourceLabel", "输入设备：系统默认麦克风");
        setTextIfValid("RecordAutoLoadLabel", "限时模式结束后自动载入处理链，监听模式可手动冻结最近一段语音。");
        setTextIfValid("RecordStatusLabel", "状态：空闲");
        setTextIfValid("RecordLevelLabel", "峰值：0.000 | 时长：0.00 s");
        setTextIfValid("MetricLabel", "指标：尚未载入信号");
        setTextIfValid("CommStatusLabel", "通信链状态：尚未运行");
        setTextIfValid("ExportInfoLabel", "将导出当前阶段波形、频谱、时频图、变声图、调制图、指标表、WAV 与界面截图到 outputs 时间戳目录。");
        setTextIfValid("PresetInfoLabel", "预设说明：课堂演示重完整链路，语音降噪重实时分析，工频抑制重陷波，安全通信与调制通信重链路仿真。");
        setTextIfValid("VoiceInfoLabel", "原始波形/频谱与变声后对比会显示在“变声分析”和“A/B 对比”页。");
        setTextIfValid("TimelineLabel", "Original  ->  Noisy  ->  Filtered  ->  Voice FX");
        setTextIfValid("TimelineHintLabel", "处理链历史会跟随当前阶段更新；所有区域都已开启滚动，放大全屏也不会直接遮挡。");

        setValueIfValid("SignalInfoArea", ["尚未加载信号。"; "完成处理后，这里会显示来源、阶段链路和关键指标。"]);
        setValueIfValid("RecordAnalysisArea", ["实时分析状态"; "短时能量：--"; "主频：--"; "频带：--"]);
        setValueIfValid("VoiceMetricsArea", ["尚未应用变声。"; "载入语音后，在“变声器”页选择模式并点击“应用变声”。"]);

        if isfield(app, "RecordAxes") && isvalid(app.RecordAxes)
            title(app.RecordAxes, "录音实时波形预览");
            xlabel(app.RecordAxes, "时间 / s");
            ylabel(app.RecordAxes, "幅值");
        end
        if isfield(app, "TimelineLabel") && isvalid(app.TimelineLabel)
            updateTimelineFooter();
        end
    end

    function repairResidualUiText()
        if ~isfield(app, "Figure") || isempty(app.Figure) || ~isvalid(app.Figure)
            return;
        end

        textMap = canonicalTextMap();
        components = [app.Figure; findall(app.Figure)];
        for idx = 1:numel(components)
            h = components(idx);
            try
                if isprop(h, "Text")
                    h.Text = replaceMappedText(h.Text, textMap);
                end
                if isprop(h, "Title")
                    h.Title = replaceMappedText(h.Title, textMap);
                end
                if isprop(h, "Placeholder")
                    h.Placeholder = replaceMappedText(h.Placeholder, textMap);
                end
                if isprop(h, "Items")
                    h.Items = replaceMappedText(h.Items, textMap);
                end
                if isprop(h, "Value") && contains(string(class(h)), "TextArea")
                    h.Value = replaceMappedText(h.Value, textMap);
                end
            catch
            end
        end

        axisHandles = findall(app.Figure, "Type", "axes");
        for axisIdx = 1:numel(axisHandles)
            ax = axisHandles(axisIdx);
            try
                ax.Title.String = replaceMappedText(ax.Title.String, textMap);
                ax.XLabel.String = replaceMappedText(ax.XLabel.String, textMap);
                ax.YLabel.String = replaceMappedText(ax.YLabel.String, textMap);
            catch
            end
        end
    end

    function textMap = canonicalTextMap()
        textMap = cell(0, 2);
        return;
%%{
        textMap = {
            "淇″彿婧?", "信号源";
            "鍘熷淇″彿", "原始信号";
            "鍔犲櫔淇″彿", "加噪信号";
            "婊ゆ尝缁撴灉", "滤波结果";
            "楂樼骇澧炲己", "高级增强";
            "鍙樺０缁撴灉", "变声结果";
            "鍔犲瘑璇煶", "加密语音";
            "缂栫爜搴忓垪", "编码序列";
            "瑙ｅ瘑璇煶", "解密语音";
            "璋冨埗缁撴灉", "调制结果";
            "淇￠亾杈撳嚭", "信道输出";
            "瑙ｈ皟缁撴灉", "解调结果";
            "璇戠爜缁撴灉", "译码结果";
            "鎭㈠淇″彿", "恢复信号";
            "鏍蜂緥璇煶", "样例语音";
            "鏄剧ず涓庡鍑?", "显示与导出";
            "鍣０娣诲姞妯″潡", "噪声添加模块";
            "婊ゆ尝鍣ㄥ幓鍣ā鍧?", "滤波器去噪模块";
            "鍙樺０ / 璇煶鍔犲瘑妯″潡", "变声 / 语音加密模块";
            "璋冨埗涓庤В璋冩ā鍧?", "调制与解调模块";
            "鏅鸿兘鎺ㄨ崘", "智能推荐";
            "鎶ュ憡绱犳潗瀵煎嚭", "报告素材导出";
            "鍦烘櫙棰勮", "场景预设";
            "鍙樺０妯″紡", "变声模式";
            "鏁堟灉鍙傛暟", "效果参数";
            "澶勭悊涓庤瘯鍚?", "处理与试听";
            "鍘熷０", "原声";
            "鐢峰０", "男声";
            "濂冲０", "女声";
            "鏈哄櫒浜洪煶", "机器人音";
            "鐢佃瘽闊?/ 瀵硅鏈洪煶", "电话音 / 对讲机音";
            "鍥炲０闊?/ 灞辫胺闊?", "回声音 / 山谷音";
            "鎬吔闊?", "怪兽音";
            "鑷畾涔?EQ", "自定义 EQ";
            "鏃堕棿 / s", "时间 / s";
            "骞呭€?", "幅值";
            "A/B 瀵规瘮", "A/B 对比";
            "闁?", "->";
            "閳?", "->";
            "鈫?", "->";
            "閿?", "";
            "锟?", "";
            "�?", ""
            };
        return;
%{
        textMap = {
            "淇″彿婧?", "信号源";
            "鍘熷淇″彿", "原始信号";
            "鍔犲櫔淇″彿", "加噪信号";
            "婊ゆ尝缁撴灉", "滤波结果";
            "楂樼骇澧炲己", "高级增强";
            "鍙樺０缁撴灉", "变声结果";
            "鍔犲瘑璇煶", "加密语音";
            "缂栫爜搴忓垪", "编码序列";
            "瑙ｅ瘑璇煶", "解密语音";
            "璋冨埗缁撴灉", "调制结果";
            "淇￠亾杈撳嚭", "信道输出";
            "瑙ｈ皟缁撴灉", "解调结果";
            "璇戠爜缁撴灉", "译码结果";
            "鎭㈠淇″彿", "恢复信号";
            "鏍蜂緥璇煶", "样例语音";
            "鏍蜂緥璇煶 1", "样例语音 1";
            "鏍蜂緥璇煶 2", "样例语音 2";
            "杞藉叆鏍蜂緥", "载入样例";
            "鎵撳紑鏈湴闊抽", "打开本地音频";
            "鍚堟垚鏃堕暱 / s", "合成时长 / s";
            "鍚堟垚閲囨牱鐜?/ Hz", "合成采样率 / Hz";
            "鐢熸垚鍚堟垚淇″彿", "生成合成信号";
            "閲嶇疆鍒板師濮嬩俊鍙?", "重置到原始信号";
            "褰曢煶杈撳叆 / 瀹炴椂閲囬泦", "录音输入 / 实时采集";
            "杈撳叆璁惧锛氱郴缁熼粯璁ら害鍏嬮", "输入设备：系统默认麦克风";
            "閲囬泦妯″紡", "采集模式";
            "闄愭椂瀹炴椂閲囬泦", "限时实时采集";
            "鎸佺画鐩戝惉", "持续监听";
            "褰曢煶閲囨牱鐜?/ Hz", "录音采样率 / Hz";
            "鏈€闀垮綍闊?/ s", "最长录音 / s";
            "寮€濮嬮噰闆?", "开始采集";
            "鍋滄閲囬泦", "停止采集";
            "杞藉叆澶勭悊閾?", "载入处理链";
            "鍐荤粨骞惰浇鍏?", "冻结并载入";
            "娓呯┖缂撳瓨", "清空缓存";
            "鐎电厧鍤ぐ鏇㈢叾", "导出录音";
            "鐘舵€侊細绌洪棽", "状态：空闲";
            "宄板€硷細0.000 | 鏃堕暱锛?.00 s", "峰值：0.000 | 时长：0.00 s";
            "褰曢煶瀹炴椂娉㈠舰棰勮", "录音实时波形预览";
            "鏃堕棿 / s", "时间 / s";
            "骞呭€?", "幅值";
            "鏄剧ず涓庡鍑?", "显示与导出";
            "鏄剧ず闃舵", "显示阶段";
            "鎾斁褰撳墠闃舵", "播放当前阶段";
            "瀵煎嚭 WAV", "导出 WAV";
            "瀵煎嚭浠〃鐩樻埅鍥?", "导出仪表盘截图";
            "涓€閿紨绀烘暣鏉℃祦绋?", "一键演示整条流程";
            "瀵煎嚭鎸囨爣 CSV", "导出指标 CSV";
            "瀵煎嚭鎸囨爣鎴浘", "导出指标截图";
            "鎸囨爣锛氬皻鏈浇鍏ヤ俊鍙?", "指标：尚未载入信号";
            "褰撳墠浠诲姟璇存槑", "当前任务说明";
            "灏氭湭鍔犺浇淇″彿銆?", "尚未加载信号。";
            "鍣０娣诲姞妯″潡", "噪声添加模块";
            "鍣０绫诲瀷", "噪声类型";
            "鐧藉櫔澹?", "白噪声";
            "宸ラ骞叉壈", "工频干扰";
            "娣峰悎鍣０", "混合噪声";
            "鍣０绛夌骇", "噪声等级";
            "娣诲姞鍣０", "添加噪声";
            "婊ゆ尝鍣ㄥ幓鍣ā鍧?", "滤波器去噪模块";
            "婊ゆ尝鍣ㄧ被鍨?", "滤波器类型";
            "Butterworth浣庨€?", "Butterworth低通";
            "Chebyshev楂橀€?", "Chebyshev高通";
            "璇煶甯﹂€?", "语音带通";
            "FIR浣庨€?", "FIR低通";
            "棰勮", "预览";
            "搴旂敤", "应用";
            "宸ヤ綔妯″紡", "工作模式";
            "鍏抽敭棰戠巼 / Hz", "关键频率 / Hz";
            "婊ゆ尝鍣ㄩ樁鏁?", "滤波器阶数";
            "閫氬甫涓婅竟鐣?/ Hz", "通带上边界 / Hz";
            "搴旂敤婊ゆ尝", "应用滤波";
            "鍙樺０ / 璇煶鍔犲瘑妯″潡", "变声 / 语音加密模块";
            "鍔熻兘绫诲瀷", "功能类型";
            "鍘熷０", "原声";
            "鐢峰０", "男声";
            "濂冲０", "女声";
            "鏈哄櫒浜?", "机器人音";
            "鐢佃瘽闊?", "电话音";
            "鍥炲０", "回声音";
            "鎬吔闊?", "怪兽音";
            "鑷畾涔?EQ", "自定义 EQ";
            "璇煶鍔犲瘑", "语音加密";
            "璇煶瑙ｅ瘑", "语音解密";
            "闊宠皟 / 鍗婇煶", "音调 / 半音";
            "璇€熷€嶆暟", "语速倍数";
            "鍥炲０寮哄害", "回声强度";
            "璋冨埗棰戠巼 / Hz", "调制频率 / Hz";
            "EQ 澧炵泭 [dB]", "EQ 增益 [dB]";
            "鍔犲瘑甯ч暱", "加密帧长";
            "搴旂敤鍙樺０/鍔熻兘", "应用变声/功能";
            "璋冨埗涓庤В璋冩ā鍧?", "调制与解调模块";
            "璋冨埗鏂瑰紡", "调制方式";
            "AM璋冨箙", "AM调幅";
            "FM璋冮", "FM调频";
            "杞芥尝棰戠巼 / Hz", "载波频率 / Hz";
            "璋冨埗搴?/ 棰戝亸", "调制度 / 频偏";
            "淇￠亾 SNR / dB", "信道 SNR / dB";
            "绗﹀彿鐜?", "符号率";
            "姣旂壒鏁?", "比特数";
            "杈撳叆姣旂壒搴忓垪锛堢暀绌哄垯闅忔満鐢熸垚锛?", "输入比特序列（留空则随机生成）";
            "渚嬪锛?01100111000", "例如：101100111000";
            "鐢熸垚闅忔満姣旂壒", "生成随机比特";
            "浠呭姞鍏ヤ俊閬撳櫔澹?", "仅加入信道噪声";
            "杩愯閫氫俊閾?", "运行通信链";
            "浠呰В璋冩ā鎷熼摼", "仅解调模拟链";
            "鏄剧ず鏄熷骇鍥?", "显示星座图";
            "璁＄畻 BER", "计算 BER";
            "閫氫俊閾剧姸鎬侊細灏氭湭杩愯", "通信链状态：尚未运行";
            "鏅鸿兘鎺ㄨ崘", "智能推荐";
            "鍒嗘瀽褰撳墠淇″彿", "分析当前信号";
            "鍔犺浇鎺ㄨ崘鍙傛暟", "加载推荐参数";
            "鐩存帴搴旂敤鎺ㄨ崘婊ゆ尝", "直接应用推荐滤波";
            "瀵规瘮婊ゆ尝鍓嶅悗", "对比滤波前后";
            "楂樼骇澧炲己", "高级增强";
            "澧炲己鏂瑰紡", "增强方式";
            "灏忔尝鍘诲櫔", "小波去噪";
            "鑷€傚簲闄锋尝", "自适应陷波";
            "璇煶鍧囪　澧炲己", "语音均衡增强";
            "澧炲己寮哄害", "增强强度";
            "鎵ц楂樼骇澧炲己", "执行高级增强";
            "鎶ュ憡绱犳潗瀵煎嚭", "报告素材导出";
            "瀵煎嚭瀹為獙鎶ュ憡绱犳潗", "导出实验报告素材";
            "鍦烘櫙棰勮", "场景预设";
            "璇惧爞婕旂ず妯″紡", "课堂演示模式";
            "璇煶闄嶅櫔妯″紡", "语音降噪模式";
            "宸ラ鎶戝埗妯″紡", "工频抑制模式";
            "瀹夊叏閫氫俊妯″紡", "安全通信模式";
            "璋冨埗閫氫俊妯″紡", "调制通信模式";
            "杩愯棰勮", "运行预设";
            "鍙樺０妯″紡", "变声模式";
            "鏈哄櫒浜洪煶", "机器人音";
            "鐢佃瘽闊?/ 瀵硅鏈洪煶", "电话音 / 对讲机音";
            "鍥炲０闊?/ 灞辫胺闊?", "回声音 / 山谷音";
            "鏁堟灉鍙傛暟", "效果参数";
            "鍥炲０寤惰繜 / s", "回声延迟 / s";
            "鏈哄櫒浜洪鐜?/ Hz", "机器人频率 / Hz";
            "璋冨埗娣卞害", "调制深度";
            "3. 5 娈?EQ 澧炵泭 / dB", "3. 5 段 EQ 增益 / dB";
            "澶勭悊涓庤瘯鍚?", "处理与试听";
            "搴旂敤鍙樺０", "应用变声";
            "鎾斁鍘熷０", "播放原声";
            "鎾斁鍙樺０鍚?", "播放变声后";
            "淇濆瓨鍙樺０闊抽", "保存变声音频";
            "A/B 瀵规瘮", "A/B 对比";
            "閫?, "->";
            "閳?", "->";
            "鈫?", "->";
            "锟?", "";
            "�?", ""
            };
    end

%}
    end
    function setTextIfValid(fieldName, textValue)
        if isfield(app, fieldName) && isvalid(app.(fieldName))
            app.(fieldName).Text = textValue;
        end
    end

    function setTitleIfValid(fieldName, titleValue)
        if isfield(app, fieldName) && isvalid(app.(fieldName))
            app.(fieldName).Title = titleValue;
        end
    end

    function setValueIfValid(fieldName, valueText)
        if isfield(app, fieldName) && isvalid(app.(fieldName))
            app.(fieldName).Value = valueText;
        end
    end

    function resetChoice(fieldName, itemsValue)
        if ~isfield(app, fieldName) || ~isvalid(app.(fieldName))
            return;
        end
        dropdownHandle = app.(fieldName);
        currentValue = "";
        try
            currentValue = replaceMappedText(string(dropdownHandle.Value), canonicalTextMap());
        catch
        end
        dropdownHandle.Items = itemsValue;
        if isprop(dropdownHandle, "ItemsData")
            try
                if ~isempty(dropdownHandle.ItemsData)
                    return;
                end
            catch
            end
        end
        if any(itemsValue == currentValue)
            dropdownHandle.Value = currentValue;
        elseif any(itemsValue == string(dropdownHandle.Value))
            dropdownHandle.Value = string(dropdownHandle.Value);
        else
            dropdownHandle.Value = itemsValue(1);
        end
    end

    function valueOut = replaceMappedText(valueIn, textMap)
        valueOut = valueIn;
        if isstring(valueIn)
            for mapIdx = 1:size(textMap, 1)
                valueOut = replace(valueOut, textMap{mapIdx, 1}, textMap{mapIdx, 2});
            end
        elseif ischar(valueIn)
            tmp = string(valueIn);
            for mapIdx = 1:size(textMap, 1)
                tmp = replace(tmp, textMap{mapIdx, 1}, textMap{mapIdx, 2});
            end
            valueOut = char(tmp);
        elseif iscell(valueIn)
            valueOut = valueIn;
            for cellIdx = 1:numel(valueIn)
                valueOut{cellIdx} = replaceMappedText(valueIn{cellIdx}, textMap);
            end
        end
    end

    function updateTimelineFooter()
        if ~isfield(app, "TimelineLabel") || isempty(app.TimelineLabel) || ~isvalid(app.TimelineLabel)
            return;
        end
        labelMap = struct( ...
            "original", "Original", ...
            "noisy", "Noisy", ...
            "filtered", "Filtered", ...
            "enhanced", "Enhanced", ...
            "effect", "Voice FX", ...
            "encrypted", "Encrypted", ...
            "encoded", "Encoded", ...
            "modulated", "Modulated", ...
            "channel", "Channel", ...
            "demodulated", "Demodulated", ...
            "decoded", "Decoded", ...
            "decrypted", "Decrypted", ...
            "restored", "Restored");
        timelineNames = strings(0, 1);
        for timelineIdx = 1:numel(state.stageOrder)
            key = state.stageOrder(timelineIdx);
            if isfield(state.signals, char(key))
                if isfield(labelMap, char(key))
                    label = string(labelMap.(char(key)));
                else
                    label = upper(string(key));
                end
                if key == state.currentStage
                    label = "[" + label + "]";
                end
                timelineNames(end + 1, 1) = label; %#ok<AGROW>
            end
        end
        if isempty(timelineNames)
            timelineNames = "Original";
        end
        app.TimelineLabel.Text = strjoin(timelineNames, "  ->  ");
    end

    function styleButton(buttonHandle, backgroundColor, fontColor)
        buttonHandle.BackgroundColor = backgroundColor;
        buttonHandle.FontColor = fontColor;
        buttonHandle.FontWeight = "bold";
        buttonHandle.FontName = "Microsoft YaHei";
    end

    function assertSignalLoaded()
        if isempty(state.fs) || ~isfield(state.signals, "original")
            uialert(app.Figure, "请先读取或生成信号，再执行后续模块。", "缺少输入信号");
            error("No signal loaded.");
        end
        return;

        if isempty(state.fs) || ~isfield(state.signals, "original")
            uialert(app.Figure, "请先读取或生成信号，再执行后续模块。", "缺少输入信号");
            error("No signal loaded.");
        end
    end

    function addLog(messageText)
        timestamp = char(datetime("now", "Format", "HH:mm:ss"));
        lineText = string(sprintf("[%s] %s", timestamp, string(messageText)));
        state.logMessages(end + 1, 1) = lineText;
        if numel(state.logMessages) > 80
            state.logMessages = state.logMessages(end - 79:end);
        end
        app.LogArea.Value = state.logMessages;
        if isfield(app, "BottomLogArea") && ~isempty(app.BottomLogArea) && isvalid(app.BottomLogArea)
            app.BottomLogArea.Value = state.logMessages;
        end
    end

    function setSignal(stageKey, signalValue, sourceLabel)
        state.signals.(char(stageKey)) = signalValue(:);
        state.currentStage = string(stageKey);
        if nargin >= 3 && strlength(sourceLabel) > 0
            state.sourceLabel = sourceLabel;
        end
        if ~isfield(state.stageMeta, char(stageKey))
            state.stageMeta.(char(stageKey)) = struct();
        end
        syncStageSelectors(string(stageKey));
        updateTimelineFooter();
    end

    function setStageMeta(stageKey, metadata)
        state.stageMeta.(char(stageKey)) = metadata;
    end

    function metadata = buildStageMeta(moduleName, descriptionText, referenceSignal, outputSignal)
        metadata = struct();
        metadata.module = string(moduleName);
        metadata.description = string(descriptionText);
        metadata.fs = state.fs;
        metadata.sampleCount = numel(outputSignal);
        if nargin >= 3 && ~isempty(referenceSignal) && ~isempty(outputSignal) && ~isempty(state.fs)
            cleanReferenceSignal = [];
            if isfield(state.signals, "original") && ~isempty(state.signals.original)
                cleanReferenceSignal = state.signals.original;
                if numel(cleanReferenceSignal) == numel(outputSignal) ...
                        && isequal(referenceSignal(:), outputSignal(:)) ...
                        && isequal(outputSignal(:), cleanReferenceSignal(:))
                    cleanReferenceSignal = [];
                end
            end
            metadata.metrics = SignalSystemDSP.evaluateProcessing(referenceSignal, outputSignal, state.fs, cleanReferenceSignal);
        else
            metadata.metrics = struct();
        end
    end

    function captureModeChangedCallback()
        state.liveAnalysis.captureMode = string(app.CaptureModeDropDown.Value);
        if state.liveAnalysis.captureMode == "持续监听"
            app.RecordAutoLoadLabel.Text = "持续监听会保留最近 8 秒缓冲区，点击“冻结并载入”后将最近片段送入处理链。";
        else
            app.RecordAutoLoadLabel.Text = "限时模式结束后自动载入处理链，适合课堂演示和报告截图。";
        end
        refreshRecordingPanel();
    end

    function clearRecordingState()
        disposeRecorder(true);
        state.recordingBuffer = zeros(0, 1);
        state.recordingElapsedSeconds = 0;
        state.recordingPeak = 0;
        state.recordingStatus = "空闲";
        state.isRecording = false;
        state.liveAnalysis.frameTrend = zeros(0, 5);
        state.liveAnalysis.latestFrameInfo = struct();
        state.liveAnalysis.latestSpectrogram = struct();
        if isfield(app, "RecordAnalysisArea") && ~isempty(app.RecordAnalysisArea) && isvalid(app.RecordAnalysisArea)
            app.RecordAnalysisArea.Value = ["Live analysis status"; "STE: --"; "MainFreq: --"; "Bands: --"];
        end
    end

    function disposeRecorder(dropCallbacks)
        if nargin < 1
            dropCallbacks = false;
        end

        recObj = state.recorder;
        if isempty(recObj)
            return;
        end

        if dropCallbacks
            try
                set(recObj, "TimerFcn", "", "StopFcn", "");
            catch
            end
        end

        try
            if strcmpi(string(recObj.Running), "on")
                stop(recObj);
            end
        catch
        end

        try
            delete(recObj);
        catch
        end

        state.recorder = [];
        state.isRecording = false;
    end

    function refreshRecordingPanel()
        if ~isfield(app, "RecordAxes") || isempty(app.RecordAxes) || ~isvalid(app.RecordAxes)
            return;
        end

        app.RecordStatusLabel.Text = "状态：" + state.recordingStatus;
        app.RecordLevelLabel.Text = sprintf("峰值：%.3f | 时长：%.2f s", state.recordingPeak, state.recordingElapsedSeconds);

        if state.isRecording
            app.StartRecordButton.Enable = "off";
            app.StopRecordButton.Enable = "on";
            app.LoadRecordingButton.Enable = "off";
        else
            app.StartRecordButton.Enable = "on";
            app.StopRecordButton.Enable = "off";
            if isempty(state.recordingBuffer)
                app.LoadRecordingButton.Enable = "off";
            else
                app.LoadRecordingButton.Enable = "on";
            end
        end

        if isempty(state.recordingBuffer)
            app.ClearRecordingButton.Enable = "off";
            if isfield(app, "SaveRecordingButton") && ~isempty(app.SaveRecordingButton)
                app.SaveRecordingButton.Enable = "off";
            end
        else
            app.ClearRecordingButton.Enable = "on";
            if isfield(app, "SaveRecordingButton") && ~isempty(app.SaveRecordingButton)
                app.SaveRecordingButton.Enable = "on";
            end
        end

        cla(app.RecordAxes);
        if isempty(state.recordingBuffer)
            text(app.RecordAxes, 0.5, 0.55, "点击“开始录音”后，这里会显示实时波形", ...
                "HorizontalAlignment", "center", ...
                "FontName", "Microsoft YaHei", ...
                "FontSize", 12, ...
                "Color", [0.36, 0.42, 0.52]);
            xlim(app.RecordAxes, [0, 1]);
            ylim(app.RecordAxes, [-1, 1]);
            app.RecordAxes.XTick = [];
            app.RecordAxes.YTick = [];
            title(app.RecordAxes, "录音实时波形预览");
            xlabel(app.RecordAxes, "时间 / s");
            ylabel(app.RecordAxes, "幅值");
            grid(app.RecordAxes, "on");
            return;
        end

        previewLength = min(numel(state.recordingBuffer), max(1, round(2 * state.recordingFs)));
        previewSignal = state.recordingBuffer(end - previewLength + 1:end);
        previewDuration = previewLength / state.recordingFs;
        startTime = max(0, state.recordingElapsedSeconds - previewDuration);
        timeAxis = startTime + (0:previewLength - 1) / state.recordingFs;

        app.RecordAxes.XTickMode = "auto";
        app.RecordAxes.YTickMode = "auto";
        plot(app.RecordAxes, timeAxis, previewSignal, ...
            "LineWidth", 0.9, ...
            "Color", [0.15, 0.57, 0.78]);
        grid(app.RecordAxes, "on");
        xlabel(app.RecordAxes, "时间 / s");
        ylabel(app.RecordAxes, "幅值");
        if state.isRecording
            title(app.RecordAxes, "录音实时波形预览");
        else
            title(app.RecordAxes, "录音缓存波形预览");
        end
        xlim(app.RecordAxes, [timeAxis(1), timeAxis(end) + eps]);
        updateRecordingAnalysisPanel();
    end

    function refreshLiveAnalysis(buffer)
        if isempty(buffer)
            state.liveAnalysis.frameTrend = zeros(0, 5);
            state.liveAnalysis.latestFrameInfo = struct();
            state.liveAnalysis.latestSpectrogram = struct();
            updateRecordingAnalysisPanel();
            return;
        end

        frameLength = 2 ^ nextpow2(max(128, round(0.032 * state.recordingFs)));
        frameLength = min(frameLength, max(128, numel(buffer)));
        if mod(frameLength, 2) ~= 0
            frameLength = frameLength + 1;
        end
        latestFrame = buffer(max(1, end - frameLength + 1):end);
        [frameInfo, trendPoint] = SignalSystemDSP.analyzeLiveFrame(latestFrame, state.recordingFs, state.liveAnalysis.frameBands);
        state.liveAnalysis.latestFrameInfo = frameInfo;
        state.liveAnalysis.frameTrend(end + 1, :) = trendPoint;
        if size(state.liveAnalysis.frameTrend, 1) > 120
            state.liveAnalysis.frameTrend = state.liveAnalysis.frameTrend(end - 119:end, :);
        end
        state.liveAnalysis.latestSpectrogram = SignalSystemDSP.buildLiveSpectrogram(buffer, state.recordingFs, ...
            struct("frameLength", frameLength, "overlapLength", round(0.5 * frameLength), "nfft", max(512, 2 * frameLength)));
        updateRecordingAnalysisPanel();
    end

    function updateRecordingAnalysisPanel()
        if ~isfield(app, "RecordAnalysisArea") || isempty(app.RecordAnalysisArea) || ~isvalid(app.RecordAnalysisArea)
            return;
        end

        if isempty(state.recordingBuffer) || ~isstruct(state.liveAnalysis.latestFrameInfo) || isempty(fieldnames(state.liveAnalysis.latestFrameInfo))
            app.RecordAnalysisArea.Value = ["Live analysis status"; "STE: --"; "MainFreq: --"; "Bands: --"];
            return;
        end

        frameInfo = state.liveAnalysis.latestFrameInfo;
        app.RecordAnalysisArea.Value = [ ...
            "Live analysis status"; ...
            sprintf("STE: %.5f | RMS: %.4f | Peak: %.4f", frameInfo.shortTimeEnergy, frameInfo.rmsValue, frameInfo.peakValue); ...
            sprintf("MainFreq: %.1f Hz | Centroid: %.1f Hz", frameInfo.dominantFrequencyHz, frameInfo.spectralCentroidHz); ...
            sprintf("Bands L/M/H: %.4f / %.4f / %.4f", frameInfo.bandEnergy.low, frameInfo.bandEnergy.mid, frameInfo.bandEnergy.high)];
    end

    function exportDir = exportRecordingArtifacts(outputSignal, fsValue, namePrefix)
        if nargin < 3 || strlength(string(namePrefix)) == 0
            namePrefix = "recording";
        end

        outputRoot = fullfile(state.baseDir, "outputs");
        if ~exist(outputRoot, "dir")
            mkdir(outputRoot);
        end
        exportDir = fullfile(outputRoot, char(string(namePrefix) + "_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss"))));
        if ~exist(exportDir, "dir")
            mkdir(exportDir);
        end

        audiowrite(fullfile(exportDir, "recording.wav"), outputSignal, fsValue);

        fig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1200, 840]);
        layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
        ax = nexttile(layout);
        SignalSystemDSP.drawWaveform(ax, outputSignal, fsValue, "Recording Waveform", [0.10, 0.45, 0.72]);
        ax = nexttile(layout);
        SignalSystemDSP.drawSpectrum(ax, outputSignal, fsValue, "Recording FFT Spectrum", [0.78, 0.22, 0.22]);
        ax = nexttile(layout);
        SignalSystemDSP.drawSpectrogram(ax, outputSignal, fsValue, "Recording Spectrogram");
        ax = nexttile(layout);
        if isstruct(state.liveAnalysis.latestFrameInfo) && ~isempty(fieldnames(state.liveAnalysis.latestFrameInfo))
            frameInfo = state.liveAnalysis.latestFrameInfo;
            text(ax, 0.05, 0.82, sprintf("STE: %.5f", frameInfo.shortTimeEnergy), "FontSize", 13);
            text(ax, 0.05, 0.64, sprintf("MainFreq: %.1f Hz", frameInfo.dominantFrequencyHz), "FontSize", 13);
            text(ax, 0.05, 0.46, sprintf("Band L/M/H: %.4f / %.4f / %.4f", frameInfo.bandEnergy.low, frameInfo.bandEnergy.mid, frameInfo.bandEnergy.high), "FontSize", 13);
            text(ax, 0.05, 0.28, sprintf("Duration: %.2f s | Fs: %.0f Hz", numel(outputSignal) / fsValue, fsValue), "FontSize", 13);
        end
        axis(ax, "off");
        exportgraphics(fig, fullfile(exportDir, "recording_dashboard.png"), "Resolution", 220);
        close(fig);

        waveformFig = figure("Visible", "off", "Color", "w", "Position", [120, 120, 980, 340]);
        ax = axes(waveformFig);
        SignalSystemDSP.drawWaveform(ax, outputSignal, fsValue, "Recording Waveform");
        exportgraphics(waveformFig, fullfile(exportDir, "recording_waveform.png"), "Resolution", 220);
        close(waveformFig);

        spectrumFig = figure("Visible", "off", "Color", "w", "Position", [120, 120, 980, 340]);
        ax = axes(spectrumFig);
        SignalSystemDSP.drawSpectrum(ax, outputSignal, fsValue, "Recording FFT Spectrum");
        exportgraphics(spectrumFig, fullfile(exportDir, "recording_spectrum.png"), "Resolution", 220);
        close(spectrumFig);

        spectrogramFig = figure("Visible", "off", "Color", "w", "Position", [120, 120, 980, 420]);
        ax = axes(spectrogramFig);
        SignalSystemDSP.drawSpectrogram(ax, outputSignal, fsValue, "Recording Spectrogram");
        exportgraphics(spectrogramFig, fullfile(exportDir, "recording_spectrogram.png"), "Resolution", 220);
        close(spectrogramFig);
    end

    function saveRecordingBundleCallback()
        if isempty(state.recordingBuffer)
            uialert(app.Figure, "No recording buffer is available yet. Please record audio first.", "No Recording");
            return;
        end

        exportDir = exportRecordingArtifacts(state.recordingBuffer, state.recordingFs, "live_recording");
        addLog("Live recording bundle exported to: " + string(exportDir));
    end

    function recordingTimerCallback(src, ~)
        if isempty(src) || ~isvalid(app.Figure)
            return;
        end

        try
            data = getaudiodata(src);
        catch
            return;
        end

        data = data(:);
        if state.liveAnalysis.captureMode == "持续监听"
            keepSamples = min(numel(data), max(1, round(state.liveAnalysis.listenBufferSeconds * state.recordingFs)));
            state.recordingBuffer = data(end - keepSamples + 1:end);
        else
            state.recordingBuffer = data;
        end
        state.recordingElapsedSeconds = numel(state.recordingBuffer) / state.recordingFs;
        if isempty(state.recordingBuffer)
            state.recordingPeak = 0;
        else
            tailLength = min(numel(state.recordingBuffer), max(1, round(0.35 * state.recordingFs)));
            tailSignal = state.recordingBuffer(end - tailLength + 1:end);
            state.recordingPeak = max(abs(tailSignal));
        end
        state.recordingStatus = sprintf("录音中 %.1f / %.1f s", state.recordingElapsedSeconds, state.recordingMaxDuration);
        refreshLiveAnalysis(state.recordingBuffer);
        refreshRecordingPanel();
        refreshOverviewViews();
        refreshSignalInfo();
        drawnow limitrate nocallbacks;
    end

    function recordingStopCallback(src, ~)
        if isempty(src)
            return;
        end

        try
            data = getaudiodata(src);
        catch
            data = state.recordingBuffer;
        end

        state.recordingBuffer = data(:);
        if state.liveAnalysis.captureMode == "持续监听"
            keepSamples = min(numel(state.recordingBuffer), max(1, round(state.liveAnalysis.listenBufferSeconds * state.recordingFs)));
            state.recordingBuffer = state.recordingBuffer(end - keepSamples + 1:end);
        end
        state.recordingElapsedSeconds = numel(state.recordingBuffer) / max(state.recordingFs, 1);
        if isempty(state.recordingBuffer)
            state.recordingPeak = 0;
            state.recordingStatus = "空闲";
        else
            state.recordingPeak = max(abs(state.recordingBuffer));
            state.recordingStatus = "录音完成，等待载入";
        end
        state.isRecording = false;
        state.recorder = [];
        refreshLiveAnalysis(state.recordingBuffer);

        if isvalid(app.Figure)
            refreshRecordingPanel();
            refreshOverviewViews();
            refreshSignalInfo();
            if ~isempty(state.recordingBuffer)
                addLog(sprintf("录音结束，缓存时长 %.2f 秒，采样率 %.0f Hz。", ...
                    state.recordingElapsedSeconds, state.recordingFs));
                try
                    exportDir = exportRecordingArtifacts(state.recordingBuffer, state.recordingFs, "live_recording_auto");
                    addLog("Live recording auto-exported to: " + string(exportDir));
                catch exportEx
                    addLog("Live recording export skipped: " + string(exportEx.message));
                end
                loadRecordingAsSignalCallback();
            end
        end
    end

    function startRecordingCallback()
        if state.isRecording
            return;
        end

        fsValue = round(app.RecordFsField.Value);
        maxDuration = app.RecordMaxDurationField.Value;
        fsValue = min(max(fsValue, 8000), 48000);
        maxDuration = min(max(maxDuration, 1), 20);
        app.RecordFsField.Value = fsValue;
        app.RecordMaxDurationField.Value = maxDuration;

        disposeRecorder(true);
        state.recordingFs = fsValue;
        state.recordingMaxDuration = maxDuration;
        state.liveAnalysis.captureMode = string(app.CaptureModeDropDown.Value);
        state.recordingBuffer = zeros(0, 1);
        state.recordingElapsedSeconds = 0;
        state.recordingPeak = 0;
        state.recordingStatus = "准备连接麦克风";
        state.liveAnalysis.frameTrend = zeros(0, 5);
        state.liveAnalysis.latestFrameInfo = struct();
        state.liveAnalysis.latestSpectrogram = struct();

        try
            recObj = audiorecorder(fsValue, 16, 1);
            recObj.TimerPeriod = 0.25;
            recObj.TimerFcn = @recordingTimerCallback;
            recObj.StopFcn = @recordingStopCallback;
            state.recorder = recObj;
            state.isRecording = true;
            state.recordingStatus = sprintf("录音中 0.0 / %.1f s", maxDuration);
            refreshRecordingPanel();
            refreshSignalInfo();
            if state.liveAnalysis.captureMode == "持续监听"
                record(recObj);
                addLog(sprintf("开始持续监听：默认麦克风，采样率 %.0f Hz，最近 %.1f 秒环形缓冲。", fsValue, state.liveAnalysis.listenBufferSeconds));
            else
                record(recObj, maxDuration);
                addLog(sprintf("开始限时采集：默认麦克风，采样率 %.0f Hz，最长 %.1f 秒。", fsValue, maxDuration));
            end
        catch ex
            disposeRecorder(true);
            state.recordingBuffer = zeros(0, 1);
            state.recordingElapsedSeconds = 0;
            state.recordingPeak = 0;
            state.recordingStatus = "录音启动失败";
            refreshRecordingPanel();
            refreshSignalInfo();
            uialert(app.Figure, "无法启动录音设备，请检查麦克风权限或输入设备状态。" + newline + ex.message, "录音失败");
        end
    end

    function stopRecordingCallback()
        if isempty(state.recorder) || ~state.isRecording
            return;
        end

        try
            stop(state.recorder);
        catch ex
            state.isRecording = false;
            state.recordingStatus = "停止失败";
            refreshRecordingPanel();
            refreshSignalInfo();
            uialert(app.Figure, "录音停止失败。" + newline + ex.message, "录音失败");
        end
    end

    function loadRecordingAsSignalCallback()
        if state.isRecording && ~isempty(state.recorder)
            try
                stop(state.recorder);
            catch
            end
        end

        if isempty(state.recordingBuffer) && ~isempty(state.recorder)
            try
                state.recordingBuffer = getaudiodata(state.recorder);
                state.recordingBuffer = state.recordingBuffer(:);
            catch
            end
        end

        if isempty(state.recordingBuffer)
            uialert(app.Figure, "当前没有可载入的录音，请先开始录音并结束采集。", "无录音缓存");
            return;
        end

        signalValue = SignalSystemDSP.prepareSignal(state.recordingBuffer);
        state.fs = state.recordingFs;
        state.signals = struct();
        state.stageMeta = struct();
        state.cryptoInfo = [];
        setSignal("original", signalValue, "实时录音");
        setStageMeta("original", buildStageMeta("实时采集", "采集缓存已载入处理链", signalValue, signalValue));
        disposeRecorder(true);
        state.recordingStatus = "已载入处理链";
        state.recordingElapsedSeconds = numel(state.recordingBuffer) / max(state.recordingFs, 1);
        state.recordingPeak = max(abs(state.recordingBuffer));
        addLog(sprintf("已将录音载入处理链，时长 %.2f 秒，采样率 %.0f Hz。", ...
            state.recordingElapsedSeconds, state.recordingFs));
        refreshAllViews();
    end

    function freezeRecordingCallback()
        if ~state.isRecording && isempty(state.recordingBuffer)
            uialert(app.Figure, "当前没有可冻结的监听缓存，请先开始持续监听。", "无监听缓存");
            return;
        end
        if state.isRecording && ~isempty(state.recorder)
            try
                stop(state.recorder);
            catch
            end
        end
        loadRecordingAsSignalCallback();
    end

    function clearRecordingBufferCallback()
        clearRecordingState();
        refreshRecordingPanel();
        refreshSignalInfo();
        addLog("已清空录音缓存。");
    end

    function closeAppCallback()
        disposeRecorder(true);
        if isvalid(app.Figure)
            app.Figure.CloseRequestFcn = [];
            delete(app.Figure);
        end
    end

    function syncStageSelectors(selectedStage)
        items = strings(0, 1);
        data = strings(0, 1);
        for idx = 1:numel(state.stageOrder)
            fieldName = char(state.stageOrder(idx));
            if isfield(state.signals, fieldName)
                items(end + 1, 1) = state.stageLabels.(fieldName); %#ok<AGROW>
                data(end + 1, 1) = string(fieldName); %#ok<AGROW>
            end
        end

        if isempty(items)
            items = "原始信号";
            data = "original";
        end

        app.StageDropDown.Items = items;
        app.StageDropDown.ItemsData = data;
        app.StageDropDown.Value = resolveValidStage(selectedStage, data);

        app.CompareStageADropDown.Items = items;
        app.CompareStageADropDown.ItemsData = data;
        app.CompareStageBDropDown.Items = items;
        app.CompareStageBDropDown.ItemsData = data;

        app.CompareStageADropDown.Value = resolveValidStage(app.CompareStageADropDown.Value, data);
        if numel(data) >= 2
            if ~ismember(app.CompareStageBDropDown.Value, data)
                app.CompareStageBDropDown.Value = data(min(2, numel(data)));
            end
        else
            app.CompareStageBDropDown.Value = data(1);
        end
    end

    function validStage = resolveValidStage(candidateStage, availableStages)
        candidateStage = string(candidateStage);
        if any(availableStages == candidateStage)
            validStage = candidateStage;
        else
            validStage = availableStages(1);
        end
    end

    function signalValue = getSignal(stageKey)
        signalValue = state.signals.(char(stageKey));
        signalValue = signalValue(:);
    end

    function signalValue = getCurrentSignal()
        signalValue = getSignal(state.currentStage);
    end

    function refreshAllViews()
        refreshRecordingPanel();
        refreshOverviewViews();
        refreshAnalysisViews();
        refreshComparisonView();
        refreshVoiceViews();
        refreshModulationViews();
        refreshStatusCards();
        refreshSignalInfo();
        normalizeUiText();
        applyReadableUiText();
    end

    function refreshOverviewViews()
        if state.isRecording && ~isempty(state.recordingBuffer)
            cla(app.WaveAxes);
            cla(app.SpectrumAxes);
            cla(app.SpectrogramAxes);
            cla(app.CompareAxes);

            SignalSystemDSP.drawWaveform(app.WaveAxes, state.recordingBuffer, state.recordingFs, "实时采集波形", [0.10, 0.48, 0.78]);
            if isfield(state.liveAnalysis.latestSpectrogram, "fftAxis")
                plot(app.SpectrumAxes, state.liveAnalysis.latestSpectrogram.fftAxis, state.liveAnalysis.latestSpectrogram.fftDb, ...
                    "LineWidth", 1.05, "Color", [0.85, 0.24, 0.20]);
                grid(app.SpectrumAxes, "on");
                xlabel(app.SpectrumAxes, "频率 / Hz");
                ylabel(app.SpectrumAxes, "幅度 / dB");
                title(app.SpectrumAxes, "实时 FFT 频谱");
                xlim(app.SpectrumAxes, [0, min(state.recordingFs / 2, 4000)]);
            end
            if isfield(state.liveAnalysis.latestSpectrogram, "powerDb")
                imagesc(app.SpectrogramAxes, ...
                    state.liveAnalysis.latestSpectrogram.timeAxis, ...
                    state.liveAnalysis.latestSpectrogram.frequencyAxis, ...
                    state.liveAnalysis.latestSpectrogram.powerDb);
                axis(app.SpectrogramAxes, "xy");
                ylim(app.SpectrogramAxes, [0, min(state.recordingFs / 2, 4000)]);
                xlabel(app.SpectrogramAxes, "时间 / s");
                ylabel(app.SpectrogramAxes, "频率 / Hz");
                title(app.SpectrogramAxes, "实时频谱瀑布图");
                colormap(app.SpectrogramAxes, turbo);
            end
            if ~isempty(state.liveAnalysis.frameTrend)
                latestPoint = state.liveAnalysis.frameTrend(end, :);
                bar(app.CompareAxes, latestPoint(3:5), "FaceColor", [0.53, 0.31, 0.72]);
                app.CompareAxes.XTickLabel = {"低频", "中频", "高频"};
                grid(app.CompareAxes, "on");
                ylabel(app.CompareAxes, "能量");
                title(app.CompareAxes, sprintf("分帧指标：STE %.3f | 主频 %.1f Hz", latestPoint(1), latestPoint(2)));
            end
            return;
        end

        if isempty(state.fs) || ~isfield(state.signals, char(app.StageDropDown.Value))
            cla(app.WaveAxes);
            cla(app.SpectrumAxes);
            cla(app.SpectrogramAxes);
            cla(app.CompareAxes);
            return;
        end

        selectedStage = string(app.StageDropDown.Value);
        selectedSignal = getSignal(selectedStage);
        selectedField = char(selectedStage);

        cla(app.WaveAxes);
        cla(app.SpectrumAxes);
        cla(app.SpectrogramAxes);
        cla(app.CompareAxes);

        SignalSystemDSP.drawWaveform(app.WaveAxes, selectedSignal, state.fs, ...
            state.stageLabels.(selectedField), [0.09, 0.47, 0.79]);
        SignalSystemDSP.drawSpectrum(app.SpectrumAxes, selectedSignal, state.fs, ...
            state.stageLabels.(selectedField) + " 频谱", [0.88, 0.24, 0.18]);
        SignalSystemDSP.drawSpectrogram(app.SpectrogramAxes, selectedSignal, state.fs, ...
            state.stageLabels.(selectedField) + " 时频图");

        hold(app.CompareAxes, "off");
        if isfield(state.signals, "original")
            referenceSignal = state.signals.original;
            compareLength = min(numel(referenceSignal), numel(selectedSignal));
            timeAxis = (0:compareLength - 1) / state.fs;
            plot(app.CompareAxes, timeAxis, referenceSignal(1:compareLength), ...
                "LineWidth", 1.0, "Color", [0.18, 0.18, 0.18]);
            hold(app.CompareAxes, "on");
            plot(app.CompareAxes, timeAxis, selectedSignal(1:compareLength), ...
                "LineWidth", 1.0, "Color", [0.82, 0.20, 0.24]);
            hold(app.CompareAxes, "off");
            legend(app.CompareAxes, ["原始信号", state.stageLabels.(selectedField)], "Location", "best");
            title(app.CompareAxes, "原始信号与当前阶段对比");
            xlabel(app.CompareAxes, "时间 / s");
            ylabel(app.CompareAxes, "幅值");
            grid(app.CompareAxes, "on");
        else
            SignalSystemDSP.drawWaveform(app.CompareAxes, selectedSignal, state.fs, "当前阶段波形", [0.82, 0.20, 0.24]);
        end

        refreshMetrics(selectedSignal, selectedField);
    end

    function refreshMetrics(selectedSignal, selectedField)
        referenceSignal = [];
        if isfield(state.signals, "original")
            referenceSignal = state.signals.original;
            if numel(referenceSignal) ~= numel(selectedSignal)
                referenceSignal = referenceSignal(1:min(numel(referenceSignal), numel(selectedSignal)));
                selectedSignal = selectedSignal(1:numel(referenceSignal));
            end
        end

        stageMetrics = getStageMetrics(string(selectedField));
        basicMetrics = SignalSystemDSP.computeMetrics(selectedSignal, state.fs);
        metrics = basicMetrics;
        metricText = sprintf( ...
            "阶段：%s | 采样率：%.0f Hz | 时长：%.2f s | RMS：%.3f | 峰值：%.3f | 主频：%.1f Hz", ...
            state.stageLabels.(selectedField), ...
            state.fs, ...
            basicMetrics.durationSeconds, ...
            basicMetrics.rmsValue, ...
            basicMetrics.peakValue, ...
            basicMetrics.dominantFrequencyHz);

        if false && ~isnan(metrics.snrDb)
            metricText = metricText + sprintf(" | 相对原始 SNR：%.2f dB | 评分：%d", ...
                metrics.snrDb, metrics.qualityScore);
        end

        if isstruct(stageMetrics) && isfield(stageMetrics, "snrAfterDb") && ~isnan(stageMetrics.snrAfterDb)
            if stageMetrics.snrType == "reference"
                snrLabel = "参考SNR";
            else
                snrLabel = "估计SNR";
            end
            metricText = metricText + sprintf(" | %s %.2f -> %.2f dB | 提升 %.2f dB | RMSE %.4f", ...
                snrLabel, stageMetrics.snrBeforeDb, stageMetrics.snrAfterDb, stageMetrics.snrImprovementDb, stageMetrics.rmse);
        elseif ~isnan(basicMetrics.snrDb)
            metricText = metricText + sprintf(" | 估计SNR %.2f dB", basicMetrics.snrDb);
        end

        app.MetricLabel.Text = metricText;
    end

    function refreshAnalysisViews()
        if isempty(state.fs)
            cla(app.FilterResponseAxes);
            cla(app.FilterPhaseAxes);
            cla(app.EnvelopeAxes);
            app.StageMetricsTable.Data = cell(0, 11);
            app.AnalysisNotesArea.Value = ["尚未开始分析。"; "读取信号后可在这里查看滤波响应、历史指标和推荐说明。"];
            return;
        end

        SignalSystemDSP.drawFilterResponse( ...
            app.FilterResponseAxes, ...
            app.FilterPhaseAxes, ...
            string(app.FilterDropDown.Value), ...
            state.fs, ...
            app.FilterCutoffField.Value, ...
            round(app.FilterOrderField.Value));

        if isfield(state.signals, char(app.StageDropDown.Value))
            previewSignal = [];
            if app.FilterModeDropDown.Value == "预览"
                config = struct( ...
                    "type", string(app.FilterDropDown.Value), ...
                    "cutoffHz", app.FilterCutoffField.Value, ...
                    "order", round(app.FilterOrderField.Value), ...
                    "highCutoffHz", app.FilterHighField.Value);
                try
                    [previewSignal, previewInfo] = SignalSystemDSP.applyFilter(getSignal(string(app.StageDropDown.Value)), state.fs, config);
                    state.liveAnalysis.previewSignal = previewSignal;
                    state.liveAnalysis.previewMetrics = previewInfo.metrics;
                catch
                    state.liveAnalysis.previewSignal = zeros(0, 1);
                    state.liveAnalysis.previewMetrics = struct();
                end
            else
                state.liveAnalysis.previewSignal = zeros(0, 1);
                state.liveAnalysis.previewMetrics = struct();
            end
        end

        if isfield(state.signals, char(app.StageDropDown.Value))
            currentSignal = getSignal(string(app.StageDropDown.Value));
            [timeAxis, envelope] = SignalSystemDSP.signalEnvelope(currentSignal, state.fs);
            plot(app.EnvelopeAxes, timeAxis, currentSignal, "Color", [0.72, 0.76, 0.80], "LineWidth", 0.8);
            hold(app.EnvelopeAxes, "on");
            plot(app.EnvelopeAxes, timeAxis, envelope, "Color", [0.14, 0.48, 0.73], "LineWidth", 1.2);
            if ~isempty(state.liveAnalysis.previewSignal)
                previewSignal = state.liveAnalysis.previewSignal;
                compareLength = min(numel(previewSignal), numel(timeAxis));
                plot(app.EnvelopeAxes, timeAxis(1:compareLength), previewSignal(1:compareLength), "Color", [0.84, 0.22, 0.16], "LineWidth", 1.0);
            end
            hold(app.EnvelopeAxes, "off");
            grid(app.EnvelopeAxes, "on");
            xlabel(app.EnvelopeAxes, "时间 / s");
            ylabel(app.EnvelopeAxes, "幅值");
            title(app.EnvelopeAxes, "当前阶段包络与滤波预览");
            if ~isempty(state.liveAnalysis.previewSignal)
                legend(app.EnvelopeAxes, ["波形", "包络", "预览结果"], "Location", "best");
            else
                legend(app.EnvelopeAxes, ["波形", "包络"], "Location", "best");
            end
        else
            cla(app.EnvelopeAxes);
        end

        app.StageMetricsTable.Data = buildStageMetricsTable();
        noteLines = string(splitlines(state.recommendation.summary));
        if isstruct(state.liveAnalysis.previewMetrics) && isfield(state.liveAnalysis.previewMetrics, "snrDb")
            noteLines = [noteLines; ...
                "滤波预览指标："; ...
                sprintf("SNR %.2f dB | MSE %.5f | RMSE %.5f", ...
                    state.liveAnalysis.previewMetrics.snrDb, ...
                    state.liveAnalysis.previewMetrics.mse, ...
                    state.liveAnalysis.previewMetrics.rmse)];
        end
        currentStage = string(app.StageDropDown.Value);
        currentMetrics = getStageMetrics(currentStage);
        if isstruct(currentMetrics) && isfield(currentMetrics, "snrAfterDb")
            noteLines = [noteLines; ...
                "当前阶段量化评价："; ...
                buildMetricsSummaryLine(currentMetrics); ...
                buildBandSummaryLine("处理前频带占比", currentMetrics.bandEnergyRatioBefore); ...
                buildBandSummaryLine("处理后频带占比", currentMetrics.bandEnergyRatioAfter); ...
                buildBandSummaryLine("频带占比变化", currentMetrics.bandEnergyRatioDelta); ...
                "评价：" + string(currentMetrics.evaluationText)];
        end
        if isfield(state.liveAnalysis.lastCommInfo, "bitErrorRate")
            noteLines = [noteLines; ...
                sprintf("最近通信链 BER：%.5f", state.liveAnalysis.lastCommInfo.bitErrorRate)];
        end
        app.AnalysisNotesArea.Value = noteLines;
    end

    function tableData = buildStageMetricsTable()
        tableData = cell(0, 11);
        if ~isfield(state.signals, "original") || isempty(state.fs)
            return;
        end

        for idx = 1:numel(state.stageOrder)
            fieldName = char(state.stageOrder(idx));
            if ~isfield(state.signals, fieldName)
                continue;
            end

            metrics = getStageMetrics(string(fieldName));
            if ~isstruct(metrics) || isempty(fieldnames(metrics))
                continue;
            end
            tableData(end + 1, :) = { ...
                char(state.stageLabels.(fieldName)), ...
                formatMetric(metrics.snrBeforeDb), ...
                formatMetric(metrics.snrAfterDb), ...
                formatMetric(metrics.snrImprovementDb), ...
                formatMetric(metrics.mse), ...
                formatMetric(metrics.rmse), ...
                formatMetric(metrics.beforeTotalEnergy), ...
                formatMetric(metrics.afterTotalEnergy), ...
                formatMetric(metrics.dominantFrequencyDeltaHz), ...
                formatMetric(metrics.spectrumPeakDeltaDb), ...
                char(string(metrics.evaluationText))}; %#ok<AGROW>
        end
    end

    function valueText = formatMetric(value)
        if isnan(value)
            valueText = "--";
        elseif isinf(value)
            valueText = "Inf";
        elseif abs(value) >= 100
            valueText = round(value);
        else
            valueText = round(value, 2);
        end
    end

    function metrics = getStageMetrics(stageKey)
        metrics = struct();
        fieldName = char(stageKey);
        if isfield(state.stageMeta, fieldName) ...
                && isstruct(state.stageMeta.(fieldName)) ...
                && isfield(state.stageMeta.(fieldName), "metrics")
            metrics = state.stageMeta.(fieldName).metrics;
        end
    end

    function summaryLine = buildMetricsSummaryLine(metrics)
        if metrics.snrType == "reference"
            snrLabel = "参考SNR";
        else
            snrLabel = "估计SNR";
        end
        summaryLine = sprintf("%s %.2f -> %.2f dB | 提升 %.2f dB | MSE %.5f | RMSE %.5f | 主频变化 %.1f Hz | 峰值变化 %.2f dB", ...
            snrLabel, metrics.snrBeforeDb, metrics.snrAfterDb, metrics.snrImprovementDb, ...
            metrics.mse, metrics.rmse, metrics.dominantFrequencyDeltaHz, metrics.spectrumPeakDeltaDb);
    end

    function summaryLine = buildBandSummaryLine(prefixText, bandRatio)
        summaryLine = sprintf("%s: 低频 %.1f%% | 语音 %.1f%% | 高频 %.1f%%", ...
            prefixText, 100 * bandRatio.low, 100 * bandRatio.speech, 100 * bandRatio.high);
    end

    function fileName = defaultMetricsFileName(stageKey)
        switch char(stageKey)
            case "filtered"
                fileName = "filtered_result_metrics.csv";
            case "enhanced"
                fileName = "denoise_metrics.csv";
            case "effect"
                fileName = "voice_change_metrics.csv";
            otherwise
                fileName = char(lower(string(stageKey)) + "_metrics.csv");
        end
    end

    function filePath = exportStageMetricsCsv(stageKey)
        assertSignalLoaded();
        metrics = getStageMetrics(stageKey);
        if ~isstruct(metrics) || isempty(fieldnames(metrics))
            error("当前阶段没有可导出的量化指标。");
        end
        outputDir = fullfile(state.baseDir, "outputs");
        fileName = defaultMetricsFileName(stageKey);
        moduleName = "";
        fieldName = char(stageKey);
        if isfield(state.stageMeta, fieldName) && isfield(state.stageMeta.(fieldName), "module")
            moduleName = string(state.stageMeta.(fieldName).module);
        end
        filePath = SignalSystemDSP.exportMetricsCsv(outputDir, fileName, metrics, stageKey, moduleName);
    end

    function exportCurrentMetricsCsvCallback()
        try
            stageKey = string(app.StageDropDown.Value);
            filePath = exportStageMetricsCsv(stageKey);
            addLog("已导出指标 CSV：" + string(filePath));
        catch exportEx
            addLog("指标 CSV 导出失败：" + string(exportEx.message));
        end
    end

    function exportMetricsSnapshotCallback()
        try
            assertSignalLoaded();
            stageKey = string(app.StageDropDown.Value);
            metrics = getStageMetrics(stageKey);
            if ~isstruct(metrics) || isempty(fieldnames(metrics))
                error("当前阶段没有可导出的指标截图。");
            end

            outputDir = fullfile(state.baseDir, "outputs");
            if ~exist(outputDir, "dir")
                mkdir(outputDir);
            end

            stageTitle = state.stageLabels.(char(stageKey));
            fig = figure("Visible", "off", "Color", "w", "Position", [120, 120, 1220, 760]);
            annotation(fig, "textbox", [0.04, 0.88, 0.92, 0.08], ...
                "String", stageTitle + " 指标截图", ...
                "LineStyle", "none", ...
                "FontSize", 20, ...
                "FontWeight", "bold", ...
                "FontName", "Microsoft YaHei");
            summaryLines = { ...
                char(buildMetricsSummaryLine(metrics)); ...
                char(buildBandSummaryLine("处理前频带占比", metrics.bandEnergyRatioBefore)); ...
                char(buildBandSummaryLine("处理后频带占比", metrics.bandEnergyRatioAfter)); ...
                char(buildBandSummaryLine("频带占比变化", metrics.bandEnergyRatioDelta)); ...
                char("评价：" + string(metrics.evaluationText))};
            annotation(fig, "textbox", [0.05, 0.52, 0.90, 0.28], ...
                "String", strjoin(summaryLines, newline), ...
                "FitBoxToText", "off", ...
                "FontSize", 13, ...
                "BackgroundColor", [0.98, 0.98, 0.98], ...
                "FontName", "Consolas");

            metricTableData = { ...
                "SNR前(dB)", formatMetric(metrics.snrBeforeDb); ...
                "SNR后(dB)", formatMetric(metrics.snrAfterDb); ...
                "提升(dB)", formatMetric(metrics.snrImprovementDb); ...
                "MSE", formatMetric(metrics.mse); ...
                "RMSE", formatMetric(metrics.rmse); ...
                "能量前", formatMetric(metrics.beforeTotalEnergy); ...
                "能量后", formatMetric(metrics.afterTotalEnergy); ...
                "主频变化(Hz)", formatMetric(metrics.dominantFrequencyDeltaHz); ...
                "峰值变化(dB)", formatMetric(metrics.spectrumPeakDeltaDb)};
            uitable(fig, ...
                "Data", metricTableData, ...
                "ColumnName", {"指标", "数值"}, ...
                "Position", [60, 80, 420, 300], ...
                "ColumnWidth", {180, 180});
            exportPath = fullfile(outputDir, char(lower(stageKey) + "_metrics_snapshot.png"));
            exportgraphics(fig, exportPath, "Resolution", 220);
            close(fig);
            addLog("已导出指标截图：" + string(exportPath));
        catch exportEx
            addLog("指标截图导出失败：" + string(exportEx.message));
        end
    end

    function refreshModulationViews()
        axesNames = ["CommOriginalAxes", "ModWaveAxes", "ChannelWaveAxes", "ModSpectrumAxes", "ConstellationAxes", "DemodWaveAxes"];
        for idx = 1:numel(axesNames)
            if isfield(app, char(axesNames(idx))) && isvalid(app.(char(axesNames(idx))))
                cla(app.(char(axesNames(idx))));
            end
        end
        if ~isfield(app, "CommInfoArea") || isempty(app.CommInfoArea) || ~isvalid(app.CommInfoArea)
            return;
        end
        if isempty(state.fs) || ~isfield(state.liveAnalysis, "lastCommChain") || ~isstruct(state.liveAnalysis.lastCommChain) || ~isfield(state.liveAnalysis.lastCommChain, "modulated")
            title(app.CommOriginalAxes, "原始输入"); grid(app.CommOriginalAxes, "on");
            title(app.ModWaveAxes, "调制波形"); grid(app.ModWaveAxes, "on");
            title(app.ChannelWaveAxes, "信道加噪波形"); grid(app.ChannelWaveAxes, "on");
            title(app.ModSpectrumAxes, "调制频谱"); grid(app.ModSpectrumAxes, "on");
            title(app.ConstellationAxes, "星座图"); grid(app.ConstellationAxes, "on");
            title(app.DemodWaveAxes, "解调/恢复结果"); grid(app.DemodWaveAxes, "on");
            app.CommInfoArea.Value = ["尚未运行通信链。"; "请选择 AM/FM/ASK/FSK/BPSK/QPSK 后点击“运行通信链”。"];
            if isfield(app, "BitCompareArea") && isvalid(app.BitCompareArea)
                app.BitCompareArea.Value = ["尚未运行通信链。"; "BPSK/QPSK/ASK/FSK 运行后，这里会显示比特预览与恢复结果。"];
            end
            if isfield(app, "CommStatusLabel") && isvalid(app.CommStatusLabel)
                app.CommStatusLabel.Text = "通信链状态：尚未运行";
            end
            return;
        end

        chain = state.liveAnalysis.lastCommChain;
        info = state.liveAnalysis.lastCommInfo;
        sourcePreview = [];
        if isfield(chain, "sourcePreview") && ~isempty(chain.sourcePreview)
            sourcePreview = chain.sourcePreview;
        elseif isfield(chain, "original") && ~isempty(chain.original)
            sourcePreview = chain.original;
        elseif isfield(state.signals, "original") && ~isempty(state.signals.original)
            sourcePreview = state.signals.original;
        end

        if ~isempty(sourcePreview)
            SignalSystemDSP.drawWaveform(app.CommOriginalAxes, sourcePreview(:), state.fs, "原始输入 / 比特源", [0.10, 0.45, 0.78]);
        else
            title(app.CommOriginalAxes, "原始输入"); grid(app.CommOriginalAxes, "on");
        end

        SignalSystemDSP.drawWaveform(app.ModWaveAxes, chain.modulated(:), state.fs, "调制信号波形", [0.72, 0.24, 0.24]);
        if isfield(chain, "channel") && ~isempty(chain.channel)
            SignalSystemDSP.drawWaveform(app.ChannelWaveAxes, chain.channel(:), state.fs, "信道加噪后波形", [0.55, 0.32, 0.73]);
        else
            title(app.ChannelWaveAxes, "信道加噪波形"); grid(app.ChannelWaveAxes, "on");
        end
        SignalSystemDSP.drawSpectrum(app.ModSpectrumAxes, chain.modulated(:), state.fs, "调制信号频谱", [0.88, 0.48, 0.14]);

        if isfield(info, "constellation") && isstruct(info.constellation) && (isfield(info.constellation, "tx") || isfield(info.constellation, "rx"))
            SignalSystemDSP.drawConstellation(app.ConstellationAxes, info.constellation, "星座图");
        else
            title(app.ConstellationAxes, "当前调制方式无星座图"); grid(app.ConstellationAxes, "on");
        end

        if isfield(chain, "restored") && ~isempty(chain.restored)
            SignalSystemDSP.drawWaveform(app.DemodWaveAxes, chain.restored(:), state.fs, "解调/恢复结果", [0.16, 0.55, 0.36]);
        else
            title(app.DemodWaveAxes, "解调/恢复结果"); grid(app.DemodWaveAxes, "on");
        end

        berText = "BER = --";
        if isfield(info, "bitErrorRate") && ~isempty(info.bitErrorRate) && isfinite(info.bitErrorRate)
            berText = sprintf("BER = %.5f", info.bitErrorRate);
        end
        sourceBerText = "源比特 BER = --";
        if isfield(info, "sourceBitErrorRate") && ~isempty(info.sourceBitErrorRate) && isfinite(info.sourceBitErrorRate)
            sourceBerText = sprintf("源比特 BER = %.5f", info.sourceBitErrorRate);
        end
        summaryText = "模拟通信链路";
        if isfield(info, "bitSummary") && strlength(string(info.bitSummary)) > 0
            summaryText = string(info.bitSummary);
        end
        if isfield(app, "BitCompareArea") && isvalid(app.BitCompareArea)
            if isfield(info, "bitPreviewLines") && ~isempty(info.bitPreviewLines)
                app.BitCompareArea.Value = string(info.bitPreviewLines(:));
            else
                app.BitCompareArea.Value = ["当前链路未生成离散比特预览。"; "AM/FM 模式主要显示波形、频谱和恢复结果。"];
            end
        end
        if isfield(app, "CommStatusLabel") && isvalid(app.CommStatusLabel)
            app.CommStatusLabel.Text = "通信链状态：已完成 " + string(info.config.modulationType);
        end

        modulationDescription = "--";
        if isfield(info, "modulationInfo") && isfield(info.modulationInfo, "description")
            modulationDescription = string(info.modulationInfo.description);
        end
        demodulationDescription = "--";
        if isfield(info, "demodulationInfo") && isfield(info.demodulationInfo, "description")
            demodulationDescription = string(info.demodulationInfo.description);
        end
        app.CommInfoArea.Value = [ ...
            "调制方式：" + string(info.config.modulationType); ...
            "载波频率：" + sprintf("%.0f Hz", info.config.carrierHz); ...
            "信道 SNR：" + sprintf("%.1f dB", info.config.channelSnrDb); ...
            berText; ...
            sourceBerText; ...
            "链路说明：" + summaryText; ...
            "调制说明：" + modulationDescription; ...
            "解调说明：" + demodulationDescription];
    end

    function refreshComparisonView()
        renderComparisonView();
        return;
        if isempty(state.fs) || ~isfield(state.signals, char(app.CompareStageADropDown.Value)) || ~isfield(state.signals, char(app.CompareStageBDropDown.Value))
            cla(app.CompareOverlayAxes);
            cla(app.CompareSpectrumAxes);
            cla(app.CompareDiffAxes);
            app.CompareInfoArea.Value = ["尚未加载足够的阶段数据。"; "完成处理后，可在这里比较任意两个阶段。"];
            return;
        end

        stageA = string(app.CompareStageADropDown.Value);
        stageB = string(app.CompareStageBDropDown.Value);
        signalA = getSignal(stageA);
        signalB = getSignal(stageB);
        compareLength = min(numel(signalA), numel(signalB));
        signalA = signalA(1:compareLength);
        signalB = signalB(1:compareLength);

        timeAxis = (0:compareLength - 1) / state.fs;
        plot(app.CompareOverlayAxes, timeAxis, signalA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
        hold(app.CompareOverlayAxes, "on");
        plot(app.CompareOverlayAxes, timeAxis, signalB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
        hold(app.CompareOverlayAxes, "off");
        grid(app.CompareOverlayAxes, "on");
        xlabel(app.CompareOverlayAxes, "时间 / s");
        ylabel(app.CompareOverlayAxes, "幅值");
        title(app.CompareOverlayAxes, "阶段 A/B 时域对比");
        legend(app.CompareOverlayAxes, [state.stageLabels.(char(stageA)), state.stageLabels.(char(stageB))], "Location", "best");

        [fA, magA] = SignalSystemDSP.magnitudeSpectrum(signalA, state.fs);
        [fB, magB] = SignalSystemDSP.magnitudeSpectrum(signalB, state.fs);
        plot(app.CompareSpectrumAxes, fA, magA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
        hold(app.CompareSpectrumAxes, "on");
        plot(app.CompareSpectrumAxes, fB, magB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
        hold(app.CompareSpectrumAxes, "off");
        grid(app.CompareSpectrumAxes, "on");
        xlabel(app.CompareSpectrumAxes, "频率 / Hz");
        ylabel(app.CompareSpectrumAxes, "幅度 / dB");
        title(app.CompareSpectrumAxes, "阶段 A/B 叠加频谱");
        legend(app.CompareSpectrumAxes, [state.stageLabels.(char(stageA)), state.stageLabels.(char(stageB))], "Location", "best");
        xlim(app.CompareSpectrumAxes, [0, min(state.fs / 2, 4000)]);

        differenceSignal = signalA - signalB;
        SignalSystemDSP.drawSpectrum(app.CompareDiffAxes, differenceSignal, state.fs, ...
            "A/B 差分频谱", [0.55, 0.19, 0.68]);

        comparison = SignalSystemDSP.compareSignals(signalA, signalB);
        app.CompareInfoArea.Value = [ ...
            "比较结果：" ...
            ; "A 阶段：" + state.stageLabels.(char(stageA)) ...
            ; "B 阶段：" + state.stageLabels.(char(stageB)) ...
            ; sprintf("相关系数：%.4f", comparison.correlation) ...
            ; sprintf("B 相对 A 的 SNR：%.2f dB", comparison.snrDb) ...
            ; sprintf("均方根误差：%.5f", comparison.rmse) ...
            ; sprintf("质量评分：%d / 100", comparison.qualityScore)];
    end

    % Build aligned A/B comparison context for plotting, playback and export.
    function compareContext = buildCompareContext()
        compareContext = [];
        if isempty(state.fs) || ~isfield(state.signals, char(app.CompareStageADropDown.Value)) || ~isfield(state.signals, char(app.CompareStageBDropDown.Value))
            return;
        end

        try
            stageA = string(app.CompareStageADropDown.Value);
            stageB = string(app.CompareStageBDropDown.Value);
            signalA = getSignal(stageA);
            signalB = getSignal(stageB);
            fsA = getStageSampleRate(stageA);
            fsB = getStageSampleRate(stageB);
            compareInfo = SignalSystemDSP.compareStagePair(signalA, signalB, fsA, fsB);
            if compareInfo.pairInfo.alignedLength < 2
                compareContext = [];
                return;
            end
            compareContext = struct( ...
                "stageA", stageA, ...
                "stageB", stageB, ...
                "labelA", string(state.stageLabels.(char(stageA))), ...
                "labelB", string(state.stageLabels.(char(stageB))), ...
                "info", compareInfo);
        catch
            compareContext = [];
        end
    end

    % Resolve the sampling rate stored with a historical stage.
    function fsValue = getStageSampleRate(stageKey)
        fsValue = state.fs;
        fieldName = char(stageKey);
        if isfield(state.stageMeta, fieldName) && isfield(state.stageMeta.(fieldName), "fs") ...
                && ~isempty(state.stageMeta.(fieldName).fs)
            fsValue = state.stageMeta.(fieldName).fs;
        end
    end

    % Clear all A/B comparison axes when no valid comparison is available.
    function clearCompareAxes()
        axesNames = { ...
            "CompareWaveAAxes", "CompareWaveBAxes", "CompareDiffWaveAxes", ...
            "CompareOverlayAxes", "CompareSpectrumAAxes", "CompareSpectrumBAxes", "CompareDiffAxes"};
        for idx = 1:numel(axesNames)
            fieldName = axesNames{idx};
            if isfield(app, fieldName) && ~isempty(app.(fieldName)) && isvalid(app.(fieldName))
                cla(app.(fieldName));
            end
        end
    end

    % Render all A/B comparison views from the latest aligned comparison context.
    function renderComparisonView()
        compareContext = buildCompareContext();
        if isempty(compareContext)
            clearCompareAxes();
            app.CompareInfoArea.Value = ["尚未加载足够的阶段数据。"; "完成处理后，可在这里比较任意两个阶段。"];
            return;
        end

        compareInfo = compareContext.info;
        timeAxis = (0:compareInfo.pairInfo.alignedLength - 1) / compareInfo.pairInfo.compareFs;
        SignalSystemDSP.drawWaveform(app.CompareWaveAAxes, compareInfo.pairInfo.signalA, compareInfo.pairInfo.compareFs, ...
            compareContext.labelA + " 波形", [0.12, 0.45, 0.73]);
        SignalSystemDSP.drawWaveform(app.CompareWaveBAxes, compareInfo.pairInfo.signalB, compareInfo.pairInfo.compareFs, ...
            compareContext.labelB + " 波形", [0.79, 0.24, 0.24]);
        SignalSystemDSP.drawWaveform(app.CompareDiffWaveAxes, compareInfo.pairInfo.differenceSignal, compareInfo.pairInfo.compareFs, ...
            "差分波形", [0.55, 0.19, 0.68]);

        plot(app.CompareOverlayAxes, timeAxis, compareInfo.pairInfo.signalA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
        hold(app.CompareOverlayAxes, "on");
        plot(app.CompareOverlayAxes, timeAxis, compareInfo.pairInfo.signalB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
        hold(app.CompareOverlayAxes, "off");
        grid(app.CompareOverlayAxes, "on");
        xlabel(app.CompareOverlayAxes, "时间 / s");
        ylabel(app.CompareOverlayAxes, "幅值");
        title(app.CompareOverlayAxes, "A/B 叠加波形");
        legend(app.CompareOverlayAxes, [compareContext.labelA, compareContext.labelB], "Location", "best");

        plot(app.CompareSpectrumAAxes, compareInfo.frequencyAxis, compareInfo.magnitudeA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
        grid(app.CompareSpectrumAAxes, "on");
        xlabel(app.CompareSpectrumAAxes, "频率 / Hz");
        ylabel(app.CompareSpectrumAAxes, "幅度 / dB");
        title(app.CompareSpectrumAAxes, compareContext.labelA + " 频谱");
        xlim(app.CompareSpectrumAAxes, [0, min(compareInfo.pairInfo.compareFs / 2, 4000)]);

        plot(app.CompareSpectrumBAxes, compareInfo.frequencyAxis, compareInfo.magnitudeB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
        grid(app.CompareSpectrumBAxes, "on");
        xlabel(app.CompareSpectrumBAxes, "频率 / Hz");
        ylabel(app.CompareSpectrumBAxes, "幅度 / dB");
        title(app.CompareSpectrumBAxes, compareContext.labelB + " 频谱");
        xlim(app.CompareSpectrumBAxes, [0, min(compareInfo.pairInfo.compareFs / 2, 4000)]);

        plot(app.CompareDiffAxes, compareInfo.frequencyAxis, compareInfo.spectrumDeltaDb, "LineWidth", 1.0, "Color", [0.55, 0.19, 0.68]);
        grid(app.CompareDiffAxes, "on");
        xlabel(app.CompareDiffAxes, "频率 / Hz");
        ylabel(app.CompareDiffAxes, "差分 / dB");
        title(app.CompareDiffAxes, "差分频谱");
        xlim(app.CompareDiffAxes, [0, min(compareInfo.pairInfo.compareFs / 2, 4000)]);

        app.CompareInfoArea.Value = buildCompareInfoLines(compareContext);
    end

    % Summarize A/B metrics, lengths and sampling rates for the compare panel.
    function infoLines = buildCompareInfoLines(compareContext)
        compareInfo = compareContext.info;
        infoLines = [ ...
            "A/B 对比结果"; ...
            "A 阶段：" + compareContext.labelA; ...
            "B 阶段：" + compareContext.labelB; ...
            sprintf("采样率：A %.0f Hz | B %.0f Hz | 对齐 %.0f Hz", ...
                compareInfo.pairInfo.fsA, compareInfo.pairInfo.fsB, compareInfo.pairInfo.compareFs); ...
            sprintf("长度：A %d | B %d | 对齐 %d", ...
                compareInfo.pairInfo.originalLengthA, compareInfo.pairInfo.originalLengthB, compareInfo.pairInfo.alignedLength); ...
            sprintf("总能量：A %.5f | B %.5f", ...
                compareInfo.metricsA.totalEnergy, compareInfo.metricsB.totalEnergy); ...
            sprintf("MSE %.5f | RMSE %.5f | 相关系数 %.4f", ...
                compareInfo.comparison.mse, compareInfo.comparison.rmse, compareInfo.comparison.correlation); ...
            sprintf("频谱差异指标 %.3f dB | 差分峰值 %.4f", ...
                compareInfo.spectralDifferenceDb, compareInfo.diffSignalPeak)];
        if compareInfo.pairInfo.resampled
            infoLines = [infoLines; "已自动重采样到统一采样率。"];
        end
    end

    % Build a stable export prefix for A/B comparison artifacts.
    function prefix = getCompareExportPrefix(compareContext)
        outputDir = fullfile(state.baseDir, "outputs");
        if ~exist(outputDir, "dir")
            mkdir(outputDir);
        end
        prefix = string(fullfile(outputDir, sprintf("ab_compare_%s_vs_%s_%s", ...
            char(compareContext.stageA), char(compareContext.stageB), datestr(now, "yyyymmdd_HHMMSS"))));
    end

    % Export comparison figures, metrics and difference audio in one bundle.
    function exportCompareBundleCallback()
        compareContext = buildCompareContext();
        if isempty(compareContext)
            addLog("A/B 对比导出失败：当前没有可用的比较结果。");
            return;
        end
        exportInfo = SignalSystemDSP.exportComparisonBundle(string(fullfile(state.baseDir, "outputs")), ...
            compareContext.labelA, compareContext.labelB, compareContext.info);
        addLog("A/B 对比导出完成：" + exportInfo.overviewPath);
    end

    % Export only the current A/B metrics table as CSV.
    function exportCompareMetricsCallback()
        compareContext = buildCompareContext();
        if isempty(compareContext)
            addLog("A/B 指标表导出失败：当前没有可用的比较结果。");
            return;
        end
        prefix = getCompareExportPrefix(compareContext);
        metricTable = table( ...
            compareContext.labelA, compareContext.labelB, ...
            compareContext.info.pairInfo.fsA, compareContext.info.pairInfo.fsB, compareContext.info.pairInfo.compareFs, ...
            compareContext.info.pairInfo.originalLengthA, compareContext.info.pairInfo.originalLengthB, compareContext.info.pairInfo.alignedLength, ...
            compareContext.info.metricsA.totalEnergy, compareContext.info.metricsB.totalEnergy, ...
            compareContext.info.comparison.mse, compareContext.info.comparison.rmse, compareContext.info.spectralDifferenceDb, ...
            'VariableNames', {'stage_a','stage_b','fs_a','fs_b','compare_fs','length_a','length_b','aligned_length','energy_a','energy_b','mse','rmse','spectral_difference_db'});
        outputPath = string(prefix + "_metrics.csv");
        writetable(metricTable, outputPath);
        addLog("已导出 A/B 指标表：" + outputPath);
    end

    % Export the current difference spectrum as a standalone figure.
    function exportDiffSpectrumCallback()
        compareContext = buildCompareContext();
        if isempty(compareContext)
            addLog("差分频谱导出失败：当前没有可用的比较结果。");
            return;
        end
        prefix = getCompareExportPrefix(compareContext);
        fig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1180, 420]);
        ax = axes(fig);
        plot(ax, compareContext.info.frequencyAxis, compareContext.info.spectrumDeltaDb, ...
            "LineWidth", 1.1, "Color", [0.55, 0.19, 0.68]);
        grid(ax, "on");
        xlabel(ax, "Frequency / Hz");
        ylabel(ax, "Delta / dB");
        title(ax, "Difference Spectrum");
        xlim(ax, [0, min(compareContext.info.pairInfo.compareFs / 2, 4000)]);
        outputPath = string(prefix + "_diff_spectrum.png");
        exportgraphics(fig, outputPath, "Resolution", 220);
        close(fig);
        addLog("已导出差分频谱：" + outputPath);
    end

    % Export the current difference audio as a WAV file.
    function exportDiffAudioCallback()
        compareContext = buildCompareContext();
        if isempty(compareContext)
            addLog("差分音频导出失败：当前没有可用的比较结果。");
            return;
        end
        prefix = getCompareExportPrefix(compareContext);
        outputPath = string(prefix + "_difference.wav");
        audiowrite(outputPath, SignalSystemDSP.normalizeAudio(compareContext.info.pairInfo.differenceSignal), ...
            compareContext.info.pairInfo.compareFs);
        addLog("已导出差分音频：" + outputPath);
    end

    function refreshVoiceViews()
        if ~isfield(app, "VoiceOriginalWaveAxes") || isempty(app.VoiceOriginalWaveAxes) || ~isvalid(app.VoiceOriginalWaveAxes)
            return;
        end

        cla(app.VoiceOriginalWaveAxes);
        cla(app.VoiceProcessedWaveAxes);
        cla(app.VoiceOriginalSpectrumAxes);
        cla(app.VoiceProcessedSpectrumAxes);
        cla(app.VoiceDiffSpectrumAxes);

        if isempty(state.fs) || ~isfield(state.signals, "original")
            app.VoiceMetricsArea.Value = ["尚未载入原始语音。"; "请先读取音频、录音或生成测试信号。"];
            return;
        end

        originalSignal = state.signals.original;
        SignalSystemDSP.drawWaveform(app.VoiceOriginalWaveAxes, originalSignal, state.fs, "原始波形", [0.10, 0.45, 0.72]);
        SignalSystemDSP.drawSpectrum(app.VoiceOriginalSpectrumAxes, originalSignal, state.fs, "原始频谱", [0.10, 0.45, 0.72]);

        if ~isfield(state.signals, "effect")
            title(app.VoiceProcessedWaveAxes, "变声后波形");
            title(app.VoiceProcessedSpectrumAxes, "变声后频谱");
            title(app.VoiceDiffSpectrumAxes, "频谱差异");
            app.VoiceMetricsArea.Value = ["尚未生成变声结果。"; "在“变声器”页点击“应用变声”后，这里会显示处理后的波形、频谱和差异。"];
            return;
        end

        processedSignal = state.signals.effect;
        SignalSystemDSP.drawWaveform(app.VoiceProcessedWaveAxes, processedSignal, state.fs, "变声后波形", [0.76, 0.22, 0.24]);
        SignalSystemDSP.drawSpectrum(app.VoiceProcessedSpectrumAxes, processedSignal, state.fs, "变声后频谱", [0.76, 0.22, 0.24]);

        compareLength = min(numel(originalSignal), numel(processedSignal));
        differenceSignal = processedSignal(1:compareLength) - originalSignal(1:compareLength);
        SignalSystemDSP.drawSpectrum(app.VoiceDiffSpectrumAxes, differenceSignal, state.fs, "频谱差异", [0.55, 0.19, 0.68]);

        comparison = SignalSystemDSP.compareSignals(originalSignal(1:compareLength), processedSignal(1:compareLength));
        [~, originalEnvelope] = SignalSystemDSP.signalEnvelope(originalSignal(1:compareLength), state.fs);
        [~, processedEnvelope] = SignalSystemDSP.signalEnvelope(processedSignal(1:compareLength), state.fs);
        app.VoiceMetricsArea.Value = [ ...
            "变声结果概览"; ...
            "模式：" + string(app.VoiceModeDropDown.Value); ...
            sprintf("时长：%.2f s", compareLength / state.fs); ...
            sprintf("SNR：%.2f dB", comparison.snrDb); ...
            sprintf("相关系数：%.4f", comparison.correlation); ...
            sprintf("RMSE：%.5f", comparison.rmse); ...
            sprintf("质量评分：%d / 100", comparison.qualityScore); ...
            sprintf("原始包络均值：%.4f", mean(originalEnvelope, "omitnan")); ...
            sprintf("变声包络均值：%.4f", mean(processedEnvelope, "omitnan"))];
    end

    function refreshStatusCards()
        app.SourceCardValue.Text = char(state.sourceLabel);
        app.StageCardValue.Text = char(state.stageLabels.(char(state.currentStage)));

        if isempty(state.fs)
            app.FsCardValue.Text = "--";
            app.ScoreCardValue.Text = "--";
            return;
        end

        app.FsCardValue.Text = sprintf("%.0f Hz", state.fs);
        if isfield(state.signals, char(state.currentStage))
            currentSignal = getSignal(state.currentStage);
            if isfield(state.signals, "original")
                referenceSignal = state.signals.original;
                compareLength = min(numel(referenceSignal), numel(currentSignal));
                comparison = SignalSystemDSP.compareSignals(referenceSignal(1:compareLength), currentSignal(1:compareLength));
                app.ScoreCardValue.Text = sprintf("%d / 100", comparison.qualityScore);
            else
                app.ScoreCardValue.Text = "--";
            end
        else
            app.ScoreCardValue.Text = "--";
        end
    end

    function refreshSignalInfo()
        if isempty(state.fs) || ~isfield(state.signals, char(state.currentStage))
            infoLines = ["尚未加载信号。"; "完成处理后，这里会显示来源、阶段链路和关键指标。"];
            if state.isRecording || ~isempty(state.recordingBuffer)
                infoLines = [infoLines; ...
                    "录音状态：" + state.recordingStatus; ...
                    sprintf("录音缓存时长：%.2f 秒", state.recordingElapsedSeconds); ...
                    sprintf("录音峰值：%.3f", state.recordingPeak); ...
                    "提示：点击“载入处理链”可把录音作为输入信号。"]; %#ok<AGROW>
            end
            app.SignalInfoArea.Value = infoLines;
            return;
        end

        currentSignal = getSignal(state.currentStage);
        stageList = strings(0, 1);
        for idx = 1:numel(state.stageOrder)
            fieldName = char(state.stageOrder(idx));
            if isfield(state.signals, fieldName)
                stageList(end + 1, 1) = state.stageLabels.(fieldName); %#ok<AGROW>
            end
        end

        infoLines = [ ...
            "来源：" + state.sourceLabel ...
            ; sprintf("当前阶段：%s", state.stageLabels.(char(state.currentStage))) ...
            ; sprintf("采样率：%.0f Hz", state.fs) ...
            ; sprintf("样本数：%d", numel(currentSignal)) ...
            ; sprintf("时长：%.2f 秒", numel(currentSignal) / state.fs) ...
            ; "已生成阶段：" + strjoin(stageList, " -> ")];
        if state.isRecording || ~isempty(state.recordingBuffer)
            infoLines = [infoLines; ...
                "录音状态：" + state.recordingStatus; ...
                sprintf("录音缓存时长：%.2f 秒", state.recordingElapsedSeconds); ...
                sprintf("录音峰值：%.3f", state.recordingPeak)]; %#ok<AGROW>
        end
        app.SignalInfoArea.Value = infoLines;
    end

    function loadSampleCallback()
        clearRecordingState();
        [signalValue, fsValue, label] = SignalSystemDSP.loadSample(string(app.SampleDropDown.Value), state.baseDir);
        state.fs = fsValue;
        state.signals = struct();
        state.stageMeta = struct();
        state.cryptoInfo = [];
        setSignal("original", signalValue, label);
        setStageMeta("original", buildStageMeta("读取样例", "样例语音已载入", signalValue, signalValue));
        addLog(sprintf("已读取 %s，采样率 %.0f Hz，样本数 %d。", label, fsValue, numel(signalValue)));
        refreshAllViews();
    end

    function loadFileCallback()
        [fileName, fileDir] = uigetfile({"*.wav;*.mp3;*.m4a;*.flac", "音频文件"; "*.*", "所有文件"}, "选择本地音频");
        if isequal(fileName, 0)
            return;
        end

        clearRecordingState();
        fullPath = string(fullfile(fileDir, fileName));
        [signalValue, fsValue, label] = SignalSystemDSP.loadAudioFile(fullPath);
        state.fs = fsValue;
        state.signals = struct();
        state.stageMeta = struct();
        state.cryptoInfo = [];
        setSignal("original", signalValue, label);
        setStageMeta("original", buildStageMeta("读取本地音频", "外部音频已载入", signalValue, signalValue));
        addLog(sprintf("已载入外部音频 %s，采样率 %.0f Hz。", fileName, fsValue));
        refreshAllViews();
    end

    function generateSyntheticCallback()
        clearRecordingState();
        [signalValue, fsValue, label] = SignalSystemDSP.generateSyntheticSignal( ...
            app.SyntheticFsField.Value, ...
            app.SyntheticDurationField.Value);
        state.fs = fsValue;
        state.signals = struct();
        state.stageMeta = struct();
        state.cryptoInfo = [];
        setSignal("original", signalValue, label);
        setStageMeta("original", buildStageMeta("合成信号", "合成测试信号已生成", signalValue, signalValue));
        addLog(sprintf("已生成 %.1f 秒合成测试信号，采样率 %.0f Hz。", app.SyntheticDurationField.Value, fsValue));
        refreshAllViews();
    end

    function resetToOriginalCallback()
        if ~isfield(state.signals, "original")
            return;
        end

        originalSignal = state.signals.original;
        state.signals = struct();
        state.stageMeta = struct();
        state.cryptoInfo = [];
        setSignal("original", originalSignal, state.sourceLabel);
        setStageMeta("original", buildStageMeta("重置", "已重置到原始信号", originalSignal, originalSignal));
        addLog("已重置到原始信号。");
        refreshAllViews();
    end

    function addNoiseCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        [noisySignal, info] = SignalSystemDSP.addNoise(signalValue, state.fs, string(app.NoiseDropDown.Value), app.NoiseLevelSlider.Value);
        setSignal("noisy", noisySignal, "");
        setStageMeta("noisy", buildStageMeta("噪声添加", info.description, signalValue, noisySignal));
        try
            exportStageMetricsCsv("noisy");
        catch
        end
        addLog(sprintf("噪声模块执行完成：%s，估计 SNR %.2f dB。", info.description, info.estimatedSNR));
        refreshAllViews();
    end

    function filterCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        config = struct( ...
            "type", string(app.FilterDropDown.Value), ...
            "cutoffHz", app.FilterCutoffField.Value, ...
            "order", round(app.FilterOrderField.Value), ...
            "highCutoffHz", app.FilterHighField.Value);
        [filteredSignal, info] = SignalSystemDSP.applyFilter(signalValue, state.fs, config);
        setSignal("filtered", filteredSignal, "");
        setStageMeta("filtered", buildStageMeta("滤波器去噪", info.description, signalValue, filteredSignal));
        try
            exportStageMetricsCsv("filtered");
        catch
        end
        addLog("滤波模块执行完成：" + info.description);
        refreshAllViews();
    end

    function advancedEnhanceCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        [enhancedSignal, info] = SignalSystemDSP.applyAdvancedEnhancement( ...
            signalValue, ...
            state.fs, ...
            string(app.AdvancedMethodDropDown.Value), ...
            app.AdvancedStrengthSlider.Value);
        setSignal("enhanced", enhancedSignal, "");
        setStageMeta("enhanced", buildStageMeta("高级增强", info.description, signalValue, enhancedSignal));
        try
            exportStageMetricsCsv("enhanced");
        catch
        end
        addLog("高级增强完成：" + info.description);
        refreshAllViews();
    end

    function voiceModeChangedCallback()
        if ~isfield(app, "VoiceModeDropDown") || isempty(app.VoiceModeDropDown)
            return;
        end

        modeName = string(app.VoiceModeDropDown.Value);
        switch modeName
            case "原声"
                app.VoicePitchSlider.Value = 0;
            case "男声"
                app.VoicePitchSlider.Value = -5;
            case "女声"
                app.VoicePitchSlider.Value = 5;
            case "机器人音"
                app.VoiceRobotFreqSlider.Value = 85;
                app.VoiceRobotDepthSlider.Value = 0.90;
            case "电话音 / 对讲机音"
                app.VoicePitchSlider.Value = 0;
            case "回声音 / 山谷音"
                app.VoiceEchoStrengthSlider.Value = 0.45;
                app.VoiceEchoDelaySlider.Value = 0.22;
            case "怪兽音"
                app.VoicePitchSlider.Value = -7;
                app.VoiceEchoStrengthSlider.Value = 0.28;
                app.VoiceEchoDelaySlider.Value = 0.24;
                app.VoiceEQ60Slider.Value = 4;
                app.VoiceEQ250Slider.Value = 2;
                app.VoiceEQ1kSlider.Value = -2;
                app.VoiceEQ4kSlider.Value = -3;
                app.VoiceEQ8kSlider.Value = -4;
            case "自定义 EQ"
                app.VoiceEQ60Slider.Value = 0;
                app.VoiceEQ250Slider.Value = 0;
                app.VoiceEQ1kSlider.Value = 3;
                app.VoiceEQ4kSlider.Value = 2;
                app.VoiceEQ8kSlider.Value = 1;
        end
    end

    function gainsDb = getVoiceEqGains()
        gainsDb = [ ...
            app.VoiceEQ60Slider.Value, ...
            app.VoiceEQ250Slider.Value, ...
            app.VoiceEQ1kSlider.Value, ...
            app.VoiceEQ4kSlider.Value, ...
            app.VoiceEQ8kSlider.Value];
    end

    function applyVoiceEffectCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        voiceConfig = struct( ...
            "mode", string(app.VoiceModeDropDown.Value), ...
            "pitchSemitone", app.VoicePitchSlider.Value, ...
            "speedFactor", 1.0, ...
            "echoDelaySeconds", app.VoiceEchoDelaySlider.Value, ...
            "echoStrength", app.VoiceEchoStrengthSlider.Value, ...
            "modFrequencyHz", app.VoiceRobotFreqSlider.Value, ...
            "modDepth", app.VoiceRobotDepthSlider.Value, ...
            "eqGainsDb", getVoiceEqGains());
        [effectSignal, info] = SignalSystemDSP.applyVoiceStudioEffect(signalValue, state.fs, voiceConfig);
        setSignal("effect", effectSignal, "");
        setStageMeta("effect", buildStageMeta("变声器", info.description, signalValue, effectSignal));
        if isfield(state.signals, "original")
            app.CompareStageADropDown.Value = resolveValidStage("original", string(app.CompareStageADropDown.ItemsData));
            app.CompareStageBDropDown.Value = resolveValidStage("effect", string(app.CompareStageBDropDown.ItemsData));
        end
        addLog("变声器处理完成：" + info.description);
        refreshAllViews();
        app.VisualTabs.SelectedTab = app.VoiceVisualTab;
    end

    function playOriginalVoiceCallback()
        assertSignalLoaded();
        if ~isfield(state.signals, "original")
            return;
        end
        playAudioSignal(state.signals.original, state.fs, "voice-original");
    end

    function playProcessedVoiceCallback()
        if isempty(state.fs) || ~isfield(state.signals, "effect")
            uialert(app.Figure, "当前还没有变声结果，请先点击“应用变声”。", "没有变声结果");
            return;
        end
        playAudioSignal(state.signals.effect, state.fs, "voice-effect");
    end

    function compareVoiceCallback()
        if isempty(state.fs) || ~isfield(state.signals, "effect")
            uialert(app.Figure, "当前还没有变声结果，请先点击“应用变声”。", "没有变声结果");
            return;
        end
        app.CompareStageADropDown.Value = resolveValidStage("original", string(app.CompareStageADropDown.ItemsData));
        app.CompareStageBDropDown.Value = resolveValidStage("effect", string(app.CompareStageBDropDown.ItemsData));
        app.VisualTabs.SelectedTab = app.CompareTab;
        refreshComparisonView();
    end

    function saveVoiceResultCallback()
        if isempty(state.fs) || ~isfield(state.signals, "effect")
            uialert(app.Figure, "当前还没有变声结果，请先点击“应用变声”。", "没有变声结果");
            return;
        end
        outputDir = fullfile(state.baseDir, "outputs");
        if ~exist(outputDir, "dir")
            mkdir(outputDir);
        end
        modeTag = regexprep(char(string(app.VoiceModeDropDown.Value)), "[^a-zA-Z0-9一-龥]+", "_");
        if isempty(modeTag)
            modeTag = "voice";
        end
        fileName = sprintf("voice_%s_%s.wav", modeTag, char(datetime("now", "Format", "yyyyMMdd_HHmmss")));
        audiowrite(fullfile(outputDir, fileName), state.signals.effect, state.fs);
        addLog("变声音频已保存到 outputs：" + string(fileName));
    end

    function effectCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        effectType = string(app.EffectDropDown.Value);

        switch effectType
            case {"原声", "男声", "女声", "机器人", "电话音", "回声", "怪兽音", "自定义 EQ", "高音", "低音"}
                eqValues = str2double(split(string(app.EQPresetField.Value), ","));
                eqValues = eqValues(~isnan(eqValues));
                if isempty(eqValues)
                    eqValues = [0, 0, 3, 2, 1];
                end
                voiceConfig = struct( ...
                    "mode", effectType, ...
                    "pitchSemitone", app.PitchShiftSlider.Value, ...
                    "speedFactor", app.SpeedSlider.Value, ...
                    "echoDelaySeconds", 0.20, ...
                    "echoStrength", app.EchoStrengthSlider.Value, ...
                    "modFrequencyHz", app.ModFreqSlider.Value, ...
                    "modDepth", min(1, max(0, app.EchoStrengthSlider.Value)), ...
                    "eqGainsDb", eqValues);
                [effectSignal, info] = SignalSystemDSP.applyVoiceProcessor(signalValue, state.fs, voiceConfig);
                setSignal("effect", effectSignal, "");
                setStageMeta("effect", buildStageMeta("变声处理", info.description, signalValue, effectSignal));
                addLog("变声模块执行完成：" + info.description);
            case "语音加密"
                [encryptedSignal, cryptoInfo] = SignalSystemDSP.encryptSignal(signalValue, round(app.FrameLengthField.Value), 2026033);
                state.cryptoInfo = cryptoInfo;
                setSignal("encrypted", encryptedSignal, "");
                setStageMeta("encrypted", buildStageMeta("语音加密", cryptoInfo.description, signalValue, encryptedSignal));
                addLog("语音加密完成：" + cryptoInfo.description);
            case "语音解密"
                if isempty(state.cryptoInfo) || ~isfield(state.signals, "encrypted")
                    uialert(app.Figure, "还没有可恢复的加密语音，请先执行一次语音加密。", "无法解密");
                    return;
                end
                [decryptedSignal, info] = SignalSystemDSP.decryptSignal(state.signals.encrypted, state.cryptoInfo);
                setSignal("decrypted", decryptedSignal, "");
                setStageMeta("decrypted", buildStageMeta("语音解密", info.description, signalValue, decryptedSignal));
                addLog(info.description);
            otherwise
                uialert(app.Figure, "暂不支持该功能。", "功能未实现");
                return;
        end

        refreshAllViews();
    end

    function generateRandomBitsCallback()
        bitCountValue = 1000;
        if isfield(app, "BitCountField") && isvalid(app.BitCountField)
            bitCountValue = max(64, round(app.BitCountField.Value));
        end
        randomBits = randi([0, 1], bitCountValue, 1);
        if isfield(app, "BitSequenceArea") && isvalid(app.BitSequenceArea)
            app.BitSequenceArea.Value = {char(randomBits.' + '0')};
        end
        addLog(sprintf("已生成 %d 位随机比特序列。", bitCountValue));
    end

    function applyChannelNoiseOnlyCallback()
        if ~isfield(state.signals, "modulated") || isempty(state.signals.modulated)
            uialert(app.Figure, "请先完成一次调制。", "缺少调制信号");
            return;
        end
        channelSignal = SignalSystemDSP.normalizeAudio(awgn(state.signals.modulated(:), app.ChannelSnrField.Value, "measured"));
        setSignal("channel", channelSignal, "");
        if ~isfield(state.liveAnalysis, "lastCommChain") || ~isstruct(state.liveAnalysis.lastCommChain)
            state.liveAnalysis.lastCommChain = struct();
        end
        state.liveAnalysis.lastCommChain.channel = channelSignal;
        if isfield(state.liveAnalysis.lastCommChain, "modulated")
            state.liveAnalysis.lastCommChain.modulated = state.signals.modulated(:);
        end
        if ~isfield(state.liveAnalysis, "lastCommInfo") || ~isstruct(state.liveAnalysis.lastCommInfo)
            state.liveAnalysis.lastCommInfo = struct();
        end
        if ~isfield(state.liveAnalysis.lastCommInfo, "config") || ~isstruct(state.liveAnalysis.lastCommInfo.config)
            state.liveAnalysis.lastCommInfo.config = struct();
        end
        state.liveAnalysis.lastCommInfo.config.channelSnrDb = app.ChannelSnrField.Value;
        setStageMeta("channel", buildStageMeta("信道加噪", "单独加入 AWGN 信道噪声", state.signals.modulated, channelSignal));
        addLog(sprintf("通信链已单独加入信道噪声：SNR = %.1f dB。", app.ChannelSnrField.Value));
        refreshAllViews();
        if isfield(app, "VisualTabs") && isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
            app.VisualTabs.SelectedTab = app.ModulationVisualTab;
        end
    end

    function showConstellationCallback()
        if isfield(app, "VisualTabs") && isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
            app.VisualTabs.SelectedTab = app.ModulationVisualTab;
        end
        refreshModulationViews();
    end

    function calculateBerCallback()
        if ~isfield(state.liveAnalysis, "lastCommInfo") || ~isstruct(state.liveAnalysis.lastCommInfo)
            uialert(app.Figure, "请先运行一次通信链。", "缺少通信链结果");
            return;
        end
        info = state.liveAnalysis.lastCommInfo;
        if isfield(info, "sourceBitErrorRate") && ~isempty(info.sourceBitErrorRate) && isfinite(info.sourceBitErrorRate)
            addLog(sprintf("当前通信链源比特 BER = %.5f，编码比特 BER = %.5f。", info.sourceBitErrorRate, info.bitErrorRate));
        elseif isfield(info, "bitErrorRate") && ~isempty(info.bitErrorRate) && isfinite(info.bitErrorRate)
            addLog(sprintf("当前通信链 BER = %.5f。", info.bitErrorRate));
        else
            addLog("当前链路为模拟 AM/FM，默认不计算 BER。");
        end
        refreshModulationViews();
        if isfield(app, "VisualTabs") && isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
            app.VisualTabs.SelectedTab = app.ModulationVisualTab;
        end
    end

    function modulateCallback()
        assertSignalLoaded();
        signalValue = getCurrentSignal();
        modulationType = string(app.ModulationDropDown.Value);
        bitSequenceText = "";
        if isfield(app, "BitSequenceArea") && isvalid(app.BitSequenceArea)
            bitSequenceText = join(string(app.BitSequenceArea.Value), "");
        end

        if any(modulationType == ["ASK", "FSK", "BPSK", "QPSK", "FM调频"])
            commConfig = struct( ...
                "modulationType", modulationType, ...
                "carrierHz", app.CarrierField.Value, ...
                "modulationIndex", app.ModulationIndexField.Value, ...
                "frequencyDeviationHz", max(80, app.ModulationIndexField.Value * 1000), ...
                "channelSnrDb", app.ChannelSnrField.Value, ...
                "symbolRate", app.SymbolRateField.Value, ...
                "bitCount", max(64, round(app.BitCountField.Value)), ...
                "inputBitSequence", bitSequenceText);
            [chain, info] = SignalSystemDSP.runCommunicationChain(signalValue, state.fs, commConfig);
            if isfield(chain, "encoded")
                setSignal("encoded", SignalSystemDSP.normalizeAudio(chain.encoded), "");
            end
            setSignal("modulated", chain.modulated, "");
            setSignal("channel", chain.channel, "");
            if isfield(chain, "demodulated")
                setSignal("demodulated", SignalSystemDSP.normalizeAudio(chain.demodulated), "");
            end
            if isfield(chain, "decoded")
                setSignal("decoded", SignalSystemDSP.normalizeAudio(chain.decoded), "");
            end
            setSignal("restored", chain.restored, "");
            setStageMeta("modulated", buildStageMeta("通信链调制", info.modulationInfo.description, signalValue, chain.modulated));
            setStageMeta("channel", buildStageMeta("信道加噪", "信道噪声叠加完成", chain.modulated, chain.channel));
            setStageMeta("restored", buildStageMeta("通信链恢复", info.demodulationInfo.description, signalValue, chain.restored));
            state.liveAnalysis.lastCommInfo = info;
            state.liveAnalysis.lastCommChain = chain;
            addLog(sprintf("通信链执行完成：%s，BER = %.5f。", modulationType, info.bitErrorRate));
        else
            [modulatedSignal, info] = SignalSystemDSP.modulateSignal( ...
                signalValue, ...
                state.fs, ...
                modulationType, ...
                app.CarrierField.Value, ...
                app.ModulationIndexField.Value);
            channelSignal = SignalSystemDSP.normalizeAudio(awgn(modulatedSignal, app.ChannelSnrField.Value, "measured"));
            setSignal("modulated", modulatedSignal, "");
            setSignal("channel", channelSignal, "");
            setStageMeta("modulated", buildStageMeta("模拟调制", info.description, signalValue, modulatedSignal));
            setStageMeta("channel", buildStageMeta("信道加噪", "模拟信道噪声叠加完成", modulatedSignal, channelSignal));
            addLog("调制模块执行完成：" + info.description);
        end
        refreshAllViews();
        if isfield(app, "VisualTabs") && isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
            app.VisualTabs.SelectedTab = app.ModulationVisualTab;
        end
    end

    function demodulateCallback()
        assertSignalLoaded();
        modulationType = string(app.ModulationDropDown.Value);
        if modulationType == "FM调频"
            signalValue = getSignal(resolveValidStage("channel", string(fieldnames(state.signals))));
            [demodulatedSignal, info] = SignalSystemDSP.demodulateSignal( ...
                signalValue, ...
                state.fs, ...
                modulationType, ...
                app.CarrierField.Value);
            setSignal("demodulated", demodulatedSignal, "");
            setSignal("restored", demodulatedSignal, "");
            setStageMeta("demodulated", buildStageMeta("FM 解调", info.description, getCurrentSignal(), demodulatedSignal));
            addLog("解调模块执行完成：" + info.description);
            refreshAllViews();
            return;
        end

        if any(modulationType == ["ASK", "FSK", "BPSK", "QPSK"])
            if isfield(state.liveAnalysis.lastCommChain, "restored")
                setSignal("restored", state.liveAnalysis.lastCommChain.restored, "");
                addLog(sprintf("%s 数字链已在“运行通信链”中完成解调与恢复。", modulationType));
                refreshAllViews();
            else
                uialert(app.Figure, "请先执行一次“运行通信链”。", "缺少通信链结果");
            end
            return;
        end

        if isfield(state.signals, "channel")
            signalValue = state.signals.channel;
        elseif isfield(state.signals, "modulated")
            signalValue = state.signals.modulated;
        else
            signalValue = getCurrentSignal();
        end

        [demodulatedSignal, info] = SignalSystemDSP.demodulateSignal( ...
            signalValue, ...
            state.fs, ...
            string(app.ModulationDropDown.Value), ...
            app.CarrierField.Value);
        setSignal("demodulated", demodulatedSignal, "");
        setSignal("restored", demodulatedSignal, "");
        setStageMeta("demodulated", buildStageMeta("模拟解调", info.description, getCurrentSignal(), demodulatedSignal));
        addLog("解调模块执行完成：" + info.description);
        refreshAllViews();
        if isfield(app, "VisualTabs") && isfield(app, "ModulationVisualTab") && isvalid(app.ModulationVisualTab)
            app.VisualTabs.SelectedTab = app.ModulationVisualTab;
        end
    end

    function analyzeSignalCallback()
        assertSignalLoaded();
        state.recommendation = SignalSystemDSP.recommendFilterConfig(getCurrentSignal(), state.fs);
        state.recommendation.sourceStage = string(state.currentStage);
        app.RecommendationArea.Value = string(splitlines(state.recommendation.summary));
        addLog("已完成智能分析，并生成推荐参数。");
        refreshAnalysisViews();
    end

    function applyRecommendationCallback()
        if ~isfield(state.recommendation, "filterType") || ~any(string(app.FilterDropDown.Items) == string(state.recommendation.filterType))
            analyzeSignalCallback();
        end
        app.FilterDropDown.Value = state.recommendation.filterType;
        app.FilterCutoffField.Value = state.recommendation.cutoffHz;
        app.FilterOrderField.Value = state.recommendation.order;
        app.FilterHighField.Value = state.recommendation.highCutoffHz;
        app.AdvancedMethodDropDown.Value = state.recommendation.enhancementMethod;
        app.AdvancedStrengthSlider.Value = state.recommendation.enhancementStrength;
        addLog("已将智能推荐参数加载到控制面板。");
        refreshAnalysisViews();
    end

    % Apply the recommended filter directly to the current stage.
    function applyRecommendedFilterCallback()
        assertSignalLoaded();
        if ~isfield(state.recommendation, "filterType") || strlength(string(state.recommendation.filterType)) == 0
            analyzeSignalCallback();
        end
        inputStage = string(state.currentStage);
        applyRecommendationCallback();
        filterCallback();
        state.recommendation.lastAppliedInputStage = inputStage;
        state.recommendation.lastAppliedOutputStage = "filtered";
        addLog("已按智能推荐直接应用滤波器。");
    end

    % Jump to the A/B workspace and compare the input stage with the filtered result.
    function compareRecommendedResultCallback()
        if ~isfield(state.signals, "filtered")
            addLog("当前还没有推荐滤波结果，请先应用推荐滤波器。");
            return;
        end

        stageA = "original";
        if isfield(state.recommendation, "lastAppliedInputStage") && strlength(string(state.recommendation.lastAppliedInputStage)) > 0
            stageA = string(state.recommendation.lastAppliedInputStage);
        elseif isfield(state.recommendation, "sourceStage") && strlength(string(state.recommendation.sourceStage)) > 0
            stageA = string(state.recommendation.sourceStage);
        end

        app.CompareStageADropDown.Value = resolveValidStage(stageA, string(app.CompareStageADropDown.ItemsData));
        app.CompareStageBDropDown.Value = resolveValidStage("filtered", string(app.CompareStageBDropDown.ItemsData));
        refreshComparisonView();
        app.TabGroup.SelectedTab = app.CompareTab;
        addLog("已切换到 A/B 对比页查看滤波前后结果。");
    end

    function runPresetCallback()
        presetName = string(app.PresetDropDown.Value);
        clearRecordingState();
        switch presetName
            case "课堂演示模式"
                [signalValue, fsValue, label] = SignalSystemDSP.loadSample("sample1", state.baseDir);
                state.fs = fsValue;
                state.signals = struct();
                state.stageMeta = struct();
                state.cryptoInfo = [];
                setSignal("original", signalValue, label);

                [noisySignal, noiseInfo] = SignalSystemDSP.addNoise(signalValue, fsValue, "混合噪声", 0.14);
                setSignal("noisy", noisySignal, "");
                [filteredSignal, filterInfo] = SignalSystemDSP.applyFilter(noisySignal, fsValue, "Butterworth低通", 2600, 6);
                setSignal("filtered", filteredSignal, "");
                [enhancedSignal, enhanceInfo] = SignalSystemDSP.applyAdvancedEnhancement(filteredSignal, fsValue, "小波去噪", 0.62);
                setSignal("enhanced", enhancedSignal, "");
                [effectSignal, effectInfo] = SignalSystemDSP.applyVoiceEffect(enhancedSignal, fsValue, "机器人");
                setSignal("effect", effectSignal, "");
                [modulatedSignal, modInfo] = SignalSystemDSP.modulateSignal(effectSignal, fsValue, "AM调幅", 2200, 0.72);
                setSignal("modulated", modulatedSignal, "");
                [demodulatedSignal, demInfo] = SignalSystemDSP.demodulateSignal(modulatedSignal, fsValue, "AM调幅", 2200);
                setSignal("demodulated", demodulatedSignal, "");
                addLog("课堂演示模式完成。");
                addLog("  1) " + noiseInfo.description);
                addLog("  2) " + filterInfo.description);
                addLog("  3) " + enhanceInfo.description);
                addLog("  4) " + effectInfo.description);
                addLog("  5) " + modInfo.description);
                addLog("  6) " + demInfo.description);
            case "语音降噪模式"
                [signalValue, fsValue, label] = SignalSystemDSP.loadSample("sample1", state.baseDir);
                state.fs = fsValue;
                state.signals = struct();
                state.stageMeta = struct();
                state.cryptoInfo = [];
                setSignal("original", signalValue, label + "（实时采集模拟）");
                state.recordingFs = fsValue;
                state.recordingBuffer = signalValue;
                state.recordingElapsedSeconds = numel(signalValue) / fsValue;
                state.recordingPeak = max(abs(signalValue));
                state.recordingStatus = "实时采集模拟完成";
                refreshLiveAnalysis(signalValue);
                state.recommendation = SignalSystemDSP.recommendFilterConfig(signalValue, fsValue);
                [noisySignal, noiseInfo] = SignalSystemDSP.addNoise(signalValue, fsValue, "混合噪声", 0.16);
                setSignal("noisy", noisySignal, "");
                config = struct("type", state.recommendation.filterType, "cutoffHz", state.recommendation.cutoffHz, "order", state.recommendation.order, "highCutoffHz", state.recommendation.highCutoffHz);
                [filteredSignal, filterInfo] = SignalSystemDSP.applyFilter(noisySignal, fsValue, config);
                setSignal("filtered", filteredSignal, "");
                addLog("语音降噪模式完成。");
                addLog("  1) " + noiseInfo.description);
                addLog("  2) " + state.recommendation.reason);
                addLog("  3) " + filterInfo.description);
            case "工频抑制模式"
                [signalValue, fsValue, label] = SignalSystemDSP.loadSample("sample2", state.baseDir);
                state.fs = fsValue;
                state.signals = struct();
                state.stageMeta = struct();
                state.cryptoInfo = [];
                setSignal("original", signalValue, label);

                [noisySignal, noiseInfo] = SignalSystemDSP.addNoise(signalValue, fsValue, "工频干扰", 0.16);
                setSignal("noisy", noisySignal, "");
                [filteredSignal, filterInfo] = SignalSystemDSP.applyFilter(noisySignal, fsValue, "50Hz陷波", 50, 4);
                setSignal("filtered", filteredSignal, "");
                [enhancedSignal, enhanceInfo] = SignalSystemDSP.applyAdvancedEnhancement(filteredSignal, fsValue, "自适应陷波", 0.78);
                setSignal("enhanced", enhancedSignal, "");
                addLog("工频抑制模式完成。");
                addLog("  1) " + noiseInfo.description);
                addLog("  2) " + filterInfo.description);
                addLog("  3) " + enhanceInfo.description);
            case "安全通信模式"
                [signalValue, fsValue, label] = SignalSystemDSP.loadSample("sample1", state.baseDir);
                state.fs = fsValue;
                state.signals = struct();
                state.stageMeta = struct();
                state.cryptoInfo = [];
                setSignal("original", signalValue, label);

                [encryptedSignal, cryptoInfo] = SignalSystemDSP.encryptSignal(signalValue, 1024, 2026033);
                state.cryptoInfo = cryptoInfo;
                setSignal("encrypted", encryptedSignal, "");
                [modulatedSignal, modInfo] = SignalSystemDSP.modulateSignal(encryptedSignal(1:min(end, numel(signalValue))), fsValue, "DSB-SC", 2600, 0.82);
                setSignal("modulated", modulatedSignal, "");
                [demodulatedSignal, demInfo] = SignalSystemDSP.demodulateSignal(modulatedSignal, fsValue, "DSB-SC", 2600);
                setSignal("demodulated", demodulatedSignal, "");
                [decryptedSignal, decryptInfo] = SignalSystemDSP.decryptSignal(encryptedSignal, cryptoInfo);
                setSignal("decrypted", decryptedSignal, "");
                addLog("安全通信模式完成。");
                addLog("  1) " + cryptoInfo.description);
                addLog("  2) " + modInfo.description);
                addLog("  3) " + demInfo.description);
                addLog("  4) " + decryptInfo.description);
            case "调制通信模式"
                [signalValue, fsValue, label] = SignalSystemDSP.loadSample("sample2", state.baseDir);
                state.fs = fsValue;
                state.signals = struct();
                state.stageMeta = struct();
                state.cryptoInfo = [];
                setSignal("original", signalValue, label);
                commConfig = struct("modulationType", "QPSK", "carrierHz", 2200, "modulationIndex", 0.75, "frequencyDeviationHz", 260, "channelSnrDb", 18, "symbolRate", 1000);
                [chain, info] = SignalSystemDSP.runCommunicationChain(signalValue(1:min(end, 8000)), fsValue, commConfig);
                setSignal("encoded", SignalSystemDSP.normalizeAudio(chain.encoded), "");
                setSignal("modulated", chain.modulated, "");
                setSignal("channel", chain.channel, "");
                setSignal("demodulated", SignalSystemDSP.normalizeAudio(chain.demodulated), "");
                setSignal("decoded", SignalSystemDSP.normalizeAudio(chain.decoded), "");
                setSignal("restored", chain.restored, "");
                state.liveAnalysis.lastCommInfo = info;
                state.liveAnalysis.lastCommChain = chain;
                addLog(sprintf("调制通信模式完成，BER = %.5f。", info.bitErrorRate));
        end

        refreshAllViews();
    end

    function exportDashboardCallback()
        [fileName, fileDir] = uiputfile("*.png", "导出当前仪表盘截图", "signal_system_dashboard.png");
        if isequal(fileName, 0)
            return;
        end
        exportapp(app.Figure, fullfile(fileDir, fileName));
        addLog("已导出仪表盘截图：" + string(fileName));
    end

    function exportMaterialsCallback()
        assertSignalLoaded();
        exportContext = struct();
        exportContext.outputRoot = fullfile(state.baseDir, "outputs");
        exportContext.signals = state.signals;
        exportContext.fs = state.fs;
        exportContext.stageLabels = state.stageLabels;
        exportContext.stageMeta = state.stageMeta;
        exportContext.appFigure = app.Figure;
        exportContext.referenceSignal = state.signals.original;
        exportContext.cleanReferenceSignal = state.signals.original;
        if isfield(state.signals, "filtered")
            exportContext.processedSignal = state.signals.filtered;
        else
            exportContext.processedSignal = getCurrentSignal();
        end
        if isfield(state.signals, "effect")
            exportContext.voiceBefore = state.signals.original;
            exportContext.voiceAfter = state.signals.effect;
        end
        if isfield(state.liveAnalysis.lastCommChain, "restored")
            exportContext.commChain = state.liveAnalysis.lastCommChain;
            exportContext.commInfo = state.liveAnalysis.lastCommInfo;
        elseif isfield(state.signals, "modulated") && isfield(state.signals, "restored")
            exportContext.commChain = struct("modulated", state.signals.modulated, "restored", state.signals.restored);
        end
        SignalSystemDSP.exportReportMaterials(exportContext);
        addLog("已导出实验报告素材到 outputs 时间戳目录。");
    end

    function playCurrentCallback()
        assertSignalLoaded();
        playAudioSignal(getSignal(app.StageDropDown.Value), state.fs, "current");
        addLog("正在播放：" + state.stageLabels.(char(app.StageDropDown.Value)));
    end

    function saveCurrentCallback()
        assertSignalLoaded();
        stageKey = string(app.StageDropDown.Value);
        defaultFileName = char(stageKey + ".wav");
        [fileName, fileDir] = uiputfile("*.wav", "导出当前阶段 WAV", defaultFileName);
        if isequal(fileName, 0)
            return;
        end
        audiowrite(fullfile(fileDir, fileName), getSignal(stageKey), state.fs);
        addLog("已导出 WAV：" + string(fileName));
    end

    function swapCompareStagesCallback()
        stageA = app.CompareStageADropDown.Value;
        stageB = app.CompareStageBDropDown.Value;
        app.CompareStageADropDown.Value = stageB;
        app.CompareStageBDropDown.Value = stageA;
        refreshComparisonView();
    end

    function playCompareStageCallback(modeName)
        compareContext = buildCompareContext();
        if ~isempty(compareContext)
            switch lower(char(modeName))
                case "a"
                    playAudioSignal(getSignal(compareContext.stageA), getStageSampleRate(compareContext.stageA), "A");
                case "b"
                    playAudioSignal(getSignal(compareContext.stageB), getStageSampleRate(compareContext.stageB), "B");
                case "diff"
                    playAudioSignal(SignalSystemDSP.normalizeAudio(compareContext.info.pairInfo.differenceSignal), ...
                        compareContext.info.pairInfo.compareFs, "diff");
                otherwise
                    switchSignal = buildSwitchSignal(compareContext.info.pairInfo.signalA, ...
                        compareContext.info.pairInfo.signalB, compareContext.info.pairInfo.compareFs);
                    playAudioSignal(switchSignal, compareContext.info.pairInfo.compareFs, "switch");
            end
            return;
        end
        if isempty(state.fs) || ~isfield(state.signals, char(app.CompareStageADropDown.Value)) || ~isfield(state.signals, char(app.CompareStageBDropDown.Value))
            return;
        end

        signalA = getSignal(string(app.CompareStageADropDown.Value));
        signalB = getSignal(string(app.CompareStageBDropDown.Value));
        compareLength = min(numel(signalA), numel(signalB));
        signalA = signalA(1:compareLength);
        signalB = signalB(1:compareLength);

        switch lower(char(modeName))
            case "a"
                playAudioSignal(signalA, state.fs, "A");
            case "b"
                playAudioSignal(signalB, state.fs, "B");
            case "diff"
                playAudioSignal(SignalSystemDSP.normalizeAudio(signalA - signalB), state.fs, "diff");
            otherwise
                switchSignal = buildSwitchSignal(signalA, signalB, state.fs);
                playAudioSignal(switchSignal, state.fs, "switch");
        end
    end

    function playAudioSignal(signalValue, fsValue, modeName)
        stopPlaybackCallback();
        player = audioplayer(signalValue, fsValue);
        state.playback.player = player;
        state.playback.currentMode = string(modeName);
        play(player);
    end

    function stopPlaybackCallback()
        if isfield(state.playback, "player") && ~isempty(state.playback.player)
            try
                stop(state.playback.player);
            catch
            end
        end
        state.playback.player = [];
        state.playback.currentMode = "idle";
    end

    function signalOut = buildSwitchSignal(signalA, signalB, fsValue)
        blockSamples = max(256, round(0.6 * fsValue));
        fadeSamples = max(32, round(0.02 * fsValue));
        totalLength = min(numel(signalA), numel(signalB));
        signalOut = zeros(totalLength, 1);
        idx = 1;
        useA = true;
        while idx <= totalLength
            endIdx = min(totalLength, idx + blockSamples - 1);
            if useA
                signalOut(idx:endIdx) = signalA(idx:endIdx);
            else
                signalOut(idx:endIdx) = signalB(idx:endIdx);
            end
            if endIdx < totalLength
                fadeEnd = min(totalLength, endIdx + fadeSamples);
                alpha = linspace(1, 0, fadeEnd - endIdx + 1).';
                if useA
                    signalOut(endIdx:fadeEnd) = alpha .* signalA(endIdx:fadeEnd) + (1 - alpha) .* signalB(endIdx:fadeEnd);
                else
                    signalOut(endIdx:fadeEnd) = alpha .* signalB(endIdx:fadeEnd) + (1 - alpha) .* signalA(endIdx:fadeEnd);
                end
            end
            useA = ~useA;
            idx = endIdx + 1;
        end
        signalOut = SignalSystemDSP.normalizeAudio(signalOut);
    end

    function runDemoCallback()
        app.PresetDropDown.Value = "课堂演示模式";
        runPresetCallback();
    end
end
