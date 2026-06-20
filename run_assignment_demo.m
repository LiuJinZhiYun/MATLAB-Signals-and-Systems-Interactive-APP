function results = run_assignment_demo()
    baseDir = string(fileparts(mfilename("fullpath")));
    outputDir = fullfile(baseDir, "outputs");

    if ~exist(outputDir, "dir")
        mkdir(outputDir);
    end

    [originalSignal, fs, sourceLabel] = SignalSystemDSP.loadSample("sample1", baseDir);
    [humSignal, humNoiseInfo] = SignalSystemDSP.addNoise(originalSignal, fs, "工频干扰", 0.18);
    humRecommendation = SignalSystemDSP.recommendFilterConfig(humSignal, fs);
    humFilterConfig = struct( ...
        "type", humRecommendation.filterType, ...
        "cutoffHz", humRecommendation.cutoffHz, ...
        "order", humRecommendation.order, ...
        "highCutoffHz", humRecommendation.highCutoffHz);
    [humFilteredSignal, humFilterInfo] = SignalSystemDSP.applyFilter(humSignal, fs, humFilterConfig);
    [noisySignal, noiseInfo] = SignalSystemDSP.addNoise(originalSignal, fs, "混合噪声", 0.18);
    [filteredSignal, filterInfo] = SignalSystemDSP.applyFilter(noisySignal, fs, "Butterworth低通", 1800, 6);
    [robotSignal, effectInfo] = SignalSystemDSP.applyVoiceEffect(filteredSignal, fs, "机器人音");
    [encryptedSignal, cryptoInfo] = SignalSystemDSP.encryptSignal(filteredSignal, 1024, 2026033);
    [decryptedSignal, decryptInfo] = SignalSystemDSP.decryptSignal(encryptedSignal, cryptoInfo);
    [modulatedSignal, modInfo] = SignalSystemDSP.modulateSignal(robotSignal, fs, "AM调幅", 2200, 0.75);
    [demodulatedSignal, demInfo] = SignalSystemDSP.demodulateSignal(modulatedSignal, fs, "AM调幅", 2200);
    bpskBits = randi([0, 1], 128, 1) > 0;
    qpskBits = randi([0, 1], 128, 1) > 0;
    [bpskChain, bpskInfo] = SignalSystemDSP.runCommunicationChain(filteredSignal, fs, struct( ...
        "modulationType", "BPSK", ...
        "carrierHz", 2200, ...
        "modulationIndex", 0.75, ...
        "frequencyDeviationHz", 260, ...
        "channelSnrDb", 12, ...
        "symbolRate", 1200, ...
        "bitCount", numel(bpskBits), ...
        "inputBitSequence", bpskBits));
    [qpskChain, qpskInfo] = SignalSystemDSP.runCommunicationChain(filteredSignal, fs, struct( ...
        "modulationType", "QPSK", ...
        "carrierHz", 2400, ...
        "modulationIndex", 0.75, ...
        "frequencyDeviationHz", 260, ...
        "channelSnrDb", 10, ...
        "symbolRate", 1200, ...
        "bitCount", numel(qpskBits), ...
        "inputBitSequence", qpskBits));

    [femaleSignal, femaleInfo] = SignalSystemDSP.applyVoiceStudioEffect(filteredSignal, fs, struct( ...
        "mode", "女声", ...
        "pitchSemitone", 5, ...
        "echoDelaySeconds", 0.18, ...
        "echoStrength", 0.20, ...
        "modFrequencyHz", 80, ...
        "modDepth", 0.60, ...
        "eqGainsDb", [0, 0, 2, 2, 1]));
    [phoneSignal, phoneInfo] = SignalSystemDSP.applyVoiceStudioEffect(filteredSignal, fs, struct( ...
        "mode", "电话音 / 对讲机音", ...
        "pitchSemitone", 0, ...
        "echoDelaySeconds", 0.18, ...
        "echoStrength", 0.10, ...
        "modFrequencyHz", 60, ...
        "modDepth", 0.40, ...
        "eqGainsDb", [0, 0, 0, 0, 0]));
    [monsterSignal, monsterInfo] = SignalSystemDSP.applyVoiceStudioEffect(filteredSignal, fs, struct( ...
        "mode", "怪兽音", ...
        "pitchSemitone", -7, ...
        "echoDelaySeconds", 0.24, ...
        "echoStrength", 0.30, ...
        "modFrequencyHz", 40, ...
        "modDepth", 0.50, ...
        "eqGainsDb", [4, 2, -2, -3, -4]));

    filterMetrics = SignalSystemDSP.evaluateProcessing(noisySignal, filteredSignal, fs, originalSignal);
    voiceMetrics = SignalSystemDSP.evaluateProcessing(filteredSignal, femaleSignal, fs);
    humMetrics = SignalSystemDSP.evaluateProcessing(humSignal, humFilteredSignal, fs, originalSignal);
    compareDemoInfo = SignalSystemDSP.compareStagePair(originalSignal, filteredSignal, fs, fs);

    SignalSystemDSP.exportFrameworkDiagram(fullfile(outputDir, "framework_diagram.png"));
    exportWaveformFigure(outputDir, fs, originalSignal, noisySignal, filteredSignal, robotSignal, modulatedSignal, demodulatedSignal);
    exportSpectrumFigure(outputDir, fs, originalSignal, noisySignal, filteredSignal, robotSignal, modulatedSignal, demodulatedSignal);
    exportSmartFilterRecommendationFigure(outputDir, fs, humSignal, humFilteredSignal, humRecommendation);
    exportEncryptionFigure(outputDir, fs, filteredSignal, encryptedSignal, decryptedSignal);
    exportVoiceShowcaseFigure(outputDir, fs, filteredSignal, femaleSignal, phoneSignal, monsterSignal);
    exportCommunicationShowcaseFigure(outputDir, fs, bpskChain, bpskInfo, qpskChain, qpskInfo);
    exportMetricsOverviewFigure(outputDir, filterMetrics, voiceMetrics);
    compareExportInfo = SignalSystemDSP.exportComparisonBundle(string(outputDir), "Original", "Filtered", compareDemoInfo);
    liveDemoInfo = exportRealtimeAnalysisDemo(outputDir, fs, originalSignal);
    exportInterfaceFigure(outputDir);
    SignalSystemDSP.exportMetricsCsv(outputDir, "filtered_result_metrics.csv", filterMetrics, "filtered", "filter");
    SignalSystemDSP.exportMetricsCsv(outputDir, "hum_denoise_metrics.csv", humMetrics, "hum_filtered", "smart_filter");
    SignalSystemDSP.exportMetricsCsv(outputDir, "voice_change_metrics.csv", voiceMetrics, "effect", "voice");
    exportCommunicationBerTable(outputDir, bpskInfo, qpskInfo);

    audiowrite(fullfile(outputDir, "demo_filtered.wav"), filteredSignal, fs);
    audiowrite(fullfile(outputDir, "demo_robot.wav"), robotSignal, fs);
    audiowrite(fullfile(outputDir, "demo_female.wav"), femaleSignal, fs);
    audiowrite(fullfile(outputDir, "demo_phone.wav"), phoneSignal, fs);
    audiowrite(fullfile(outputDir, "demo_monster.wav"), monsterSignal, fs);
    audiowrite(fullfile(outputDir, "demo_demodulated.wav"), demodulatedSignal, fs);
    audiowrite(fullfile(outputDir, "demo_bpsk_restored.wav"), bpskChain.restored, fs);
    audiowrite(fullfile(outputDir, "demo_qpsk_restored.wav"), qpskChain.restored, fs);

    noiseSnr = SignalSystemDSP.estimateSNR(originalSignal, noisySignal);
    filterSnr = SignalSystemDSP.estimateSNR(originalSignal, filteredSignal);
    decryptSnr = SignalSystemDSP.estimateSNR(filteredSignal, decryptedSignal);
    demodSnr = SignalSystemDSP.estimateSNR(robotSignal, demodulatedSignal);

    results = struct();
    results.sourceLabel = sourceLabel;
    results.sampleRate = fs;
    results.noiseInfo = noiseInfo;
    results.humNoiseInfo = humNoiseInfo;
    results.humRecommendation = humRecommendation;
    results.humFilterInfo = humFilterInfo;
    results.humMetrics = humMetrics;
    results.filterInfo = filterInfo;
    results.filterMetrics = filterMetrics;
    results.effectInfo = effectInfo;
    results.femaleInfo = femaleInfo;
    results.voiceMetrics = voiceMetrics;
    results.compareDemoInfo = compareDemoInfo;
    results.compareExportInfo = compareExportInfo;
    results.phoneInfo = phoneInfo;
    results.monsterInfo = monsterInfo;
    results.liveDemoInfo = liveDemoInfo;
    results.cryptoInfo = cryptoInfo;
    results.decryptInfo = decryptInfo;
    results.modInfo = modInfo;
    results.demInfo = demInfo;
    results.bpskInfo = bpskInfo;
    results.qpskInfo = qpskInfo;
    results.noiseSnrDb = noiseSnr;
    results.filterSnrDb = filterSnr;
    results.decryptSnrDb = decryptSnr;
    results.demodSnrDb = demodSnr;

    save(fullfile(outputDir, "demo_results.mat"), "results");
    writeSummary(outputDir, results);

    fprintf("DEMO_DONE: %s\n", outputDir);
end

function exportWaveformFigure(outputDir, fs, originalSignal, noisySignal, filteredSignal, robotSignal, modulatedSignal, demodulatedSignal)
    fig = figure("Visible", "off", "Color", "w", "Position", [80, 60, 1250, 1120]);
    layout = tiledlayout(fig, 3, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "APP 涓昏澶勭悊闃舵娉㈠舰缁撴灉", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, originalSignal, fs, "鍘熷璇煶娉㈠舰");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, noisySignal, fs, "加噪后波形", [0.80, 0.32, 0.16]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, filteredSignal, fs, "婊ゆ尝鍘诲櫔缁撴灉", [0.10, 0.55, 0.28]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, robotSignal, fs, "鏈哄櫒浜洪煶鍙樺０缁撴灉", [0.55, 0.18, 0.62]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, modulatedSignal, fs, "AM 璋冨埗缁撴灉", [0.76, 0.18, 0.25]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, demodulatedSignal, fs, "AM 瑙ｈ皟鎭㈠缁撴灉", [0.14, 0.40, 0.72]);

    exportgraphics(fig, fullfile(outputDir, "pipeline_waveforms.png"), "Resolution", 220);
    close(fig);
end

function exportSpectrumFigure(outputDir, fs, originalSignal, noisySignal, filteredSignal, robotSignal, modulatedSignal, demodulatedSignal)
    fig = figure("Visible", "off", "Color", "w", "Position", [90, 70, 1250, 1120]);
    layout = tiledlayout(fig, 3, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "APP 涓昏澶勭悊闃舵棰戣氨缁撴灉", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, originalSignal, fs, "鍘熷璇煶棰戣氨");

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, noisySignal, fs, "加噪后频谱", [0.80, 0.32, 0.16]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, filteredSignal, fs, "婊ゆ尝鍘诲櫔棰戣氨", [0.10, 0.55, 0.28]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, robotSignal, fs, "鏈哄櫒浜洪煶棰戣氨", [0.55, 0.18, 0.62]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, modulatedSignal, fs, "AM 璋冨埗棰戣氨", [0.76, 0.18, 0.25]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, demodulatedSignal, fs, "AM 瑙ｈ皟棰戣氨", [0.14, 0.40, 0.72]);

    exportgraphics(fig, fullfile(outputDir, "pipeline_spectra.png"), "Resolution", 220);
    close(fig);
end

% Export a fixed smart-filter recommendation demo for 50 Hz hum suppression.
function exportSmartFilterRecommendationFigure(outputDir, fs, humSignal, humFilteredSignal, recommendation)
    fig = figure("Visible", "off", "Color", "w", "Position", [100, 80, 1280, 860]);
    layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "智能滤波推荐演示：工频干扰识别与陷波去除", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, humSignal, fs, "工频干扰频谱", [0.78, 0.28, 0.22]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, humFilteredSignal, fs, "推荐滤波后频谱", [0.16, 0.52, 0.33]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, humSignal, fs, "工频干扰波形", [0.78, 0.28, 0.22]);

    ax = nexttile(layout);
    axis(ax, "off");
    text(ax, 0.02, 0.86, "智能推荐结果", "FontSize", 16, "FontWeight", "bold");
    text(ax, 0.02, 0.68, "检测噪声：" + string(recommendation.noiseSignature), "FontSize", 13);
    text(ax, 0.02, 0.52, sprintf("推荐滤波器：%s", recommendation.filterType), "FontSize", 13);
    text(ax, 0.02, 0.36, sprintf("关键频率：%.1f Hz | 阶数：%d", recommendation.cutoffHz, recommendation.order), "FontSize", 13);
    text(ax, 0.02, 0.16, string(recommendation.reason), "FontSize", 12, "Interpreter", "none");

    exportgraphics(fig, fullfile(outputDir, "smart_filter_recommendation_demo.png"), "Resolution", 220);
    close(fig);
end

function exportEncryptionFigure(outputDir, fs, filteredSignal, encryptedSignal, decryptedSignal)
    fig = figure("Visible", "off", "Color", "w", "Position", [120, 80, 1250, 820]);
    layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "闄勫姞鍔熻兘锛氳闊冲姞瀵嗕笌鎭㈠", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, filteredSignal, fs, "滤波后参考语音");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, encryptedSignal, fs, "加密结果", [0.76, 0.18, 0.25]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, decryptedSignal, fs, "瑙ｅ瘑鎭㈠缁撴灉", [0.10, 0.55, 0.28]);

    ax = nexttile(layout);
    t = (0:numel(filteredSignal) - 1) / fs;
    plot(ax, t, filteredSignal, "LineWidth", 1.0, "Color", [0.18, 0.18, 0.18]);
    hold(ax, "on");
    plot(ax, t, decryptedSignal, "LineWidth", 1.0, "Color", [0.86, 0.20, 0.18]);
    hold(ax, "off");
    grid(ax, "on");
    xlabel(ax, "鏃堕棿 / s");
    ylabel(ax, "幅值");
    title(ax, "滤波语音与解密语音对比");
    legend(ax, ["婊ゆ尝璇煶", "瑙ｅ瘑璇煶"], "Location", "best");

    exportgraphics(fig, fullfile(outputDir, "encryption_recovery.png"), "Resolution", 220);
    close(fig);
end

function exportVoiceShowcaseFigure(outputDir, fs, filteredSignal, femaleSignal, phoneSignal, monsterSignal)
    fig = figure("Visible", "off", "Color", "w", "Position", [120, 80, 1320, 900]);
    layout = tiledlayout(fig, 3, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "变声器模块自动演示", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, filteredSignal, fs, "参考语音波形");

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, filteredSignal, fs, "参考语音频谱");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, femaleSignal, fs, "濂冲０妯″紡娉㈠舰", [0.80, 0.28, 0.50]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, femaleSignal, fs, "濂冲０妯″紡棰戣氨", [0.80, 0.28, 0.50]);

    ax = nexttile(layout);
    hold(ax, "on");
    SignalSystemDSP.drawSpectrum(ax, phoneSignal, fs, "鐢佃瘽闊?/ 鎬吔闊?棰戣氨瀵规瘮", [0.18, 0.58, 0.70]);
    [fMonster, magMonster] = SignalSystemDSP.magnitudeSpectrum(monsterSignal, fs);
    plot(ax, fMonster, magMonster, "LineWidth", 1.1, "Color", [0.72, 0.24, 0.20]);
    legend(ax, ["电话音 / 对讲机音", "怪兽音"], "Location", "best");
    hold(ax, "off");

    ax = nexttile(layout);
    t = (0:min(numel(filteredSignal), numel(monsterSignal)) - 1) / fs;
    plot(ax, t, filteredSignal(1:numel(t)), "LineWidth", 0.9, "Color", [0.25, 0.25, 0.25]);
    hold(ax, "on");
    plot(ax, t, monsterSignal(1:numel(t)), "LineWidth", 0.9, "Color", [0.72, 0.24, 0.20]);
    hold(ax, "off");
    grid(ax, "on");
    xlabel(ax, "鏃堕棿 / s");
    ylabel(ax, "幅值");
    title(ax, "怪兽音与参考语音波形对比");
    legend(ax, ["参考语音", "怪兽音"], "Location", "best");

    exportgraphics(fig, fullfile(outputDir, "voice_effects_showcase.png"), "Resolution", 220);
    close(fig);
end

function liveDemoInfo = exportRealtimeAnalysisDemo(outputDir, fs, referenceSignal)
    demoDuration = min(4.5, max(3.0, numel(referenceSignal) / fs));
    t = (0:round(demoDuration * fs) - 1).' / fs;
    chirpSignal = 0.45 * chirp(t, 180, t(end), min(2600, fs / 2 - 300), "linear");
    speechLike = referenceSignal(1:min(numel(referenceSignal), numel(t)));
    if numel(speechLike) < numel(t)
        speechLike(end + 1:numel(t), 1) = 0;
    end
    envelope = 0.45 + 0.55 * max(0, sin(2 * pi * 0.9 * t));
    simulatedSignal = SignalSystemDSP.normalizeAudio(0.55 * speechLike + envelope .* chirpSignal);

    frameLength = max(256, 2 ^ nextpow2(round(0.032 * fs)));
    hopLength = max(64, round(frameLength / 2));
    frameCount = max(1, floor((numel(simulatedSignal) - frameLength) / hopLength) + 1);
    trend = zeros(frameCount, 5);
    latestFrameInfo = struct();
    for idx = 1:frameCount
        startIdx = (idx - 1) * hopLength + 1;
        endIdx = min(numel(simulatedSignal), startIdx + frameLength - 1);
        frame = simulatedSignal(startIdx:endIdx);
        if numel(frame) < frameLength
            frame(end + 1:frameLength, 1) = 0;
        end
        [latestFrameInfo, trend(idx, :)] = SignalSystemDSP.analyzeLiveFrame(frame, fs, [0, 300, 1200, 3400, min(8000, fs / 2)]);
    end
    liveView = SignalSystemDSP.buildLiveSpectrogram(simulatedSignal, fs, ...
        struct("frameLength", frameLength, "overlapLength", round(0.5 * frameLength), "nfft", max(512, 2 * frameLength)));

    audiowrite(fullfile(outputDir, "demo_live_input.wav"), simulatedSignal, fs);

    waveformFig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1100, 320]);
    ax = axes(waveformFig);
    SignalSystemDSP.drawWaveform(ax, simulatedSignal, fs, "Simulated Realtime Input");
    exportgraphics(waveformFig, fullfile(outputDir, "demo_live_waveform.png"), "Resolution", 220);
    close(waveformFig);

    spectrumFig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1100, 320]);
    ax = axes(spectrumFig);
    SignalSystemDSP.drawSpectrum(ax, simulatedSignal, fs, "Simulated Realtime FFT");
    exportgraphics(spectrumFig, fullfile(outputDir, "demo_live_spectrum.png"), "Resolution", 220);
    close(spectrumFig);

    spectrogramFig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1100, 420]);
    ax = axes(spectrogramFig);
    imagesc(ax, liveView.timeAxis, liveView.frequencyAxis, liveView.powerDb);
    axis(ax, "xy");
    ylim(ax, [0, min(fs / 2, 4000)]);
    xlabel(ax, "Time / s");
    ylabel(ax, "Frequency / Hz");
    title(ax, "Simulated Realtime Spectrogram");
    colormap(ax, turbo);
    colorbar(ax);
    exportgraphics(spectrogramFig, fullfile(outputDir, "demo_live_spectrogram.png"), "Resolution", 220);
    close(spectrogramFig);

    overviewFig = figure("Visible", "off", "Color", "w", "Position", [90, 90, 1280, 840]);
    layout = tiledlayout(overviewFig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, simulatedSignal, fs, "Simulated Realtime Waveform");
    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, simulatedSignal, fs, "Simulated Realtime FFT");
    ax = nexttile(layout);
    imagesc(ax, liveView.timeAxis, liveView.frequencyAxis, liveView.powerDb);
    axis(ax, "xy");
    ylim(ax, [0, min(fs / 2, 4000)]);
    xlabel(ax, "Time / s");
    ylabel(ax, "Frequency / Hz");
    title(ax, "Simulated Realtime Waterfall");
    colormap(ax, turbo);
    ax = nexttile(layout);
    plot(ax, trend(:, 1), "LineWidth", 1.1, "Color", [0.16, 0.47, 0.74]);
    hold(ax, "on");
    yyaxis(ax, "right");
    plot(ax, trend(:, 2), "LineWidth", 1.1, "Color", [0.82, 0.26, 0.22]);
    grid(ax, "on");
    title(ax, "Frame Energy and Dominant Frequency");
    exportgraphics(overviewFig, fullfile(outputDir, "demo_live_overview.png"), "Resolution", 220);
    close(overviewFig);

    liveDemoInfo = struct();
    liveDemoInfo.frameCount = frameCount;
    liveDemoInfo.durationSeconds = numel(simulatedSignal) / fs;
    liveDemoInfo.shortTimeEnergy = latestFrameInfo.shortTimeEnergy;
    liveDemoInfo.dominantFrequencyHz = latestFrameInfo.dominantFrequencyHz;
    liveDemoInfo.bandEnergy = latestFrameInfo.bandEnergy;
end

function exportCommunicationShowcaseFigure(outputDir, fs, bpskChain, bpskInfo, qpskChain, qpskInfo)
    fig = figure("Visible", "off", "Color", "w", "Position", [100, 80, 1380, 920]);
    layout = tiledlayout(fig, 3, 2, "Padding", "compact", "TileSpacing", "compact");
    title(layout, "BPSK / QPSK 通信链自动演示", "FontWeight", "bold");

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, bpskChain.modulated, fs, "BPSK 调制波形", [0.78, 0.22, 0.24]);

    ax = nexttile(layout);
    SignalSystemDSP.drawWaveform(ax, qpskChain.modulated, fs, "QPSK 调制波形", [0.12, 0.45, 0.72]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, bpskChain.channel, fs, sprintf("BPSK 信道频谱 | BER %.4f", bpskInfo.bitErrorRate), [0.78, 0.22, 0.24]);

    ax = nexttile(layout);
    SignalSystemDSP.drawSpectrum(ax, qpskChain.channel, fs, sprintf("QPSK 信道频谱 | BER %.4f", qpskInfo.bitErrorRate), [0.12, 0.45, 0.72]);

    ax = nexttile(layout);
    SignalSystemDSP.drawConstellation(ax, bpskInfo.constellation, "BPSK 星座图");

    ax = nexttile(layout);
    SignalSystemDSP.drawConstellation(ax, qpskInfo.constellation, "QPSK 星座图");

    exportgraphics(fig, fullfile(outputDir, "communication_bpsk_qpsk_showcase.png"), "Resolution", 220);
    close(fig);
end

function exportCommunicationBerTable(outputDir, bpskInfo, qpskInfo)
    data = { ...
        'BPSK', bpskInfo.channelSnrDb, bpskInfo.symbolRate, numel(bpskInfo.sourceBits), bpskInfo.bitErrorRate; ...
        'QPSK', qpskInfo.channelSnrDb, qpskInfo.symbolRate, numel(qpskInfo.sourceBits), qpskInfo.bitErrorRate};
    cell2csv = cell2table(data, "VariableNames", {'Modulation','SNR_dB','SymbolRate','BitCount','BER'});
    writetable(cell2csv, fullfile(outputDir, "communication_ber_summary.csv"));
end

function exportMetricsOverviewFigure(outputDir, filterMetrics, voiceMetrics)
    fig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1280, 720]);
    annotation(fig, "textbox", [0.04, 0.88, 0.92, 0.08], ...
        "String", "閲忓寲璇勪环妯″潡鑷姩婕旂ず", ...
        "LineStyle", "none", ...
        "FontWeight", "bold", ...
        "FontSize", 20, ...
        "FontName", "Microsoft YaHei");

    summaryData = { ...
        "婊ゆ尝鍘诲櫔", formatMetricCell(filterMetrics.snrBeforeDb), formatMetricCell(filterMetrics.snrAfterDb), formatMetricCell(filterMetrics.snrImprovementDb), formatMetricCell(filterMetrics.rmse), char(string(filterMetrics.evaluationText)); ...
        "鍙樺０澶勭悊", formatMetricCell(voiceMetrics.snrBeforeDb), formatMetricCell(voiceMetrics.snrAfterDb), formatMetricCell(voiceMetrics.snrImprovementDb), formatMetricCell(voiceMetrics.rmse), char(string(voiceMetrics.evaluationText))};
    summaryData = cellfun(@convertTableCell, summaryData, "UniformOutput", false);
    uitable(fig, ...
        "Data", summaryData, ...
        "ColumnName", {"妯″潡", "SNR鍓?dB)", "SNR鍚?dB)", "鎻愬崌(dB)", "RMSE", "璇勪环"}, ...
        "Position", [40, 280, 1200, 360], ...
        "ColumnWidth", {120, 110, 110, 110, 90, 620});

        noteLines = { ...
        "滤波去噪与变声处理的量化评价总览。", ...
        sprintf("滤波前后频带占比变化：低频 %.1f%%，语音 %.1f%%，高频 %.1f%%。", ...
            100 * filterMetrics.bandEnergyRatioDelta.low, ...
            100 * filterMetrics.bandEnergyRatioDelta.speech, ...
            100 * filterMetrics.bandEnergyRatioDelta.high), ...
        sprintf("频谱峰值变化：滤波 %.2f dB，变声 %.2f dB。", ...
            filterMetrics.spectrumPeakDeltaDb, voiceMetrics.spectrumPeakDeltaDb)};
    noteLines = cellfun(@convertTableCell, noteLines, "UniformOutput", false);
    noteText = strjoin(noteLines, newline);
    annotation(fig, "textbox", [0.05, 0.08, 0.90, 0.14], ...
        "String", noteText, ...
        "FontSize", 12, ...
        "BackgroundColor", [0.98, 0.98, 0.98], ...
        "FontName", "Consolas");

    exportgraphics(fig, fullfile(outputDir, "metrics_overview.png"), "Resolution", 220);
    close(fig);
end

function exportInterfaceFigure(outputDir)
    app = launch_signal_system_app("Visible", false);
    drawnow;
    exportapp(app.Figure, fullfile(outputDir, "app_interface.png"));
    exportapp(app.Figure, fullfile(outputDir, "app_interface_v2.png"));
    delete(app.Figure);
end

function writeSummary(outputDir, results)
    summaryPath = fullfile(outputDir, "demo_summary.txt");
    fileId = fopen(summaryPath, "w");

    fprintf(fileId, "淇″彿涓庣郴缁熻绋嬪ぇ浣滀笟 APP 鑷姩婕旂ず缁撴灉\n\n");
    fprintf(fileId, "鏁版嵁婧愶細%s\n", results.sourceLabel);
    fprintf(fileId, "閲囨牱鐜囷細%.0f Hz\n\n", results.sampleRate);

    fprintf(fileId, "澶勭悊閾捐矾锛歕n");
    fprintf(fileId, "1. %s锛屼及璁?SNR = %.2f dB\n", results.noiseInfo.description, results.noiseSnrDb);
    fprintf(fileId, "2. %s锛屾护娉㈠悗鐩稿鍘熷淇″彿 SNR = %.2f dB\n", results.filterInfo.description, results.filterSnrDb);
    fprintf(fileId, "3. %s\n", results.effectInfo.description);
    fprintf(fileId, "4. %s\n", results.modInfo.description);
    fprintf(fileId, "5. %s锛岃В璋冨悗鐩稿鍙樺０闊抽 SNR = %.2f dB\n\n", results.demInfo.description, results.demodSnrDb);
    fprintf(fileId, "6. BPSK 通信链：BER = %.6f | SNR = %.2f dB\n", results.bpskInfo.bitErrorRate, results.bpskInfo.channelSnrDb);
    fprintf(fileId, "7. QPSK 通信链：BER = %.6f | SNR = %.2f dB\n\n", results.qpskInfo.bitErrorRate, results.qpskInfo.channelSnrDb);

    fprintf(fileId, "鍒涙柊闄勫姞鍔熻兘锛歕n");
    fprintf(fileId, "- %s\n", results.cryptoInfo.description);
    fprintf(fileId, "- %s锛岀浉瀵规护娉㈠悗璇煶 SNR = %.2f dB\n\n", results.decryptInfo.description, results.decryptSnrDb);

    fprintf(fileId, "杈撳嚭鏂囦欢锛歕n");
    fprintf(fileId, "- framework_diagram.png\n");
    fprintf(fileId, "- pipeline_waveforms.png\n");
    fprintf(fileId, "- pipeline_spectra.png\n");
    fprintf(fileId, "- smart_filter_recommendation_demo.png\n");
    fprintf(fileId, "- encryption_recovery.png\n");
    fprintf(fileId, "- communication_bpsk_qpsk_showcase.png\n");
    fprintf(fileId, "- metrics_overview.png\n");
    fprintf(fileId, "- filtered_result_metrics.csv\n");
    fprintf(fileId, "- hum_denoise_metrics.csv\n");
    fprintf(fileId, "- voice_change_metrics.csv\n");
    fprintf(fileId, "- communication_ber_summary.csv\n");
    fprintf(fileId, "- ab_compare_*_overview.png\n");
    fprintf(fileId, "- ab_compare_*_diff_spectrum.png\n");
    fprintf(fileId, "- ab_compare_*_metrics.csv\n");
    fprintf(fileId, "- ab_compare_*_difference.wav\n");
    fprintf(fileId, "- app_interface.png\n");
    fprintf(fileId, "- app_interface_v2.png\n");
    fprintf(fileId, "- demo_filtered.wav\n");
    fprintf(fileId, "- demo_robot.wav\n");
    fprintf(fileId, "- demo_demodulated.wav\n");
    fprintf(fileId, "- demo_bpsk_restored.wav\n");
    fprintf(fileId, "- demo_qpsk_restored.wav\n");
    fclose(fileId);
end

function valueText = formatMetricCell(value)
    if isnan(value)
        valueText = '--';
    elseif isinf(value)
        valueText = 'Inf';
    elseif abs(value) >= 100
        valueText = sprintf("%.0f", value);
    else
        valueText = sprintf("%.2f", value);
    end
end

function valueOut = convertTableCell(valueIn)
    if isstring(valueIn)
        valueOut = char(valueIn);
    else
        valueOut = valueIn;
    end
end

