classdef SignalSystemDSP
    methods (Static)
        function [signal, fs, label] = loadSample(sampleId, baseDir)
            arguments
                sampleId (1, 1) string
                baseDir (1, 1) string
            end

            sampleMap = struct( ...
                "sample1", "sample_voice_1.wav", ...
                "sample2", "sample_voice_2.wav");

            if ~isfield(sampleMap, sampleId)
                error("Unsupported sample id: %s", sampleId);
            end

            filePath = fullfile(baseDir, "assets", sampleMap.(sampleId));
            [signal, fs] = audioread(filePath);
            signal = SignalSystemDSP.prepareSignal(signal);

            if sampleId == "sample1"
                label = "样例语音 1";
            else
                label = "样例语音 2";
            end
        end

        function [signal, fs, label] = loadAudioFile(filePath)
            arguments
                filePath (1, 1) string
            end

            [signal, fs] = audioread(filePath);
            signal = SignalSystemDSP.prepareSignal(signal);
            [~, name, ext] = fileparts(filePath);
            label = sprintf("外部音频 %s%s", name, ext);
        end

        function [signal, fs, label] = generateSyntheticSignal(fs, durationSeconds)
            arguments
                fs (1, 1) double {mustBePositive} = 16000
                durationSeconds (1, 1) double {mustBePositive} = 3
            end

            t = (0:1 / fs:durationSeconds).';
            baseTone = 0.42 * sin(2 * pi * 220 * t) ...
                + 0.18 * sin(2 * pi * 440 * t) ...
                + 0.08 * sin(2 * pi * 660 * t);
            glide = 0.26 * chirp(t, 180, t(end), 1900, "linear");
            formantLike = 0.16 * sin(2 * pi * (500 + 300 * sin(2 * pi * 0.4 * t)) .* t);
            envelope = 0.35 + 0.65 * max(0, sin(2 * pi * 1.05 * t));

            signal = envelope .* baseTone + 0.65 * glide + 0.25 * formantLike;
            signal = SignalSystemDSP.normalizeAudio(signal);
            label = "合成测试信号";
        end

        function signal = prepareSignal(signal)
            if size(signal, 2) > 1
                signal = mean(signal, 2);
            end

            signal = signal(:);
            signal = signal - mean(signal, "omitnan");
            nanMask = isnan(signal);
            if any(nanMask)
                signal(nanMask) = 0;
            end

            signal = SignalSystemDSP.normalizeAudio(signal);
        end

        function signal = normalizeAudio(signal)
            signal = signal(:);
            peakValue = max(abs(signal), [], "omitnan");
            if isempty(peakValue) || peakValue < eps
                return;
            end
            signal = 0.95 * signal / peakValue;
        end

        function [signalOut, info] = addNoise(signalIn, fs, noiseType, noiseLevel)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                noiseType (1, 1) string
                noiseLevel (1, 1) double {mustBeNonnegative}
            end

            signalPower = rms(signalIn) + eps;
            t = (0:numel(signalIn) - 1).' / fs;

            switch noiseType
                case "白噪声"
                    noise = noiseLevel * signalPower * randn(size(signalIn));
                    description = sprintf("白噪声，等级 %.2f", noiseLevel);
                case "工频干扰"
                    noise = noiseLevel * signalPower * sin(2 * pi * 50 * t) ...
                        + 0.35 * noiseLevel * signalPower * sin(2 * pi * 100 * t);
                    description = sprintf("50 Hz 工频干扰，等级 %.2f", noiseLevel);
                case "混合噪声"
                    hum = noiseLevel * signalPower * sin(2 * pi * 50 * t);
                    wideband = 0.75 * noiseLevel * signalPower * randn(size(signalIn));
                    noise = hum + wideband;
                    description = sprintf("混合噪声，等级 %.2f", noiseLevel);
                case "脉冲噪声"
                    noise = zeros(size(signalIn));
                    impulseCount = max(4, round(0.008 * numel(signalIn)));
                    impulseIndex = randperm(numel(signalIn), impulseCount);
                    noise(impulseIndex) = noiseLevel * signalPower * (2 * rand(impulseCount, 1) - 1) * 6;
                    description = sprintf("脉冲噪声，等级 %.2f", noiseLevel);
                otherwise
                    error("Unsupported noise type: %s", noiseType);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalIn + noise);
            info = struct();
            info.description = description;
            info.estimatedSNR = SignalSystemDSP.estimateSNR(signalIn, signalOut);
        end

        function [signalOut, info] = applyFilter(signalIn, fs, varargin)
            if nargin == 3 && isstruct(varargin{1})
                config = SignalSystemDSP.normalizeFilterConfig(varargin{1}, fs);
            else
                filterType = string(varargin{1});
                cutoffHz = varargin{2};
                order = varargin{3};
                config = SignalSystemDSP.normalizeFilterConfig(struct( ...
                    "type", filterType, ...
                    "cutoffHz", cutoffHz, ...
                    "order", order), fs);
            end

            [signalOut, info] = SignalSystemDSP.applyFilterConfig(signalIn, fs, config);
        end

        function [signalOut, info] = applyAdvancedEnhancement(signalIn, fs, method, strength)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                method (1, 1) string
                strength (1, 1) double {mustBePositive} = 0.55
            end

            strength = min(max(strength, 0.1), 1.0);
            signalIn = signalIn(:);

            switch method
                case "小波去噪"
                    try
                        level = max(3, min(7, wmaxlev(numel(signalIn), "sym8")));
                        signalOut = wdenoise(signalIn, level, ...
                            "Wavelet", "sym8", ...
                            "DenoisingMethod", "Bayes", ...
                            "ThresholdRule", "Soft");
                        description = sprintf("小波去噪完成，强度 %.2f，分解层数 %d", strength, level);
                    catch
                        windowLength = max(7, 2 * floor(7 + 18 * strength) + 1);
                        signalOut = smoothdata(signalIn, "movmean", windowLength);
                        description = sprintf("小波工具箱不可用，退化为平滑增强，窗口长度 %d", windowLength);
                    end
                case "自适应陷波"
                    [humHz, humScore] = SignalSystemDSP.detectHumFrequency(signalIn, fs);
                    if isnan(humHz)
                        humHz = 50;
                    end
                    nyquist = fs / 2;
                    wo = min(max(humHz / nyquist, 0.001), 0.95);
                    qFactor = 22 + 24 * strength;
                    bw = max(wo / qFactor, 0.0008);
                    [b, a] = iirnotch(wo, bw);
                    signalOut = filtfilt(b, a, signalIn);
                    description = sprintf("自适应陷波完成，中心频率 %.1f Hz，干扰评分 %.2f", humHz, humScore);
                case "语音均衡增强"
                    signalOut = SignalSystemDSP.applyGraphicEQ(signalIn, fs, [0, 0, 3 + 4 * strength, 2 + 2 * strength, 1]);
                    description = sprintf("语音均衡增强完成，中高频补偿强度 %.2f", strength);
                case "维纳降噪"
                    signalOut = wiener2(signalIn, [max(5, 2 * round(6 + 16 * strength) + 1), 1]);
                    description = sprintf("维纳降噪完成，强度 %.2f", strength);
                otherwise
                    error("Unsupported enhancement method: %s", method);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = description;
            info.method = method;
            info.strength = strength;
            info.snrDb = SignalSystemDSP.estimateSNR(signalIn, signalOut);
        end

        function recommendation = recommendProcessing(signalIn, fs)
            recommendation = SignalSystemDSP.recommendFilterConfig(signalIn, fs);
        end

        function profile = classifyNoiseProfile(signalIn, fs)
            profile = SignalSystemDSP.analyzeNoiseSignature(signalIn, fs);
            return;
            signalIn = signalIn(:);
            [f, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signalIn, fs);
            magnitudeLin = 10 .^ (magnitudeDb / 20);
            bandEnergy = SignalSystemDSP.computeBandEnergies(signalIn, fs, [0, 300, 1200, 3400, min(8000, fs / 2)]);
            flatness = exp(mean(log(magnitudeLin + eps))) / (mean(magnitudeLin + eps) + eps);
            crestValue = max(abs(signalIn)) / max(rms(signalIn), eps);
            signalKurtosis = SignalSystemDSP.sampleKurtosis(signalIn);
            impulseScore = signalKurtosis + 0.85 * crestValue;

            [hum50Hz, hum50Score] = SignalSystemDSP.detectHumAt(signalIn, fs, 50);
            [hum60Hz, hum60Score] = SignalSystemDSP.detectHumAt(signalIn, fs, 60);
            highRatio = bandEnergy.high / max(bandEnergy.mid + bandEnergy.low, eps);
            lowRatio = bandEnergy.low / max(bandEnergy.mid + bandEnergy.high, eps);

            profile = struct();
            profile.code = "white";
            profile.label = "白噪声";
            profile.reason = sprintf("谱平坦度 %.2f，频带能量分布较均匀。", flatness);
            profile.humFrequencyHz = NaN;
            profile.flatness = flatness;
            profile.highRatio = highRatio;
            profile.lowRatio = lowRatio;
            profile.impulseScore = impulseScore;
            profile.bandEnergy = bandEnergy;
            profile.magnitudeDb = magnitudeDb;
            profile.frequencyAxis = f;

            if impulseScore > 9.5
                profile.code = "impulse";
                profile.label = "脉冲噪声";
                profile.reason = sprintf("峰值因子 %.2f、峰度 %.2f 偏高，存在脉冲型尖峰。", crestValue, signalKurtosis);
            elseif hum50Score > 8 || hum60Score > 8
                if hum50Score >= hum60Score
                    profile.code = "hum50";
                    profile.label = "50 Hz 工频干扰";
                    profile.reason = sprintf("检测到 %.1f Hz 附近存在明显谱峰，建议使用陷波滤波器。", hum50Hz);
                    profile.humFrequencyHz = hum50Hz;
                else
                    profile.code = "hum60";
                    profile.label = "60 Hz 工频干扰";
                    profile.reason = sprintf("检测到 %.1f Hz 附近存在明显谱峰，建议使用陷波滤波器。", hum60Hz);
                    profile.humFrequencyHz = hum60Hz;
                end
            elseif highRatio > 1.10
                profile.code = "high_freq";
                profile.label = "高频噪声";
                profile.reason = sprintf("高频带能量占比 %.2f 偏高，建议低通滤波。", highRatio);
            elseif lowRatio > 0.95
                profile.code = "low_freq";
                profile.label = "低频环境噪声";
                profile.reason = sprintf("低频带能量占比 %.2f 偏高，建议高通或带通滤波。", lowRatio);
            else
                profile.code = "white";
                profile.label = "白噪声";
                profile.reason = sprintf("谱平坦度 %.2f 较高，建议小波或维纳降噪。", flatness);
            end
        end

        function recommendation = recommendFilterConfig(signalIn, fs)
            recommendation = SignalSystemDSP.buildNoiseRecommendation(signalIn, fs);
            return;
            profile = SignalSystemDSP.classifyNoiseProfile(signalIn, fs);
            recommendation = struct();
            recommendation.filterType = "Butterworth低通";
            recommendation.cutoffHz = min(3200, 0.18 * fs);
            recommendation.order = 6;
            recommendation.lowCutoffHz = 300;
            recommendation.highCutoffHz = min(3400, 0.42 * fs);
            recommendation.stopbandHz = min(4200, 0.45 * fs);
            recommendation.enhancementMethod = "小波去噪";
            recommendation.enhancementStrength = 0.60;
            recommendation.noiseSignature = profile.label;
            recommendation.noiseCode = profile.code;
            recommendation.reason = profile.reason;
            recommendation.filterFamily = "Butterworth";
            recommendation.previewNote = "建议先预览频谱变化，再应用到处理链。";

            switch profile.code
                case "high_freq"
                    recommendation.filterType = "Butterworth低通";
                    recommendation.cutoffHz = min(2800, 0.16 * fs);
                    recommendation.order = 6;
                    recommendation.enhancementMethod = "小波去噪";
                    recommendation.enhancementStrength = 0.62;
                case "low_freq"
                    recommendation.filterType = "Chebyshev高通";
                    recommendation.cutoffHz = 220;
                    recommendation.order = 5;
                    recommendation.enhancementMethod = "语音均衡增强";
                    recommendation.enhancementStrength = 0.40;
                case {"hum50", "hum60"}
                    recommendation.filterType = "陷波";
                    recommendation.cutoffHz = profile.humFrequencyHz;
                    recommendation.order = 4;
                    recommendation.enhancementMethod = "自适应陷波";
                    recommendation.enhancementStrength = 0.78;
                case "impulse"
                    recommendation.filterType = "Median";
                    recommendation.cutoffHz = 7;
                    recommendation.order = 5;
                    recommendation.enhancementMethod = "维纳降噪";
                    recommendation.enhancementStrength = 0.55;
                otherwise
                    recommendation.filterType = "小波去噪";
                    recommendation.cutoffHz = min(3000, 0.16 * fs);
                    recommendation.order = 6;
                    recommendation.enhancementMethod = "维纳降噪";
                    recommendation.enhancementStrength = 0.58;
            end

            recommendation.summary = strjoin([ ...
                "智能分析结果：" + recommendation.noiseSignature, ...
                "推荐理由：" + recommendation.reason, ...
                sprintf("建议滤波器：%s，关键频率 %.0f Hz，阶数 %d。", ...
                    recommendation.filterType, recommendation.cutoffHz, recommendation.order), ...
                sprintf("建议增强：%s，强度 %.2f。", ...
                    recommendation.enhancementMethod, recommendation.enhancementStrength), ...
                "提示：" + recommendation.previewNote], newline);
        end

        % Analyze spectrum and waveform features to infer the dominant noise type.
        function profile = analyzeNoiseSignature(signalIn, fs)
            signalIn = signalIn(:);
            [f, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signalIn, fs);
            magnitudeLin = 10 .^ (magnitudeDb / 20);
            bandProfile = SignalSystemDSP.computeReportBandProfile(signalIn, fs);
            flatness = exp(mean(log(magnitudeLin + eps), "omitnan")) / (mean(magnitudeLin + eps, "omitnan") + eps);
            crestValue = max(abs(signalIn), [], "omitnan") / max(rms(signalIn), eps);
            signalKurtosis = SignalSystemDSP.sampleKurtosis(signalIn);
            impulseScore = signalKurtosis + 0.85 * crestValue;
            deviation = abs(signalIn - median(signalIn, "omitnan"));
            madValue = median(deviation, "omitnan") + eps;
            impulseCount = sum(deviation > 6 * madValue);
            spectralPeakiness = max(magnitudeDb, [], "omitnan") - median(magnitudeDb, "omitnan");

            [hum50Hz, hum50Score] = SignalSystemDSP.detectHumAt(signalIn, fs, 50);
            [hum60Hz, hum60Score] = SignalSystemDSP.detectHumAt(signalIn, fs, 60);
            lowShare = bandProfile.ratio.low;
            speechShare = bandProfile.ratio.speech;
            highShare = bandProfile.ratio.high;

            profile = struct();
            profile.code = "white";
            profile.label = "白噪声";
            profile.reason = sprintf("谱平坦度 %.2f，频带能量分布较均匀。", flatness);
            profile.humFrequencyHz = NaN;
            profile.flatness = flatness;
            profile.lowShare = lowShare;
            profile.speechShare = speechShare;
            profile.highShare = highShare;
            profile.impulseScore = impulseScore;
            profile.impulseCount = impulseCount;
            profile.crestFactor = crestValue;
            profile.kurtosis = signalKurtosis;
            profile.spectralPeakinessDb = spectralPeakiness;
            profile.hum50Score = hum50Score;
            profile.hum60Score = hum60Score;
            profile.bandEnergy = bandProfile.absolute;
            profile.bandRatio = bandProfile.ratio;
            profile.magnitudeDb = magnitudeDb;
            profile.frequencyAxis = f;
            profile.confidence = 0.55;

            if impulseScore > 9.5 || impulseCount >= max(5, round(0.0025 * numel(signalIn)))
                profile.code = "impulse";
                profile.label = "脉冲噪声";
                profile.reason = sprintf("检测到 %d 个异常尖峰，峰度 %.2f、峰值因子 %.2f 偏高，建议使用中值滤波。", ...
                    impulseCount, signalKurtosis, crestValue);
                profile.confidence = min(0.98, 0.60 + 0.02 * impulseCount);
            elseif hum50Score > 8 || hum60Score > 8
                if hum50Score >= hum60Score
                    profile.code = "hum50";
                    profile.label = "50 Hz 工频干扰";
                    profile.reason = sprintf("检测到 %.1f Hz 附近存在明显谱峰，工频干扰评分 %.2f，建议使用陷波滤波器。", ...
                        hum50Hz, hum50Score);
                    profile.humFrequencyHz = hum50Hz;
                    profile.confidence = min(0.99, 0.58 + 0.025 * hum50Score);
                else
                    profile.code = "hum60";
                    profile.label = "60 Hz 工频干扰";
                    profile.reason = sprintf("检测到 %.1f Hz 附近存在明显谱峰，工频干扰评分 %.2f，建议使用陷波滤波器。", ...
                        hum60Hz, hum60Score);
                    profile.humFrequencyHz = hum60Hz;
                    profile.confidence = min(0.99, 0.58 + 0.025 * hum60Score);
                end
            elseif highShare >= 0.42 && highShare > speechShare
                profile.code = "high_freq";
                profile.label = "高频噪声";
                profile.reason = sprintf("高频段能量占比 %.1f%% 偏高，建议使用低通滤波。", 100 * highShare);
                profile.confidence = min(0.95, 0.55 + 0.70 * max(highShare - speechShare / 2, 0));
            elseif lowShare >= 0.28 && lowShare > speechShare * 0.55
                profile.code = "low_freq";
                profile.label = "低频环境噪声";
                profile.reason = sprintf("低频段能量占比 %.1f%% 偏高，建议使用高通滤波。", 100 * lowShare);
                profile.confidence = min(0.92, 0.55 + 0.85 * lowShare);
            elseif flatness >= 0.52 && spectralPeakiness <= 18
                profile.code = "white";
                profile.label = "白噪声";
                profile.reason = sprintf("谱平坦度 %.2f 较高，且频谱峰值起伏 %.2f dB 较小，建议小波去噪或维纳滤波。", ...
                    flatness, spectralPeakiness);
                profile.confidence = min(0.93, 0.50 + 0.65 * flatness);
            elseif highShare > lowShare
                profile.code = "high_freq";
                profile.label = "高频噪声";
                profile.reason = sprintf("高频段能量占比 %.1f%% 高于低频段 %.1f%%，建议优先尝试低通滤波。", ...
                    100 * highShare, 100 * lowShare);
                profile.confidence = 0.62;
            else
                profile.code = "low_freq";
                profile.label = "低频环境噪声";
                profile.reason = sprintf("低频段能量占比 %.1f%% 高于高频段 %.1f%%，建议优先尝试高通滤波。", ...
                    100 * lowShare, 100 * highShare);
                profile.confidence = 0.60;
            end
        end

        % Convert the detected noise profile into filter and enhancement suggestions.
        function recommendation = buildNoiseRecommendation(signalIn, fs)
            profile = SignalSystemDSP.analyzeNoiseSignature(signalIn, fs);
            recommendation = struct();
            recommendation.filterType = "Butterworth低通";
            recommendation.cutoffHz = min(3200, 0.18 * fs);
            recommendation.order = 6;
            recommendation.lowCutoffHz = 300;
            recommendation.highCutoffHz = min(3400, 0.42 * fs);
            recommendation.stopbandHz = min(4200, 0.45 * fs);
            recommendation.enhancementMethod = "小波去噪";
            recommendation.enhancementStrength = 0.60;
            recommendation.noiseSignature = profile.label;
            recommendation.noiseCode = profile.code;
            recommendation.reason = profile.reason;
            recommendation.filterFamily = "Butterworth";
            recommendation.previewNote = "建议先分析噪声，再一键加载或直接应用推荐滤波器。";
            recommendation.primaryNoiseType = profile.label;
            recommendation.confidence = profile.confidence;
            recommendation.centerFrequencyHz = profile.humFrequencyHz;
            recommendation.sourceStage = "";
            recommendation.lastAppliedInputStage = "";
            recommendation.lastAppliedOutputStage = "";
            recommendation.analysisProfile = profile;

            switch profile.code
                case "high_freq"
                    recommendation.filterType = "Butterworth低通";
                    recommendation.cutoffHz = min(2800, 0.16 * fs);
                    recommendation.order = 6;
                    recommendation.enhancementMethod = "小波去噪";
                    recommendation.enhancementStrength = 0.62;
                case "low_freq"
                    recommendation.filterType = "Chebyshev高通";
                    recommendation.cutoffHz = max(120, min(280, round(300 * profile.lowShare)));
                    recommendation.order = 5;
                    recommendation.enhancementMethod = "语音均衡增强";
                    recommendation.enhancementStrength = 0.40;
                case {"hum50", "hum60"}
                    recommendation.filterType = "陷波";
                    recommendation.cutoffHz = profile.humFrequencyHz;
                    recommendation.order = 4;
                    recommendation.enhancementMethod = "自适应陷波";
                    recommendation.enhancementStrength = 0.78;
                case "impulse"
                    recommendation.filterType = "Median";
                    recommendation.cutoffHz = 7;
                    recommendation.order = 5;
                    recommendation.enhancementMethod = "维纳降噪";
                    recommendation.enhancementStrength = 0.55;
                otherwise
                    recommendation.filterType = "小波去噪";
                    recommendation.cutoffHz = min(3000, 0.16 * fs);
                    recommendation.order = 6;
                    recommendation.enhancementMethod = "维纳降噪";
                    recommendation.enhancementStrength = 0.58;
            end

            recommendation.recommendedFilterType = recommendation.filterType;
            recommendation.recommendedFrequencyHz = recommendation.cutoffHz;
            recommendation.recommendedOrder = recommendation.order;
            recommendation.summary = strjoin([ ...
                "智能分析结果：" + recommendation.noiseSignature, ...
                sprintf("置信度：%.0f%%", 100 * recommendation.confidence), ...
                "推荐理由：" + recommendation.reason, ...
                sprintf("推荐滤波器：%s | 关键频率 %.0f Hz | 阶数 %d", ...
                    recommendation.filterType, recommendation.cutoffHz, recommendation.order), ...
                sprintf("建议增强：%s | 强度 %.2f", ...
                    recommendation.enhancementMethod, recommendation.enhancementStrength), ...
                "提示：" + recommendation.previewNote], newline);
        end

        function metrics = evaluateProcessing(referenceSignal, processedSignal, fs, cleanReferenceSignal)
            arguments
                referenceSignal (:, 1) double
                processedSignal (:, 1) double
                fs (1, 1) double {mustBePositive}
                cleanReferenceSignal double = []
            end

            metrics = SignalSystemDSP.createEmptyProcessingMetrics();
            [referenceSignal, processedSignal] = SignalSystemDSP.alignSignals(referenceSignal, processedSignal);
            if isempty(referenceSignal) || isempty(processedSignal)
                metrics.evaluationText = "无可用信号，未生成评价。";
                metrics.summaryText = metrics.evaluationText;
                return;
            end

            errorSignal = processedSignal - referenceSignal;
            beforeBand = SignalSystemDSP.computeReportBandProfile(referenceSignal, fs);
            afterBand = SignalSystemDSP.computeReportBandProfile(processedSignal, fs);
            beforeDom = SignalSystemDSP.findDominantFrequency(referenceSignal, fs);
            afterDom = SignalSystemDSP.findDominantFrequency(processedSignal, fs);
            comparison = SignalSystemDSP.compareSignals(referenceSignal, processedSignal);
            beforePeakDb = SignalSystemDSP.findSpectrumPeakDb(referenceSignal, fs);
            afterPeakDb = SignalSystemDSP.findSpectrumPeakDb(processedSignal, fs);

            metrics.snrDb = comparison.snrDb;
            metrics.mse = mean(errorSignal .^ 2, "omitnan");
            metrics.rmse = sqrt(metrics.mse);
            metrics.correlation = comparison.correlation;
            metrics.qualityScore = comparison.qualityScore;
            metrics.beforeDominantFrequencyHz = beforeDom;
            metrics.afterDominantFrequencyHz = afterDom;
            metrics.dominantFrequencyDeltaHz = afterDom - beforeDom;
            metrics.beforeTotalEnergy = mean(referenceSignal .^ 2, "omitnan");
            metrics.afterTotalEnergy = mean(processedSignal .^ 2, "omitnan");
            metrics.energyDelta = metrics.afterTotalEnergy - metrics.beforeTotalEnergy;
            metrics.beforeSpectrumPeakDb = beforePeakDb;
            metrics.afterSpectrumPeakDb = afterPeakDb;
            metrics.spectrumPeakDeltaDb = afterPeakDb - beforePeakDb;
            metrics.bandEnergyBefore = beforeBand.absolute;
            metrics.bandEnergyAfter = afterBand.absolute;
            metrics.bandEnergyDelta = struct( ...
                "low", afterBand.absolute.low - beforeBand.absolute.low, ...
                "speech", afterBand.absolute.speech - beforeBand.absolute.speech, ...
                "high", afterBand.absolute.high - beforeBand.absolute.high);
            metrics.bandEnergyRatioBefore = beforeBand.ratio;
            metrics.bandEnergyRatioAfter = afterBand.ratio;
            metrics.bandEnergyRatioDelta = struct( ...
                "low", afterBand.ratio.low - beforeBand.ratio.low, ...
                "speech", afterBand.ratio.speech - beforeBand.ratio.speech, ...
                "high", afterBand.ratio.high - beforeBand.ratio.high);

            cleanReferenceSignal = cleanReferenceSignal(:);
            if ~isempty(cleanReferenceSignal)
                [cleanBefore, alignedBefore] = SignalSystemDSP.alignSignals(cleanReferenceSignal, referenceSignal);
                [cleanAfter, alignedAfter] = SignalSystemDSP.alignSignals(cleanReferenceSignal, processedSignal);
                beforeQuality = SignalSystemDSP.compareSignals(cleanBefore, alignedBefore);
                afterQuality = SignalSystemDSP.compareSignals(cleanAfter, alignedAfter);
                metrics.hasCleanReference = true;
                metrics.snrType = "reference";
                metrics.snrBeforeDb = beforeQuality.snrDb;
                metrics.snrAfterDb = afterQuality.snrDb;
                metrics.snrDb = afterQuality.snrDb;
                metrics.correlation = afterQuality.correlation;
                metrics.qualityScore = afterQuality.qualityScore;
            else
                metrics.hasCleanReference = false;
                metrics.snrType = "estimated";
                metrics.snrBeforeDb = SignalSystemDSP.estimateNoReferenceSNR(referenceSignal, fs);
                metrics.snrAfterDb = SignalSystemDSP.estimateNoReferenceSNR(processedSignal, fs);
                metrics.snrDb = metrics.snrAfterDb;
            end

            metrics.snrImprovementDb = metrics.snrAfterDb - metrics.snrBeforeDb;
            metrics.denoiseImprovementDb = metrics.snrImprovementDb;
            metrics.evaluationText = SignalSystemDSP.summarizeProcessingMetrics(metrics);
            if metrics.snrType == "reference"
                metrics.summaryText = sprintf("参考SNR %.2f -> %.2f dB，提升 %.2f dB。%s", ...
                    metrics.snrBeforeDb, metrics.snrAfterDb, metrics.snrImprovementDb, metrics.evaluationText);
            else
                metrics.summaryText = sprintf("无参考估计SNR %.2f -> %.2f dB，变化 %.2f dB。%s", ...
                    metrics.snrBeforeDb, metrics.snrAfterDb, metrics.snrImprovementDb, metrics.evaluationText);
            end
        end

        function metrics = computeMetrics(signal, fs, referenceSignal)
            arguments
                signal (:, 1) double
                fs (1, 1) double {mustBePositive}
                referenceSignal double = []
            end

            metrics = struct();
            metrics.durationSeconds = numel(signal) / fs;
            metrics.rmsValue = rms(signal);
            metrics.peakValue = max(abs(signal), [], "omitnan");
            metrics.meanValue = mean(signal, "omitnan");
            metrics.dominantFrequencyHz = SignalSystemDSP.findDominantFrequency(signal, fs);
            metrics.crestFactor = metrics.peakValue / max(metrics.rmsValue, eps);
            metrics.totalEnergy = mean(signal .^ 2, "omitnan");
            metrics.spectrumPeakDb = SignalSystemDSP.findSpectrumPeakDb(signal, fs);
            bandProfile = SignalSystemDSP.computeReportBandProfile(signal, fs);
            metrics.bandEnergy = bandProfile.absolute;
            metrics.bandEnergyRatio = bandProfile.ratio;

            if ~isempty(referenceSignal)
                comparison = SignalSystemDSP.compareSignals(referenceSignal, signal);
                metrics.snrDb = comparison.snrDb;
                metrics.correlation = comparison.correlation;
                metrics.qualityScore = comparison.qualityScore;
                metrics.rmse = comparison.rmse;
                metrics.snrType = "reference";
            else
                metrics.snrDb = SignalSystemDSP.estimateNoReferenceSNR(signal, fs);
                metrics.correlation = NaN;
                metrics.qualityScore = NaN;
                metrics.rmse = NaN;
                metrics.snrType = "estimated";
            end
        end

        function comparison = compareSignals(referenceSignal, testSignal, referenceFs, testFs)
            if nargin < 3
                referenceFs = [];
            end
            if nargin < 4
                testFs = referenceFs;
            end
            referenceSignal = referenceSignal(:);
            testSignal = testSignal(:);

            comparison = struct();
            comparison.snrDb = NaN;
            comparison.correlation = NaN;
            comparison.rmse = NaN;
            comparison.mse = NaN;
            comparison.qualityScore = NaN;
            comparison.alignedLength = 0;
            comparison.resampled = false;

            if isempty(referenceSignal) || isempty(testSignal)
                return;
            end

            [referenceSignal, testSignal, alignInfo] = SignalSystemDSP.alignSignals(referenceSignal, testSignal, referenceFs, testFs);
            comparison.alignedLength = numel(referenceSignal);
            comparison.resampled = alignInfo.resampled;
            if isempty(referenceSignal) || isempty(testSignal)
                return;
            end

            errorSignal = testSignal - referenceSignal;
            signalPower = mean(referenceSignal .^ 2, "omitnan") + eps;
            noisePower = mean(errorSignal .^ 2, "omitnan") + eps;
            comparison.snrDb = 10 * log10(signalPower / noisePower);
            comparison.mse = noisePower;
            comparison.rmse = sqrt(noisePower);

            if numel(referenceSignal) < 2 || std(referenceSignal, "omitnan") < eps || std(testSignal, "omitnan") < eps
                comparison.correlation = 1 - min(comparison.rmse, 1);
            else
                cc = corrcoef(referenceSignal, testSignal);
                if numel(cc) >= 4 && ~isnan(cc(1, 2))
                    comparison.correlation = cc(1, 2);
                else
                    comparison.correlation = 1 - min(comparison.rmse, 1);
                end
            end

            comparison.qualityScore = SignalSystemDSP.computeQualityScore(comparison);
        end

        function snrDb = estimateSNR(referenceSignal, testSignal)
            comparison = SignalSystemDSP.compareSignals(referenceSignal, testSignal);
            snrDb = comparison.snrDb;
        end

        function tableData = metricsToTable(metrics, stageKey, moduleName)
            if nargin < 2 || strlength(string(stageKey)) == 0
                stageKey = "stage";
            end
            if nargin < 3 || strlength(string(moduleName)) == 0
                moduleName = "processing";
            end

            tableData = table( ...
                string(stageKey), string(moduleName), string(metrics.snrType), ...
                metrics.snrBeforeDb, metrics.snrAfterDb, metrics.snrImprovementDb, ...
                metrics.mse, metrics.rmse, ...
                metrics.beforeTotalEnergy, metrics.afterTotalEnergy, metrics.energyDelta, ...
                metrics.beforeDominantFrequencyHz, metrics.afterDominantFrequencyHz, metrics.dominantFrequencyDeltaHz, ...
                metrics.beforeSpectrumPeakDb, metrics.afterSpectrumPeakDb, metrics.spectrumPeakDeltaDb, ...
                metrics.bandEnergyBefore.low, metrics.bandEnergyAfter.low, metrics.bandEnergyDelta.low, ...
                metrics.bandEnergyRatioBefore.low, metrics.bandEnergyRatioAfter.low, metrics.bandEnergyRatioDelta.low, ...
                metrics.bandEnergyBefore.speech, metrics.bandEnergyAfter.speech, metrics.bandEnergyDelta.speech, ...
                metrics.bandEnergyRatioBefore.speech, metrics.bandEnergyRatioAfter.speech, metrics.bandEnergyRatioDelta.speech, ...
                metrics.bandEnergyBefore.high, metrics.bandEnergyAfter.high, metrics.bandEnergyDelta.high, ...
                metrics.bandEnergyRatioBefore.high, metrics.bandEnergyRatioAfter.high, metrics.bandEnergyRatioDelta.high, ...
                metrics.denoiseImprovementDb, string(metrics.evaluationText), ...
                'VariableNames', { ...
                'stage','module','snr_type','snr_before_db','snr_after_db','snr_improvement_db', ...
                'mse','rmse','energy_before','energy_after','energy_delta', ...
                'dominant_before_hz','dominant_after_hz','dominant_delta_hz', ...
                'spectrum_peak_before_db','spectrum_peak_after_db','spectrum_peak_delta_db', ...
                'low_before','low_after','low_delta','low_ratio_before','low_ratio_after','low_ratio_delta', ...
                'speech_before','speech_after','speech_delta','speech_ratio_before','speech_ratio_after','speech_ratio_delta', ...
                'high_before','high_after','high_delta','high_ratio_before','high_ratio_after','high_ratio_delta', ...
                'denoise_improvement_db','evaluation'} ...
                );
        end

        function filePath = exportMetricsCsv(outputDir, fileName, metrics, stageKey, moduleName)
            if ~exist(outputDir, "dir")
                mkdir(outputDir);
            end
            metricTable = SignalSystemDSP.metricsToTable(metrics, stageKey, moduleName);
            filePath = fullfile(outputDir, fileName);
            writetable(metricTable, filePath);
        end

        % Prepare two stage signals for aligned A/B comparison and listening.
        function pairInfo = prepareComparisonSignals(signalA, signalB, fsA, fsB)
            arguments
                signalA (:, 1) double
                signalB (:, 1) double
                fsA (1, 1) double {mustBePositive}
                fsB (1, 1) double {mustBePositive} = fsA
            end

            [alignedA, alignedB, alignInfo] = SignalSystemDSP.alignSignals(signalA, signalB, fsA, fsB);
            pairInfo = struct();
            pairInfo.signalA = alignedA;
            pairInfo.signalB = alignedB;
            pairInfo.differenceSignal = alignedA - alignedB;
            pairInfo.fsA = fsA;
            pairInfo.fsB = fsB;
            pairInfo.compareFs = fsA;
            pairInfo.originalLengthA = numel(signalA);
            pairInfo.originalLengthB = numel(signalB);
            pairInfo.alignedLength = numel(alignedA);
            pairInfo.durationASeconds = numel(signalA) / fsA;
            pairInfo.durationBSeconds = numel(signalB) / fsB;
            pairInfo.alignedDurationSeconds = numel(alignedA) / fsA;
            pairInfo.resampled = alignInfo.resampled;
        end

        % Compute waveform, spectrum and metric differences for any two stages.
        function comparisonInfo = compareStagePair(signalA, signalB, fsA, fsB)
            arguments
                signalA (:, 1) double
                signalB (:, 1) double
                fsA (1, 1) double {mustBePositive}
                fsB (1, 1) double {mustBePositive} = fsA
            end

            pairInfo = SignalSystemDSP.prepareComparisonSignals(signalA, signalB, fsA, fsB);
            comparison = SignalSystemDSP.compareSignals(signalA, signalB, fsA, fsB);
            metricsA = SignalSystemDSP.computeMetrics(pairInfo.signalA, pairInfo.compareFs);
            metricsB = SignalSystemDSP.computeMetrics(pairInfo.signalB, pairInfo.compareFs);
            [frequencyAxis, magnitudeA] = SignalSystemDSP.magnitudeSpectrum(pairInfo.signalA, pairInfo.compareFs);
            [~, magnitudeB] = SignalSystemDSP.magnitudeSpectrum(pairInfo.signalB, pairInfo.compareFs);
            spectrumDeltaDb = magnitudeA - magnitudeB;

            comparisonInfo = struct();
            comparisonInfo.pairInfo = pairInfo;
            comparisonInfo.comparison = comparison;
            comparisonInfo.metricsA = metricsA;
            comparisonInfo.metricsB = metricsB;
            comparisonInfo.frequencyAxis = frequencyAxis;
            comparisonInfo.magnitudeA = magnitudeA;
            comparisonInfo.magnitudeB = magnitudeB;
            comparisonInfo.spectrumDeltaDb = spectrumDeltaDb;
            comparisonInfo.spectralDifferenceDb = rms(spectrumDeltaDb, "omitnan");
            comparisonInfo.diffSignalPeak = max(abs(pairInfo.differenceSignal), [], "omitnan");
            comparisonInfo.diffSignalEnergy = mean(pairInfo.differenceSignal .^ 2, "omitnan");
        end

        % Export A/B comparison plots, metrics table and difference audio.
        function exportInfo = exportComparisonBundle(outputDir, stageALabel, stageBLabel, comparisonInfo)
            arguments
                outputDir (1, 1) string
                stageALabel (1, 1) string
                stageBLabel (1, 1) string
                comparisonInfo (1, 1) struct
            end

            if ~exist(outputDir, "dir")
                mkdir(outputDir);
            end

            safeA = regexprep(lower(char(stageALabel)), '[^a-zA-Z0-9]+', '_');
            safeB = regexprep(lower(char(stageBLabel)), '[^a-zA-Z0-9]+', '_');
            if isempty(safeA)
                safeA = 'stage_a';
            end
            if isempty(safeB)
                safeB = 'stage_b';
            end
            prefix = string("ab_compare_" + safeA + "_vs_" + safeB + "_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")));

            timeAxis = (0:comparisonInfo.pairInfo.alignedLength - 1) / comparisonInfo.pairInfo.compareFs;
            fig = figure("Visible", "off", "Color", "w", "Position", [90, 90, 1380, 980]);
            layout = tiledlayout(fig, 3, 2, "Padding", "compact", "TileSpacing", "compact");
            title(layout, stageALabel + " vs " + stageBLabel + " A/B Comparison", "FontWeight", "bold");

            ax = nexttile(layout);
            SignalSystemDSP.drawWaveform(ax, comparisonInfo.pairInfo.signalA, comparisonInfo.pairInfo.compareFs, stageALabel + " Waveform", [0.12, 0.45, 0.73]);
            ax = nexttile(layout);
            SignalSystemDSP.drawWaveform(ax, comparisonInfo.pairInfo.signalB, comparisonInfo.pairInfo.compareFs, stageBLabel + " Waveform", [0.79, 0.24, 0.24]);

            ax = nexttile(layout);
            plot(ax, timeAxis, comparisonInfo.pairInfo.signalA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
            hold(ax, "on");
            plot(ax, timeAxis, comparisonInfo.pairInfo.signalB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
            hold(ax, "off");
            grid(ax, "on");
            xlabel(ax, "Time / s");
            ylabel(ax, "Amplitude");
            title(ax, "Overlay Waveform");
            legend(ax, [stageALabel, stageBLabel], "Location", "best");

            ax = nexttile(layout);
            plot(ax, comparisonInfo.frequencyAxis, comparisonInfo.magnitudeA, "LineWidth", 1.0, "Color", [0.12, 0.45, 0.73]);
            hold(ax, "on");
            plot(ax, comparisonInfo.frequencyAxis, comparisonInfo.magnitudeB, "LineWidth", 1.0, "Color", [0.79, 0.24, 0.24]);
            hold(ax, "off");
            grid(ax, "on");
            xlabel(ax, "Frequency / Hz");
            ylabel(ax, "Magnitude / dB");
            title(ax, "A/B Spectrum");
            legend(ax, [stageALabel, stageBLabel], "Location", "best");
            xlim(ax, [0, min(comparisonInfo.pairInfo.compareFs / 2, 4000)]);

            ax = nexttile(layout);
            SignalSystemDSP.drawWaveform(ax, comparisonInfo.pairInfo.differenceSignal, comparisonInfo.pairInfo.compareFs, "Difference Waveform", [0.55, 0.19, 0.68]);
            ax = nexttile(layout);
            plot(ax, comparisonInfo.frequencyAxis, comparisonInfo.spectrumDeltaDb, "LineWidth", 1.0, "Color", [0.55, 0.19, 0.68]);
            grid(ax, "on");
            xlabel(ax, "Frequency / Hz");
            ylabel(ax, "Delta / dB");
            title(ax, "Difference Spectrum");
            xlim(ax, [0, min(comparisonInfo.pairInfo.compareFs / 2, 4000)]);

            overviewPath = fullfile(outputDir, char(prefix + "_overview.png"));
            exportgraphics(fig, overviewPath, "Resolution", 220);
            close(fig);

            diffSpectrumFig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1180, 420]);
            ax = axes(diffSpectrumFig);
            plot(ax, comparisonInfo.frequencyAxis, comparisonInfo.spectrumDeltaDb, "LineWidth", 1.1, "Color", [0.55, 0.19, 0.68]);
            grid(ax, "on");
            xlabel(ax, "Frequency / Hz");
            ylabel(ax, "Delta / dB");
            title(ax, "Difference Spectrum");
            xlim(ax, [0, min(comparisonInfo.pairInfo.compareFs / 2, 4000)]);
            diffSpectrumPath = fullfile(outputDir, char(prefix + "_diff_spectrum.png"));
            exportgraphics(diffSpectrumFig, diffSpectrumPath, "Resolution", 220);
            close(diffSpectrumFig);

            metricTable = table( ...
                string(stageALabel), string(stageBLabel), ...
                comparisonInfo.pairInfo.fsA, comparisonInfo.pairInfo.fsB, comparisonInfo.pairInfo.compareFs, ...
                comparisonInfo.pairInfo.originalLengthA, comparisonInfo.pairInfo.originalLengthB, comparisonInfo.pairInfo.alignedLength, ...
                comparisonInfo.metricsA.totalEnergy, comparisonInfo.metricsB.totalEnergy, ...
                comparisonInfo.comparison.mse, comparisonInfo.comparison.rmse, comparisonInfo.comparison.correlation, ...
                comparisonInfo.spectralDifferenceDb, comparisonInfo.diffSignalEnergy, comparisonInfo.diffSignalPeak, ...
                comparisonInfo.pairInfo.resampled, ...
                'VariableNames', {'stage_a','stage_b','fs_a','fs_b','compare_fs','length_a','length_b','aligned_length','energy_a','energy_b','mse','rmse','correlation','spectral_difference_db','difference_energy','difference_peak','resampled'});
            metricsPath = fullfile(outputDir, char(prefix + "_metrics.csv"));
            writetable(metricTable, metricsPath);

            diffAudioPath = fullfile(outputDir, char(prefix + "_difference.wav"));
            audiowrite(diffAudioPath, SignalSystemDSP.normalizeAudio(comparisonInfo.pairInfo.differenceSignal), comparisonInfo.pairInfo.compareFs);

            exportInfo = struct();
            exportInfo.overviewPath = string(overviewPath);
            exportInfo.diffSpectrumPath = string(diffSpectrumPath);
            exportInfo.metricsPath = string(metricsPath);
            exportInfo.diffAudioPath = string(diffAudioPath);
        end

        function [frameInfo, trendPoint] = analyzeLiveFrame(frame, fs, bandEdges)
            arguments
                frame (:, 1) double
                fs (1, 1) double {mustBePositive}
                bandEdges (1, :) double = [0, 300, 1200, 3400, 8000]
            end

            frame = frame(:);
            frameInfo = struct();
            frameInfo.shortTimeEnergy = mean(frame .^ 2, "omitnan");
            frameInfo.rmsValue = rms(frame);
            frameInfo.peakValue = max(abs(frame), [], "omitnan");
            frameInfo.dominantFrequencyHz = SignalSystemDSP.findDominantFrequency(frame, fs);
            frameInfo.bandEnergy = SignalSystemDSP.computeBandEnergies(frame, fs, bandEdges);
            frameInfo.spectralCentroidHz = SignalSystemDSP.spectralCentroid(frame, fs);

            trendPoint = [ ...
                frameInfo.shortTimeEnergy, ...
                frameInfo.dominantFrequencyHz, ...
                frameInfo.bandEnergy.low, ...
                frameInfo.bandEnergy.mid, ...
                frameInfo.bandEnergy.high];
        end

        function liveView = buildLiveSpectrogram(buffer, fs, config)
            arguments
                buffer (:, 1) double
                fs (1, 1) double {mustBePositive}
                config struct = struct()
            end

            if ~isfield(config, "frameLength")
                config.frameLength = 512;
            end
            if ~isfield(config, "overlapLength")
                config.overlapLength = 256;
            end
            if ~isfield(config, "nfft")
                config.nfft = 1024;
            end

            frameLength = max(128, round(config.frameLength));
            overlapLength = min(round(config.overlapLength), frameLength - 1);
            nfft = max(512, round(config.nfft));
            buffer = buffer(:);

            if numel(buffer) < frameLength
                padded = [buffer; zeros(frameLength - numel(buffer), 1)];
            else
                padded = buffer;
            end

            [s, f, t] = spectrogram(padded, hann(frameLength, "periodic"), overlapLength, nfft, fs);
            powerDb = 20 * log10(abs(s) + 1e-6);
            recentFrame = padded(max(1, end - frameLength + 1):end);
            [fftAxis, fftDb] = SignalSystemDSP.magnitudeSpectrum(recentFrame, fs);

            liveView = struct();
            liveView.timeAxis = t;
            liveView.frequencyAxis = f;
            liveView.powerDb = powerDb;
            liveView.fftAxis = fftAxis;
            liveView.fftDb = fftDb;
            liveView.latestFrame = recentFrame;
        end

        function [signalOut, info] = applyVoiceProcessor(signalIn, fs, voiceConfig)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                voiceConfig (1, 1) struct
            end

            signalIn = signalIn(:);
            config = SignalSystemDSP.normalizeVoiceConfig(voiceConfig);
            modeName = string(config.mode);

            switch modeName
                case "原声"
                    signalOut = signalIn;
                    description = "原声直通";
                case {"男声", "低音"}
                    signalOut = SignalSystemDSP.pitchShiftTimePreserving(signalIn, max(config.pitchSemitone, -7), config.speedFactor);
                    signalOut = SignalSystemDSP.applyLowShelf(signalOut, fs, 220, 2.5);
                    description = sprintf("%s变换，音高 %.1f 半音，语速 %.2f 倍", modeName, config.pitchSemitone, config.speedFactor);
                case {"女声", "高音"}
                    signalOut = SignalSystemDSP.pitchShiftTimePreserving(signalIn, min(config.pitchSemitone, 7), config.speedFactor);
                    description = sprintf("%s变换，音高 %.1f 半音，语速 %.2f 倍", modeName, config.pitchSemitone, config.speedFactor);
                case "机器人"
                    t = (0:numel(signalIn) - 1).' / fs;
                    carrier = 1 + config.modDepth * cos(2 * pi * config.modFrequencyHz * t);
                    signalOut = signalIn .* carrier;
                    description = sprintf("机器人音，调制频率 %.0f Hz，深度 %.2f", config.modFrequencyHz, config.modDepth);
                case {"电话音", "对讲机音"}
                    signalOut = SignalSystemDSP.applyBandPassVoice(signalIn, fs, 300, min(3400, 0.42 * fs));
                    signalOut = signalOut + 0.015 * randn(size(signalOut));
                    signalOut = tanh(1.8 * signalOut);
                    description = "电话音/对讲机音，300-3400 Hz 带通并叠加轻微失真";
                case {"回声", "山谷音"}
                    signalOut = SignalSystemDSP.applyEcho(signalIn, fs, config.echoDelaySeconds, config.echoStrength);
                    description = sprintf("回声效果，延迟 %.0f ms，强度 %.2f", config.echoDelaySeconds * 1000, config.echoStrength);
                case "怪兽音"
                    signalOut = SignalSystemDSP.pitchShiftTimePreserving(signalIn, -7, 0.94);
                    signalOut = SignalSystemDSP.applyLowShelf(signalOut, fs, 180, 5.0);
                    signalOut = SignalSystemDSP.applyEcho(signalOut, fs, 0.22, 0.28);
                    description = "怪兽音：降调、增强低频并叠加轻微回声";
                case "自定义 EQ"
                    signalOut = SignalSystemDSP.applyGraphicEQ(signalIn, fs, config.eqGainsDb);
                    if abs(config.pitchSemitone) > eps || abs(config.speedFactor - 1) > eps
                        signalOut = SignalSystemDSP.pitchShiftTimePreserving(signalOut, config.pitchSemitone, config.speedFactor);
                    end
                    description = "自定义 5 段 EQ 已应用";
                otherwise
                    signalOut = SignalSystemDSP.pitchShiftTimePreserving(signalIn, config.pitchSemitone, config.speedFactor);
                    description = sprintf("自定义音高变换，音高 %.1f 半音，语速 %.2f 倍", config.pitchSemitone, config.speedFactor);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = description;
            info.mode = modeName;
            info.config = config;
            info.metrics = SignalSystemDSP.evaluateProcessing(signalIn, signalOut, fs);
        end

        function [signalOut, info] = applyVoiceEffect(signalIn, fs, effectType)
            config = struct( ...
                "mode", effectType, ...
                "pitchSemitone", 5 * double(effectType == "高音") - 5 * double(effectType == "低音"), ...
                "speedFactor", 1.0, ...
                "echoDelaySeconds", 0.18, ...
                "echoStrength", 0.45, ...
                "modFrequencyHz", 85, ...
                "modDepth", 1.0, ...
                "eqGainsDb", [0, 0, 0, 0, 0]);
            [signalOut, info] = SignalSystemDSP.applyVoiceProcessor(signalIn, fs, config);
        end

        function [signalOut, info] = applyVoiceStudioEffect(signalIn, fs, voiceConfig)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                voiceConfig (1, 1) struct
            end

            signalIn = signalIn(:);
            config = SignalSystemDSP.normalizeVoiceConfig(voiceConfig);
            modeName = string(config.mode);

            switch modeName
                case {"原声", "鍘熷０"}
                    signalOut = signalIn;
                    description = "原声直通";
                case {"男声", "鐢峰０", "浣庨煶"}
                    semitone = -max(4, abs(config.pitchSemitone));
                    signalOut = SignalSystemDSP.voicePitchShift(signalIn, semitone);
                    signalOut = SignalSystemDSP.applyLowShelf(signalOut, fs, 220, 2.5);
                    description = sprintf("男声变换，音高 %.1f 半音", semitone);
                case {"女声", "濂冲０", "楂橀煶"}
                    semitone = max(4, abs(config.pitchSemitone));
                    signalOut = SignalSystemDSP.voicePitchShift(signalIn, semitone);
                    description = sprintf("女声变换，音高 +%.1f 半音", semitone);
                case {"机器人音", "鏈哄櫒浜?"}
                    t = (0:numel(signalIn) - 1).' / fs;
                    modulated = signalIn .* cos(2 * pi * config.modFrequencyHz * t);
                    signalOut = (1 - config.modDepth) * signalIn + config.modDepth * modulated;
                    description = sprintf("机器人音，调制频率 %.0f Hz，调制深度 %.2f", config.modFrequencyHz, config.modDepth);
                case {"电话音 / 对讲机音", "电话音", "对讲机音", "鐢佃瘽闊?", "瀵硅鏈洪煶"}
                    signalOut = SignalSystemDSP.applyBandPassVoice(signalIn, fs, 300, min(3400, 0.42 * fs));
                    signalOut = signalOut + 0.010 * rms(signalIn) * randn(size(signalOut));
                    signalOut = tanh(1.6 * signalOut);
                    description = "电话音 / 对讲机音，300-3400 Hz 带通并叠加轻微噪声与失真";
                case {"回声音 / 山谷音", "回声音", "山谷音", "鍥炲０", "灞辫胺闊?"}
                    signalOut = SignalSystemDSP.applyEcho(signalIn, fs, config.echoDelaySeconds, config.echoStrength);
                    description = sprintf("回声效果，延迟 %.0f ms，强度 %.2f", config.echoDelaySeconds * 1000, config.echoStrength);
                case {"怪兽音", "鎬吔闊?"}
                    semitone = -max(6, abs(config.pitchSemitone));
                    signalOut = SignalSystemDSP.voicePitchShift(signalIn, semitone);
                    signalOut = SignalSystemDSP.applyLowShelf(signalOut, fs, 180, 6.0);
                    signalOut = SignalSystemDSP.applyEcho(signalOut, fs, max(0.18, config.echoDelaySeconds), max(0.18, config.echoStrength));
                    description = "怪兽音预设：降调、低频增强并叠加轻微回声";
                case {"自定义 EQ", "鑷畾涔?EQ"}
                    signalOut = SignalSystemDSP.applyFiveBandEQ(signalIn, fs, config.eqGainsDb);
                    description = sprintf("自定义 5 段 EQ 已应用，增益 [%s] dB", strjoin(string(round(config.eqGainsDb, 1)), ", "));
                otherwise
                    signalOut = SignalSystemDSP.voicePitchShift(signalIn, config.pitchSemitone);
                    description = sprintf("自定义音高变换，音高 %.1f 半音", config.pitchSemitone);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = description;
            info.mode = modeName;
            info.config = config;
            info.metrics = SignalSystemDSP.evaluateProcessing(signalIn, signalOut, fs);
        end

        function [signalOut, cryptoInfo] = encryptSignal(signalIn, frameLength, seedValue)
            arguments
                signalIn (:, 1) double
                frameLength (1, 1) double {mustBePositive} = 1024
                seedValue (1, 1) double = 2026033
            end

            signalIn = SignalSystemDSP.prepareSignal(signalIn);
            frameLength = max(128, round(frameLength));
            originalLength = numel(signalIn);
            paddedLength = ceil(originalLength / frameLength) * frameLength;
            paddedSignal = [signalIn; zeros(paddedLength - originalLength, 1)];
            frames = reshape(paddedSignal, frameLength, []);

            rngState = rng;
            rng(round(seedValue), "twister");
            permutation = randperm(size(frames, 2));
            polarityMask = 2 * randi([0, 1], 1, size(frames, 2)) - 1;
            rng(rngState);

            encryptedFrames = frames(:, permutation) .* repmat(polarityMask, frameLength, 1);
            signalOut = encryptedFrames(:);

            cryptoInfo = struct();
            cryptoInfo.description = sprintf("语音加密完成，帧长 %d，种子 %.0f", frameLength, seedValue);
            cryptoInfo.frameLength = frameLength;
            cryptoInfo.seedValue = seedValue;
            cryptoInfo.originalLength = originalLength;
            cryptoInfo.permutation = permutation;
            cryptoInfo.polarityMask = polarityMask;
        end

        function [signalOut, info] = decryptSignal(signalIn, cryptoInfo)
            arguments
                signalIn (:, 1) double
                cryptoInfo (1, 1) struct
            end

            frameLength = cryptoInfo.frameLength;
            originalLength = cryptoInfo.originalLength;
            permutation = cryptoInfo.permutation;
            polarityMask = cryptoInfo.polarityMask;

            paddedLength = ceil(numel(signalIn) / frameLength) * frameLength;
            paddedSignal = [signalIn(:); zeros(paddedLength - numel(signalIn), 1)];
            encryptedFrames = reshape(paddedSignal, frameLength, []);

            restoredFrames = zeros(size(encryptedFrames));
            restoredFrames(:, permutation) = encryptedFrames .* repmat(polarityMask, frameLength, 1);
            signalOut = restoredFrames(:);
            signalOut = signalOut(1:min(originalLength, numel(signalOut)));

            info = struct();
            info.description = sprintf("语音解密完成，恢复 %d 个采样点", numel(signalOut));
            info.frameLength = frameLength;
            info.originalLength = originalLength;
        end

        function [chain, info] = runCommunicationChain(signalIn, fs, commConfig)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                commConfig (1, 1) struct
            end

            config = SignalSystemDSP.normalizeCommConfig(commConfig, fs);
            signalIn = SignalSystemDSP.prepareSignal(signalIn);

            chain = struct();
            chain.original = signalIn;
            info = struct();

            switch string(config.modulationType)
                case {"AM调幅", "FM调频"}
                    chain.encoded = signalIn;
                    if config.modulationType == "AM调幅"
                        [chain.modulated, modInfo] = SignalSystemDSP.modulateSignal(signalIn, fs, "AM调幅", config.carrierHz, config.modulationIndex);
                        chain.channel = SignalSystemDSP.applyChannelNoise(chain.modulated, config.channelSnrDb);
                        [chain.demodulated, demInfo] = SignalSystemDSP.demodulateSignal(chain.channel, fs, "AM调幅", config.carrierHz);
                    else
                        [chain.modulated, modInfo] = SignalSystemDSP.modulateSignal(signalIn, fs, "FM调频", config.carrierHz, config.frequencyDeviationHz);
                        chain.channel = SignalSystemDSP.applyChannelNoise(chain.modulated, config.channelSnrDb);
                        [chain.demodulated, demInfo] = SignalSystemDSP.demodulateSignal(chain.channel, fs, "FM调频", config.carrierHz, config.frequencyDeviationHz);
                    end
                    chain.decoded = chain.demodulated;
                    chain.restored = SignalSystemDSP.normalizeAudio(chain.demodulated);
                    info.bitErrorRate = NaN;
                    info.constellation = [];
                otherwise
                    sourceBits = SignalSystemDSP.resolveCommunicationBits(signalIn, config);
                    encodedBits = SignalSystemDSP.hamming74Encode(sourceBits);
                    symbolsPerBit = max(8, round(fs / max(config.symbolRate, 1)));
                    [modulatedSignal, txSymbols, mappingInfo] = SignalSystemDSP.modulateBitstream(encodedBits, fs, config, symbolsPerBit);
                    channelSignal = SignalSystemDSP.applyChannelNoise(modulatedSignal, config.channelSnrDb);
                    [decodedBits, rxSymbols, berValue] = SignalSystemDSP.demodulateBitstream(channelSignal, encodedBits, fs, config, symbolsPerBit, mappingInfo);
                    recoveredBits = SignalSystemDSP.hamming74Decode(decodedBits);
                    recoveredBits = recoveredBits(1:min(numel(recoveredBits), numel(sourceBits)));
                    restoredSignal = SignalSystemDSP.bitstreamToWaveform(recoveredBits, fs, config.symbolRate);
                    sourceWaveform = SignalSystemDSP.bitstreamToWaveform(sourceBits, fs, config.symbolRate);

                    chain.encoded = double(encodedBits(:));
                    chain.modulated = modulatedSignal(:);
                    chain.channel = channelSignal(:);
                    chain.demodulated = double(decodedBits(:));
                    chain.decoded = double(recoveredBits(:));
                    chain.restored = SignalSystemDSP.normalizeAudio(restoredSignal(:));
                    chain.original = SignalSystemDSP.normalizeAudio(sourceWaveform(:));
                    info.bitErrorRate = berValue;
                    info.constellation = struct("tx", txSymbols, "rx", rxSymbols);
                    info.sourceBits = logical(sourceBits(:));
                    info.encodedBits = logical(encodedBits(:));
                    info.recoveredBits = logical(recoveredBits(:));
                    modInfo = struct("description", sprintf("%s 数字调制完成", config.modulationType));
                    demInfo = struct("description", sprintf("%s 数字解调完成", config.modulationType));
            end

            info.modulationInfo = modInfo;
            info.demodulationInfo = demInfo;
            info.config = config;
            info.channelSnrDb = config.channelSnrDb;
            info.modulationType = config.modulationType;
            info.symbolRate = config.symbolRate;
            if ~isfield(info, "sourceBits")
                info.sourceBits = [];
            end
            if ~isfield(info, "recoveredBits")
                info.recoveredBits = [];
            end
            info.summary = sprintf("%s | Carrier %.0f Hz | SNR %.2f dB", config.modulationType, config.carrierHz, config.channelSnrDb);
            info.bitPreview = SignalSystemDSP.buildBitPreview(info);
            info.metrics = SignalSystemDSP.evaluateProcessing(signalIn(1:min(end, numel(chain.restored))), chain.restored(1:min(end, numel(signalIn))), fs);
        end

        function [signalOut, info] = modulateSignal(signalIn, fs, modulationType, carrierHz, modulationIndex)
            arguments
                signalIn (:, 1) double
                fs (1, 1) double {mustBePositive}
                modulationType (1, 1) string
                carrierHz (1, 1) double {mustBePositive}
                modulationIndex (1, 1) double {mustBePositive}
            end

            x = SignalSystemDSP.normalizeAudio(signalIn);
            t = (0:numel(x) - 1).' / fs;
            carrierHz = min(carrierHz, 0.42 * fs);

            switch modulationType
                case "AM调幅"
                    modulationIndex = min(modulationIndex, 0.95);
                    signalOut = (1 + modulationIndex * x) .* cos(2 * pi * carrierHz * t);
                    description = sprintf("AM 调幅，载波 %.0f Hz，调制度 %.2f", carrierHz, modulationIndex);
                case "DSB-SC"
                    modulationIndex = min(modulationIndex, 0.95);
                    signalOut = modulationIndex * x .* cos(2 * pi * carrierHz * t);
                    description = sprintf("DSB-SC 相干调制，载波 %.0f Hz", carrierHz);
                case "FM调频"
                    deviationHz = modulationIndex;
                    phase = 2 * pi * carrierHz * t + 2 * pi * deviationHz * cumsum(x) / fs;
                    signalOut = cos(phase);
                    description = sprintf("FM 调频，载波 %.0f Hz，频偏 %.0f Hz", carrierHz, deviationHz);
                otherwise
                    error("Unsupported modulation type: %s", modulationType);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = description;
            info.carrierHz = carrierHz;
            info.modulationIndex = modulationIndex;
        end

        function [signalOut, info] = demodulateSignal(signalIn, fs, modulationType, carrierHz, varargin)
            carrierHz = min(carrierHz, 0.42 * fs);
            t = (0:numel(signalIn) - 1).' / fs;

            switch modulationType
                case "AM调幅"
                    envelope = abs(hilbert(signalIn));
                    centeredEnvelope = envelope - mean(envelope, "omitnan");
                    cutoffHz = min(max(1500, 0.55 * carrierHz), 0.35 * fs);
                    [b, a] = butter(6, cutoffHz / (fs / 2), "low");
                    signalOut = filtfilt(b, a, centeredEnvelope);
                    description = sprintf("AM 解调，恢复低通截止频率 %.0f Hz", cutoffHz);
                case "DSB-SC"
                    mixedSignal = 2 * signalIn .* cos(2 * pi * carrierHz * t);
                    cutoffHz = min(max(1600, 0.5 * carrierHz), 0.35 * fs);
                    [b, a] = butter(6, cutoffHz / (fs / 2), "low");
                    signalOut = filtfilt(b, a, mixedSignal);
                    description = sprintf("DSB-SC 相干解调，恢复低通截止频率 %.0f Hz", cutoffHz);
                case "FM调频"
                    analyticSignal = hilbert(signalIn);
                    instPhase = unwrap(angle(analyticSignal));
                    instFreq = [0; diff(instPhase)] * fs / (2 * pi);
                    signalOut = instFreq - carrierHz;
                    signalOut = smoothdata(signalOut, "movmean", 9);
                    description = "FM 解调完成";
                otherwise
                    error("Unsupported modulation type: %s", modulationType);
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = description;
        end

        function [frequencyAxis, magnitudeDb] = magnitudeSpectrum(signal, fs)
            signal = signal(:);
            n = numel(signal);
            if n < 8
                frequencyAxis = linspace(0, fs / 2, 8).';
                magnitudeDb = -120 * ones(size(frequencyAxis));
                return;
            end

            nfft = 2 ^ nextpow2(max(n, 1024));
            window = hann(n, "periodic");
            spectrum = fft(signal .* window, nfft);
            positiveBins = 1:(nfft / 2 + 1);
            magnitude = abs(spectrum(positiveBins));
            magnitude = magnitude / max(magnitude + eps);
            frequencyAxis = linspace(0, fs / 2, numel(positiveBins)).';
            magnitudeDb = 20 * log10(magnitude + 1e-6);
        end

        function [frequencyAxis, magnitudeDb, phaseDeg] = filterResponse(filterType, fs, cutoffHz, order)
            config = SignalSystemDSP.normalizeFilterConfig(struct( ...
                "type", filterType, ...
                "cutoffHz", cutoffHz, ...
                "order", order), fs);
            [b, a, responseType] = SignalSystemDSP.designFilter(config, fs);
            nyquist = fs / 2;
            w = linspace(0, pi, 2048).';

            if responseType == "virtual"
                frequencyAxis = linspace(0, nyquist, 256).';
                magnitudeDb = -4 * (frequencyAxis / max(nyquist, eps));
                phaseDeg = zeros(size(frequencyAxis));
                return;
            end

            response = freqz(b, a, w);
            frequencyAxis = w / pi * nyquist;
            magnitudeDb = 20 * log10(abs(response) + 1e-6);
            phaseDeg = unwrap(angle(response)) * 180 / pi;
        end

        function [timeAxis, envelope] = signalEnvelope(signal, fs)
            signal = signal(:);
            timeAxis = (0:numel(signal) - 1).' / fs;
            envelope = abs(hilbert(signal));
        end

        function drawWaveform(ax, signal, fs, plotTitle, lineColor)
            arguments
                ax
                signal (:, 1) double
                fs (1, 1) double
                plotTitle (1, 1) string
                lineColor = [0.1, 0.45, 0.8]
            end

            timeAxis = (0:numel(signal) - 1) / fs;
            plot(ax, timeAxis, signal, "LineWidth", 1.15, "Color", lineColor);
            grid(ax, "on");
            xlabel(ax, "时间 / s");
            ylabel(ax, "幅值");
            title(ax, plotTitle);
        end

        function drawSpectrum(ax, signal, fs, plotTitle, lineColor)
            arguments
                ax
                signal (:, 1) double
                fs (1, 1) double
                plotTitle (1, 1) string
                lineColor = [0.85, 0.2, 0.2]
            end

            [frequencyAxis, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signal, fs);
            plot(ax, frequencyAxis, magnitudeDb, "LineWidth", 1.10, "Color", lineColor);
            grid(ax, "on");
            xlabel(ax, "频率 / Hz");
            ylabel(ax, "幅度 / dB");
            title(ax, plotTitle);
            xlim(ax, [0, min(fs / 2, 4000)]);
        end

        function drawConstellation(ax, constellationInfo, plotTitle)
            cla(ax);
            hold(ax, "on");
            if isstruct(constellationInfo)
                if isfield(constellationInfo, "tx") && ~isempty(constellationInfo.tx)
                    scatter(ax, real(constellationInfo.tx), imag(constellationInfo.tx), 28, ...
                        "MarkerEdgeColor", [0.10, 0.45, 0.72], ...
                        "MarkerFaceColor", [0.10, 0.45, 0.72], ...
                        "MarkerFaceAlpha", 0.18, ...
                        "MarkerEdgeAlpha", 0.45);
                end
                if isfield(constellationInfo, "rx") && ~isempty(constellationInfo.rx)
                    scatter(ax, real(constellationInfo.rx), imag(constellationInfo.rx), 18, ...
                        "MarkerEdgeColor", [0.82, 0.24, 0.24], ...
                        "MarkerFaceColor", [0.82, 0.24, 0.24], ...
                        "MarkerFaceAlpha", 0.28, ...
                        "MarkerEdgeAlpha", 0.55);
                end
            end
            hold(ax, "off");
            grid(ax, "on");
            axis(ax, "equal");
            xlabel(ax, "In-Phase");
            ylabel(ax, "Quadrature");
            title(ax, plotTitle);
            legend(ax, ["Tx", "Rx"], "Location", "best");
        end

        function drawSpectrogram(ax, signal, fs, plotTitle)
            signal = signal(:);
            windowLength = min(512, max(128, 2 ^ nextpow2(min(numel(signal), 256))));
            overlapLength = round(0.75 * windowLength);
            nfft = max(512, 2 ^ nextpow2(windowLength));
            [s, f, t] = spectrogram(signal, hann(windowLength, "periodic"), overlapLength, nfft, fs);
            powerDb = 20 * log10(abs(s) + 1e-6);

            imagesc(ax, t, f, powerDb);
            axis(ax, "xy");
            ylim(ax, [0, min(fs / 2, 4000)]);
            xlabel(ax, "时间 / s");
            ylabel(ax, "频率 / Hz");
            title(ax, plotTitle);
            colormap(ax, turbo);
            colorbar(ax);
        end

        function drawFilterResponse(axMag, axPhase, filterType, fs, cutoffHz, order)
            [frequencyAxis, magnitudeDb, phaseDeg] = SignalSystemDSP.filterResponse(filterType, fs, cutoffHz, order);

            plot(axMag, frequencyAxis, magnitudeDb, "LineWidth", 1.2, "Color", [0.08, 0.45, 0.72]);
            grid(axMag, "on");
            xlabel(axMag, "频率 / Hz");
            ylabel(axMag, "幅度 / dB");
            title(axMag, filterType + " 幅频响应");
            xlim(axMag, [0, min(fs / 2, 4000)]);

            plot(axPhase, frequencyAxis, phaseDeg, "LineWidth", 1.2, "Color", [0.74, 0.18, 0.24]);
            grid(axPhase, "on");
            xlabel(axPhase, "频率 / Hz");
            ylabel(axPhase, "相位 / deg");
            title(axPhase, filterType + " 相频响应");
            xlim(axPhase, [0, min(fs / 2, 4000)]);
        end

        function exportFrameworkDiagram(outputPath)
            fig = figure("Visible", "off", "Color", "w", "Position", [90, 90, 1480, 820]);
            ax = axes(fig, "Position", [0, 0, 1, 1]);
            axis(ax, [0, 1, 0, 1]);
            axis(ax, "off");

            modulePos = [
                0.04, 0.66, 0.14, 0.14;
                0.20, 0.66, 0.14, 0.14;
                0.36, 0.66, 0.14, 0.14;
                0.52, 0.66, 0.14, 0.14;
                0.68, 0.66, 0.14, 0.14;
                0.84, 0.66, 0.12, 0.14;
                0.20, 0.36, 0.18, 0.13;
                0.41, 0.36, 0.18, 0.13;
                0.62, 0.36, 0.18, 0.13
            ];

            titles = {
                "信号采集";
                "实时分析";
                "噪声处理";
                "变声与增强";
                "调制通信";
                "报告导出";
                "智能推荐";
                "量化评价";
                "A/B 对比"
            };

            subtitles = {
                "样例、本地音频、录音、监听";
                "波形、FFT、瀑布图、分帧指标";
                "加噪、低通、高通、陷波、中值";
                "男声/女声、机器人、电话音、EQ";
                "AM/FM/ASK/FSK/BPSK/QPSK";
                "波形图、频谱图、CSV、截图";
                "自动识别噪声类型并给参";
                "SNR、MSE、RMSE、频带变化";
                "试听、叠加波形、差分频谱"
            };

            faceColors = [
                0.88, 0.95, 1.00;
                0.91, 0.98, 0.98;
                1.00, 0.93, 0.87;
                0.98, 0.92, 0.95;
                0.92, 0.93, 1.00;
                0.95, 0.95, 0.95;
                0.98, 0.97, 0.90;
                0.89, 0.97, 0.91;
                0.94, 0.95, 1.00
            ];

            for idx = 1:size(modulePos, 1)
                annotation(fig, "textbox", modulePos(idx, :), ...
                    "String", sprintf("%s\n%s", titles{idx}, subtitles{idx}), ...
                    "HorizontalAlignment", "center", ...
                    "VerticalAlignment", "middle", ...
                    "FitBoxToText", "off", ...
                    "LineWidth", 1.3, ...
                    "Color", [0.22, 0.22, 0.22], ...
                    "BackgroundColor", faceColors(idx, :), ...
                    "FontSize", 12, ...
                    "FontName", "Microsoft YaHei");
            end

            for idx = 1:5
                startX = modulePos(idx, 1) + modulePos(idx, 3);
                endX = modulePos(idx + 1, 1);
                midY = modulePos(idx, 2) + 0.07;
                annotation(fig, "arrow", [startX, endX], [midY, midY], "LineWidth", 1.5, "Color", [0.25, 0.25, 0.25]);
            end

            annotation(fig, "arrow", [0.42, 0.29], [0.66, 0.49], "LineWidth", 1.4, "Color", [0.25, 0.25, 0.25]);
            annotation(fig, "arrow", [0.58, 0.50], [0.66, 0.49], "LineWidth", 1.4, "Color", [0.25, 0.25, 0.25]);
            annotation(fig, "arrow", [0.74, 0.71], [0.66, 0.49], "LineWidth", 1.4, "Color", [0.25, 0.25, 0.25]);

            annotation(fig, "textbox", [0.22, 0.85, 0.56, 0.08], ...
                "String", "信号与系统课程大作业 APP 总体架构 v3", ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", ...
                "LineStyle", "none", ...
                "FontSize", 22, ...
                "FontWeight", "bold", ...
                "Color", [0.10, 0.18, 0.33], ...
                "FontName", "Microsoft YaHei");

            exportgraphics(fig, outputPath, "Resolution", 220);
            close(fig);
        end

        function exportReportMaterials(exportContext)
            arguments
                exportContext (1, 1) struct
            end

            outputRoot = string(exportContext.outputRoot);
            if strlength(outputRoot) == 0
                outputRoot = string(fullfile(pwd, "outputs"));
            end
            if ~exist(outputRoot, "dir")
                mkdir(outputRoot);
            end

            bundleName = "report_bundle_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
            bundleDir = fullfile(outputRoot, bundleName);
            if ~exist(bundleDir, "dir")
                mkdir(bundleDir);
            end

            signals = exportContext.signals;
            fs = exportContext.fs;
            stageOrder = string(fieldnames(signals));
            stageLabels = exportContext.stageLabels;

            for idx = 1:numel(stageOrder)
                stageKey = stageOrder(idx);
                signalValue = signals.(char(stageKey));
                stageTitle = SignalSystemDSP.resolveStageTitle(stageLabels, stageKey);
                stagePrefix = lower(char(stageKey));

                fig = figure("Visible", "off", "Color", "w", "Position", [80, 80, 1220, 860]);
                layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
                ax = nexttile(layout);
                SignalSystemDSP.drawWaveform(ax, signalValue, fs, stageTitle + " 波形");
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrum(ax, signalValue, fs, stageTitle + " 频谱");
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrogram(ax, signalValue, fs, stageTitle + " 时频图");
                ax = nexttile(layout);
                metrics = SignalSystemDSP.computeMetrics(signalValue, fs);
                text(ax, 0.05, 0.80, sprintf("RMS: %.4f", metrics.rmsValue), "FontSize", 13);
                text(ax, 0.05, 0.62, sprintf("Peak: %.4f", metrics.peakValue), "FontSize", 13);
                text(ax, 0.05, 0.44, sprintf("Dominant: %.1f Hz", metrics.dominantFrequencyHz), "FontSize", 13);
                axis(ax, "off");
                exportgraphics(fig, fullfile(bundleDir, stagePrefix + "_overview.png"), "Resolution", 220);
                close(fig);
                audiowrite(fullfile(bundleDir, stagePrefix + ".wav"), signalValue, fs);
            end

            if isfield(exportContext, "stageMeta")
                stageMeta = exportContext.stageMeta;
            else
                stageMeta = struct();
            end

            stageMetricKeys = string(fieldnames(stageMeta));
            summaryRows = cell(0, 6);
            for idx = 1:numel(stageMetricKeys)
                stageKey = stageMetricKeys(idx);
                stageInfo = stageMeta.(char(stageKey));
                if ~isstruct(stageInfo) || ~isfield(stageInfo, "metrics") || isempty(fieldnames(stageInfo.metrics))
                    continue;
                end
                metrics = stageInfo.metrics;
                moduleName = "";
                if isfield(stageInfo, "module")
                    moduleName = string(stageInfo.module);
                end

                switch char(stageKey)
                    case "filtered"
                        metricFileName = "filtered_result_metrics.csv";
                    case "enhanced"
                        metricFileName = "denoise_metrics.csv";
                    case "effect"
                        metricFileName = "voice_change_metrics.csv";
                    otherwise
                        metricFileName = lower(char(stageKey)) + "_metrics.csv";
                end
                SignalSystemDSP.exportMetricsCsv(bundleDir, metricFileName, metrics, stageKey, moduleName);

                stageLabel = SignalSystemDSP.resolveStageTitle(stageLabels, stageKey);
                summaryRows(end + 1, :) = { ...
                    char(stageLabel), ...
                    char(string(metrics.snrType)), ...
                    metrics.snrBeforeDb, ...
                    metrics.snrAfterDb, ...
                    metrics.snrImprovementDb, ...
                    char(string(metrics.evaluationText))}; %#ok<AGROW>
            end

            if ~isempty(summaryRows)
                metricsFig = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1320, 780]);
                uitable(metricsFig, ...
                    "Data", summaryRows, ...
                    "ColumnName", {"阶段", "SNR类型", "处理前SNR(dB)", "处理后SNR(dB)", "提升(dB)", "评价"}, ...
                    "Position", [30, 240, 1260, 500], ...
                    "ColumnWidth", {120, 90, 120, 120, 90, 680});
                annotation(metricsFig, "textbox", [0.03, 0.05, 0.94, 0.14], ...
                    "String", "指标导出总览：包含 SNR、误差、总能量、频带能量占比、主频变化、频谱峰值变化与简短评价。", ...
                    "LineStyle", "none", ...
                    "FontSize", 13, ...
                    "FontName", "Microsoft YaHei");
                exportgraphics(metricsFig, fullfile(bundleDir, "metrics_summary.png"), "Resolution", 220);
                close(metricsFig);
            end

            if isfield(exportContext, "referenceSignal") && isfield(exportContext, "processedSignal")
                if isfield(exportContext, "cleanReferenceSignal")
                    cleanReferenceSignal = exportContext.cleanReferenceSignal;
                else
                    cleanReferenceSignal = [];
                end
                metrics = SignalSystemDSP.evaluateProcessing(exportContext.referenceSignal, exportContext.processedSignal, fs, cleanReferenceSignal);
                SignalSystemDSP.exportMetricsCsv(bundleDir, "filtered_result_metrics.csv", metrics, "filtered", "filter");
            end

            if isfield(exportContext, "voiceBefore") && isfield(exportContext, "voiceAfter")
                fig = figure("Visible", "off", "Color", "w", "Position", [90, 90, 1280, 840]);
                layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
                ax = nexttile(layout);
                SignalSystemDSP.drawWaveform(ax, exportContext.voiceBefore, fs, "原始语音波形");
                ax = nexttile(layout);
                SignalSystemDSP.drawWaveform(ax, exportContext.voiceAfter, fs, "变声后波形", [0.71, 0.22, 0.55]);
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrum(ax, exportContext.voiceBefore, fs, "原始语音频谱");
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrum(ax, exportContext.voiceAfter, fs, "变声后频谱", [0.18, 0.57, 0.72]);
                exportgraphics(fig, fullfile(bundleDir, "voice_change_comparison.png"), "Resolution", 220);
                close(fig);
            end

            if isfield(exportContext, "commChain")
                chain = exportContext.commChain;
                fig = figure("Visible", "off", "Color", "w", "Position", [90, 90, 1280, 860]);
                layout = tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");
                ax = nexttile(layout);
                SignalSystemDSP.drawWaveform(ax, chain.modulated, fs, "调制结果波形");
                ax = nexttile(layout);
                SignalSystemDSP.drawWaveform(ax, chain.restored, fs, "恢复信号波形", [0.18, 0.55, 0.32]);
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrum(ax, chain.modulated, fs, "调制结果频谱");
                ax = nexttile(layout);
                SignalSystemDSP.drawSpectrum(ax, chain.restored, fs, "恢复信号频谱", [0.72, 0.18, 0.25]);
                exportgraphics(fig, fullfile(bundleDir, "modulation_demodulation_result.png"), "Resolution", 220);
                close(fig);

                if isfield(exportContext, "commInfo") && isfield(exportContext.commInfo, "constellation") && ~isempty(exportContext.commInfo.constellation)
                    fig = figure("Visible", "off", "Color", "w", "Position", [120, 120, 920, 440]);
                    subplot(1, 2, 1);
                    plot(real(exportContext.commInfo.constellation.tx), imag(exportContext.commInfo.constellation.tx), ".");
                    grid on; title("发送星座");
                    subplot(1, 2, 2);
                    plot(real(exportContext.commInfo.constellation.rx), imag(exportContext.commInfo.constellation.rx), ".");
                    grid on; title("接收星座");
                    exportgraphics(fig, fullfile(bundleDir, "communication_constellation.png"), "Resolution", 220);
                    close(fig);
                end
            end

            if isfield(exportContext, "appFigure") && ~isempty(exportContext.appFigure) && isvalid(exportContext.appFigure)
                exportapp(exportContext.appFigure, fullfile(bundleDir, "current_dashboard.png"));
            end
        end
    end

    methods (Static, Access = private)
        function config = normalizeFilterConfig(configIn, fs)
            nyquist = fs / 2;
            config = struct();
            config.type = "Butterworth低通";
            config.cutoffHz = min(2200, 0.18 * fs);
            config.order = 6;
            config.lowCutoffHz = 300;
            config.highCutoffHz = min(3400, 0.42 * fs);
            config.stopbandHz = min(4200, 0.46 * fs);
            config.notchHz = 50;
            config.family = "Butterworth";
            config.windowSize = 7;

            fields = string(fieldnames(configIn));
            for idx = 1:numel(fields)
                config.(char(fields(idx))) = configIn.(char(fields(idx)));
            end

            config.type = string(config.type);
            config.cutoffHz = min(max(double(config.cutoffHz), 40), 0.92 * nyquist);
            config.order = max(2, round(double(config.order)));
            config.lowCutoffHz = min(max(double(config.lowCutoffHz), 40), 0.60 * nyquist);
            config.highCutoffHz = min(max(double(config.highCutoffHz), config.lowCutoffHz + 50), 0.92 * nyquist);
            config.stopbandHz = min(max(double(config.stopbandHz), config.highCutoffHz + 50), 0.95 * nyquist);
            config.notchHz = min(max(double(config.notchHz), 45), 1000);
            config.windowSize = max(3, 2 * floor(double(config.windowSize) / 2) + 1);
        end

        function [signalOut, info] = applyFilterConfig(signalIn, fs, config)
            [b, a, responseType, auxInfo] = SignalSystemDSP.designFilter(config, fs);
            signalIn = signalIn(:);

            switch responseType
                case "iir"
                    signalOut = filtfilt(b, a, signalIn);
                case "fir"
                    signalOut = filtfilt(b, 1, signalIn);
                case "median"
                    signalOut = medfilt1(signalIn, config.windowSize, "truncate");
                case "wavelet"
                    [signalOut, auxEnhance] = SignalSystemDSP.applyAdvancedEnhancement(signalIn, fs, "小波去噪", 0.60);
                    auxInfo.description = auxEnhance.description;
                otherwise
                    signalOut = signalIn;
            end

            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
            info = struct();
            info.description = auxInfo.description;
            info.config = config;
            info.metrics = SignalSystemDSP.evaluateProcessing(signalIn, signalOut, fs);
        end

        function [b, a, responseType, auxInfo] = designFilter(config, fs)
            nyquist = fs / 2;
            responseType = "iir";
            auxInfo = struct("description", "");

            switch string(config.type)
                case {"Butterworth低通", "Butterworth"}
                    [b, a] = butter(config.order, config.cutoffHz / nyquist, "low");
                    auxInfo.description = sprintf("Butterworth 低通，截止频率 %.0f Hz，阶数 %d", config.cutoffHz, config.order);
                case {"Chebyshev高通", "Chebyshev I高通"}
                    [b, a] = cheby1(config.order, 0.8, config.cutoffHz / nyquist, "high");
                    auxInfo.description = sprintf("Chebyshev I 高通，截止频率 %.0f Hz，阶数 %d", config.cutoffHz, config.order);
                case {"语音带通", "Bandpass"}
                    [b, a] = butter(config.order, [config.lowCutoffHz, config.highCutoffHz] / nyquist, "bandpass");
                    auxInfo.description = sprintf("语音带通，通带 %.0f-%.0f Hz，阶数 %d", config.lowCutoffHz, config.highCutoffHz, config.order);
                case {"FIR低通", "FIR"}
                    b = fir1(max(12, 8 * config.order), config.cutoffHz / nyquist, "low", hann(max(13, 8 * config.order + 1)));
                    a = 1;
                    responseType = "fir";
                    auxInfo.description = sprintf("FIR 低通，截止频率 %.0f Hz，阶数 %d", config.cutoffHz, max(12, 8 * config.order));
                case {"50Hz陷波", "陷波", "Notch"}
                    notchHz = config.cutoffHz;
                    wo = min(max(notchHz / nyquist, 0.001), 0.95);
                    bw = max(wo / 35, 0.001);
                    [b, a] = iirnotch(wo, bw);
                    auxInfo.description = sprintf("陷波滤波，中心频率 %.1f Hz", notchHz);
                case {"Median", "中值滤波"}
                    b = [];
                    a = [];
                    responseType = "median";
                    auxInfo.description = sprintf("中值滤波，窗口长度 %d", config.windowSize);
                case {"小波去噪"}
                    b = [];
                    a = [];
                    responseType = "wavelet";
                    auxInfo.description = "小波去噪滤波";
                otherwise
                    [b, a] = butter(config.order, config.cutoffHz / nyquist, "low");
                    auxInfo.description = sprintf("默认低通滤波，截止频率 %.0f Hz，阶数 %d", config.cutoffHz, config.order);
            end
        end

        function score = computeQualityScore(comparison)
            if any(isnan([comparison.snrDb, comparison.correlation, comparison.rmse]))
                score = 0;
                return;
            end
            snrTerm = min(max(comparison.snrDb / 30, 0), 1);
            corrTerm = min(max((comparison.correlation + 1) / 2, 0), 1);
            rmseTerm = min(max(1 - comparison.rmse / 0.65, 0), 1);
            score = round(100 * (0.42 * snrTerm + 0.38 * corrTerm + 0.20 * rmseTerm));
        end

        function metrics = createEmptyProcessingMetrics()
            zeroBand = struct("low", 0, "speech", 0, "high", 0);
            metrics = struct( ...
                "snrDb", NaN, ...
                "snrType", "estimated", ...
                "snrBeforeDb", NaN, ...
                "snrAfterDb", NaN, ...
                "snrImprovementDb", NaN, ...
                "mse", NaN, ...
                "rmse", NaN, ...
                "correlation", NaN, ...
                "qualityScore", NaN, ...
                "beforeDominantFrequencyHz", NaN, ...
                "afterDominantFrequencyHz", NaN, ...
                "dominantFrequencyDeltaHz", NaN, ...
                "beforeSpectrumPeakDb", NaN, ...
                "afterSpectrumPeakDb", NaN, ...
                "spectrumPeakDeltaDb", NaN, ...
                "beforeTotalEnergy", NaN, ...
                "afterTotalEnergy", NaN, ...
                "energyDelta", NaN, ...
                "bandEnergyBefore", zeroBand, ...
                "bandEnergyAfter", zeroBand, ...
                "bandEnergyDelta", zeroBand, ...
                "bandEnergyRatioBefore", zeroBand, ...
                "bandEnergyRatioAfter", zeroBand, ...
                "bandEnergyRatioDelta", zeroBand, ...
                "denoiseImprovementDb", NaN, ...
                "hasCleanReference", false, ...
                "evaluationText", "", ...
                "summaryText", "");
        end

        function [referenceSignal, testSignal, info] = alignSignals(referenceSignal, testSignal, referenceFs, testFs)
            if nargin < 3
                referenceFs = [];
            end
            if nargin < 4
                testFs = referenceFs;
            end

            referenceSignal = referenceSignal(:);
            testSignal = testSignal(:);
            info = struct("resampled", false, "referenceFs", referenceFs, "testFs", testFs);

            if isempty(referenceSignal) || isempty(testSignal)
                referenceSignal = zeros(0, 1);
                testSignal = zeros(0, 1);
                return;
            end

            if ~isempty(referenceFs) && ~isempty(testFs) && isfinite(referenceFs) && isfinite(testFs) ...
                    && referenceFs > 0 && testFs > 0 && abs(referenceFs - testFs) > 1e-6
                testSignal = SignalSystemDSP.resampleLinear(testSignal, testFs, referenceFs);
                info.resampled = true;
            end

            compareLength = min(numel(referenceSignal), numel(testSignal));
            referenceSignal = referenceSignal(1:compareLength);
            testSignal = testSignal(1:compareLength);
        end

        function signalOut = resampleLinear(signalIn, sourceFs, targetFs)
            signalIn = signalIn(:);
            if isempty(signalIn) || ~isfinite(sourceFs) || ~isfinite(targetFs) || sourceFs <= 0 || targetFs <= 0
                signalOut = signalIn;
                return;
            end
            sourceTime = (0:numel(signalIn) - 1).' / sourceFs;
            targetLength = max(1, round(numel(signalIn) * targetFs / sourceFs));
            targetTime = (0:targetLength - 1).' / targetFs;
            signalOut = interp1(sourceTime, signalIn, targetTime, "linear", 0);
            signalOut = signalOut(:);
        end

        function snrDb = estimateNoReferenceSNR(signal, fs)
            signal = signal(:) - mean(signal, "omitnan");
            if isempty(signal)
                snrDb = NaN;
                return;
            end

            signalPower = mean(signal .^ 2, "omitnan") + eps;
            frameLength = min(numel(signal), max(128, round(0.02 * fs)));
            if frameLength < 16
                noisePower = 0.25 * signalPower;
                snrDb = 10 * log10(max(signalPower - noisePower, eps) / max(noisePower, eps));
                return;
            end

            hopLength = max(16, round(frameLength / 2));
            frameCount = max(1, floor((numel(signal) - frameLength) / hopLength) + 1);
            frameEnergies = zeros(frameCount, 1);
            for idx = 1:frameCount
                startIdx = (idx - 1) * hopLength + 1;
                stopIdx = min(numel(signal), startIdx + frameLength - 1);
                frame = signal(startIdx:stopIdx);
                if numel(frame) < frameLength
                    frame(end + 1:frameLength, 1) = 0;
                end
                frameEnergies(idx) = mean(frame .^ 2, "omitnan");
            end

            sortedEnergy = sort(frameEnergies, "ascend");
            takeCount = max(1, round(0.2 * numel(sortedEnergy)));
            noisePower = mean(sortedEnergy(1:takeCount), "omitnan");
            noisePower = min(max(noisePower, eps), 0.98 * signalPower);
            snrDb = 10 * log10(max(signalPower - noisePower, eps) / noisePower);
        end

        function bandProfile = computeReportBandProfile(signal, fs)
            signal = signal(:);
            energy = [0, 0, 0];
            if ~isempty(signal)
                nfft = 2 ^ nextpow2(max(numel(signal), 1024));
                window = hann(numel(signal), "periodic");
                spectrum = fft(signal .* window, nfft);
                positiveSpectrum = spectrum(1:(nfft / 2 + 1));
                powerSpectrum = abs(positiveSpectrum) .^ 2;
                frequencyAxis = linspace(0, fs / 2, numel(positiveSpectrum)).';
                masks = { ...
                    frequencyAxis >= 0 & frequencyAxis < 300, ...
                    frequencyAxis >= 300 & frequencyAxis < min(3400, fs / 2), ...
                    frequencyAxis >= min(3400, fs / 2) & frequencyAxis <= fs / 2};
                for idx = 1:3
                    if any(masks{idx})
                        energy(idx) = sum(powerSpectrum(masks{idx}), "omitnan");
                    end
                end
            end

            totalEnergy = sum(energy, "omitnan");
            if totalEnergy <= eps
                ratio = [0, 0, 0];
            else
                ratio = energy / totalEnergy;
            end

            bandProfile = struct();
            bandProfile.absolute = struct("low", energy(1), "speech", energy(2), "high", energy(3));
            bandProfile.ratio = struct("low", ratio(1), "speech", ratio(2), "high", ratio(3));
            bandProfile.total = totalEnergy;
        end

        function peakDb = findSpectrumPeakDb(signal, fs)
            signal = signal(:);
            if isempty(signal)
                peakDb = NaN;
                return;
            end

            nfft = 2 ^ nextpow2(max(numel(signal), 1024));
            window = hann(numel(signal), "periodic");
            spectrum = fft(signal .* window, nfft);
            positiveMagnitude = abs(spectrum(1:(nfft / 2 + 1))) / max(sum(window), eps);
            peakDb = 20 * log10(max(positiveMagnitude, [], "omitnan") + 1e-9);
        end

        function summaryText = summarizeProcessingMetrics(metrics)
            summaryLines = strings(0, 1);

            if ~isnan(metrics.snrImprovementDb)
                if metrics.snrImprovementDb >= 1.5
                    summaryLines(end + 1, 1) = sprintf("信噪比提升 %.2f dB", metrics.snrImprovementDb); %#ok<AGROW>
                elseif metrics.snrImprovementDb <= -1.0
                    summaryLines(end + 1, 1) = sprintf("信噪比下降 %.2f dB，处理失真偏大", abs(metrics.snrImprovementDb)); %#ok<AGROW>
                else
                    summaryLines(end + 1, 1) = "信噪比变化较小"; %#ok<AGROW>
                end
            else
                summaryLines(end + 1, 1) = "缺少参考信号，显示无参考估计值"; %#ok<AGROW>
            end

            if metrics.bandEnergyRatioDelta.high <= -0.05
                summaryLines(end + 1, 1) = "高频噪声明显降低"; %#ok<AGROW>
            end
            if abs(metrics.bandEnergyRatioDelta.speech) <= 0.08
                summaryLines(end + 1, 1) = "语音频段能量保持较好"; %#ok<AGROW>
            elseif metrics.bandEnergyRatioDelta.speech < -0.08
                summaryLines(end + 1, 1) = "语音主频段被削弱"; %#ok<AGROW>
            else
                summaryLines(end + 1, 1) = "语音主频段能量上升"; %#ok<AGROW>
            end

            if ~isnan(metrics.energyDelta) && metrics.beforeTotalEnergy > eps
                if metrics.energyDelta <= -0.15 * metrics.beforeTotalEnergy
                    summaryLines(end + 1, 1) = "整体能量衰减较明显"; %#ok<AGROW>
                elseif metrics.energyDelta >= 0.15 * metrics.beforeTotalEnergy
                    summaryLines(end + 1, 1) = "整体能量有所增强"; %#ok<AGROW>
                end
            end

            if ~isnan(metrics.dominantFrequencyDeltaHz) && abs(metrics.dominantFrequencyDeltaHz) >= 80
                summaryLines(end + 1, 1) = sprintf("主频偏移 %.1f Hz", metrics.dominantFrequencyDeltaHz); %#ok<AGROW>
            end

            if ~isnan(metrics.spectrumPeakDeltaDb) && metrics.spectrumPeakDeltaDb <= -3
                summaryLines(end + 1, 1) = "频谱峰值下降，尖锐峰受到抑制"; %#ok<AGROW>
            elseif ~isnan(metrics.spectrumPeakDeltaDb) && metrics.spectrumPeakDeltaDb >= 3
                summaryLines(end + 1, 1) = "频谱峰值抬升，增强效果明显"; %#ok<AGROW>
            end

            if isempty(summaryLines)
                summaryText = "处理完成，指标变化平稳。";
            else
                summaryText = strjoin(summaryLines, "；");
            end
        end

        function bandEnergy = computeBandEnergies(signal, fs, bandEdges)
            bandEdges = bandEdges(:).';
            if bandEdges(end) > fs / 2
                bandEdges(end) = fs / 2;
            end
            [f, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signal, fs);
            magnitudeLin = 10 .^ (magnitudeDb / 20);
            energy = zeros(1, max(1, numel(bandEdges) - 1));
            for idx = 1:(numel(bandEdges) - 1)
                mask = f >= bandEdges(idx) & f < bandEdges(idx + 1);
                energy(idx) = mean(magnitudeLin(mask), "omitnan");
                if isnan(energy(idx))
                    energy(idx) = 0;
                end
            end
            if numel(energy) < 4
                energy(end + 1:4) = 0;
            end
            bandEnergy = struct("low", energy(1), "mid", energy(2), "high", energy(3), "ultra", energy(4));
        end

        function centroidHz = spectralCentroid(signal, fs)
            [f, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signal, fs);
            magnitudeLin = 10 .^ (magnitudeDb / 20);
            centroidHz = sum(f .* magnitudeLin) / max(sum(magnitudeLin), eps);
        end

        function [humHz, humScore] = detectHumFrequency(signal, fs)
            [hum50Hz, hum50Score] = SignalSystemDSP.detectHumAt(signal, fs, 50);
            [hum60Hz, hum60Score] = SignalSystemDSP.detectHumAt(signal, fs, 60);
            if hum50Score >= hum60Score
                humHz = hum50Hz;
                humScore = hum50Score;
            else
                humHz = hum60Hz;
                humScore = hum60Score;
            end
        end

        function [humHz, humScore] = detectHumAt(signal, fs, centerHz)
            [frequencyAxis, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signal, fs);
            humMask = frequencyAxis >= centerHz - 4 & frequencyAxis <= centerHz + 4;
            if ~any(humMask)
                humHz = centerHz;
                humScore = 0;
                return;
            end
            humAxis = frequencyAxis(humMask);
            humMag = magnitudeDb(humMask);
            [peakValue, peakIndex] = max(humMag);
            humHz = humAxis(peakIndex);
            backgroundMask = frequencyAxis >= max(10, centerHz - 40) & frequencyAxis <= centerHz + 40 & ~humMask;
            humScore = peakValue - median(magnitudeDb(backgroundMask), "omitnan");
            if isnan(humScore)
                humScore = 0;
            end
        end

        function config = normalizeVoiceConfig(configIn)
            config = struct( ...
                "mode", "原声", ...
                "pitchSemitone", 0, ...
                "speedFactor", 1.0, ...
                "echoDelaySeconds", 0.18, ...
                "echoStrength", 0.45, ...
                "modFrequencyHz", 85, ...
                "modDepth", 0.9, ...
                "eqGainsDb", [0, 0, 0, 0, 0]);
            fields = fieldnames(configIn);
            for idx = 1:numel(fields)
                config.(fields{idx}) = configIn.(fields{idx});
            end
            config.pitchSemitone = min(max(config.pitchSemitone, -12), 12);
            config.speedFactor = min(max(config.speedFactor, 0.5), 2.0);
            config.echoDelaySeconds = min(max(config.echoDelaySeconds, 0.1), 0.8);
            config.echoStrength = min(max(config.echoStrength, 0), 0.9);
            config.modFrequencyHz = min(max(config.modFrequencyHz, 20), 100);
            config.modDepth = min(max(config.modDepth, 0), 1);
            gains = config.eqGainsDb(:).';
            if numel(gains) < 5
                gains(end + 1:5) = 0;
            elseif numel(gains) > 5
                gains = gains(1:5);
            end
            config.eqGainsDb = gains;
        end

        function signalOut = pitchShiftTimePreserving(signalIn, semitone, speedFactor)
            signalIn = signalIn(:);
            factor = 2 .^ (semitone / 12);
            try
                warped = SignalSystemDSP.pitchWarp(signalIn, factor);
                targetLength = max(8, round(numel(signalIn) / speedFactor));
                readIndex = linspace(1, numel(warped), targetLength).';
                tempSignal = interp1((1:numel(warped)).', warped, readIndex, "linear", "extrap");
                restoreIndex = linspace(1, numel(tempSignal), numel(signalIn)).';
                signalOut = interp1((1:numel(tempSignal)).', tempSignal, restoreIndex, "linear", "extrap");
            catch
                signalOut = SignalSystemDSP.pitchWarp(signalIn, factor);
            end
            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
        end

        function signalOut = pitchWarp(signalIn, factor)
            signalIn = signalIn(:);
            sampleCount = numel(signalIn);
            if sampleCount < 16
                signalOut = signalIn;
                return;
            end

            warpedLength = max(8, round(sampleCount / max(factor, 0.25)));
            readIndex = linspace(1, sampleCount, warpedLength).';
            warped = interp1((1:sampleCount).', signalIn, readIndex, "linear", "extrap");
            restoreIndex = linspace(1, numel(warped), sampleCount).';
            signalOut = interp1((1:numel(warped)).', warped, restoreIndex, "linear", "extrap");
            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
        end

        function signalOut = applyEcho(signalIn, fs, delaySeconds, alpha)
            delaySamples = max(1, round(delaySeconds * fs));
            echoSignal = [zeros(delaySamples, 1); signalIn(1:max(1, end - delaySamples))];
            if numel(echoSignal) > numel(signalIn)
                echoSignal = echoSignal(1:numel(signalIn));
            end
            signalOut = signalIn + alpha * echoSignal;
        end

        function signalOut = applyBandPassVoice(signalIn, fs, lowHz, highHz)
            highHz = min(highHz, 0.92 * fs / 2);
            [b, a] = butter(4, [lowHz, highHz] / (fs / 2), "bandpass");
            signalOut = filtfilt(b, a, signalIn);
        end

        function signalOut = applyLowShelf(signalIn, fs, cutoffHz, gainDb)
            lowBand = lowpass(signalIn, cutoffHz, fs, "ImpulseResponse", "iir");
            signalOut = signalIn + (10 ^ (gainDb / 20) - 1) * lowBand;
        end

        function signalOut = applyGraphicEQ(signalIn, fs, gainsDb)
            centerFreqs = [60, 250, 1000, 4000, 8000];
            signalOut = zeros(size(signalIn));
            signalOut = signalOut + bandpass(signalIn, [20, 120], fs) * 10 ^ (gainsDb(1) / 20);
            signalOut = signalOut + bandpass(signalIn, [120, 500], fs) * 10 ^ (gainsDb(2) / 20);
            signalOut = signalOut + bandpass(signalIn, [500, 1800], fs) * 10 ^ (gainsDb(3) / 20);
            signalOut = signalOut + bandpass(signalIn, [1800, min(6000, fs / 2 - 100)], fs) * 10 ^ (gainsDb(4) / 20);
            signalOut = signalOut + highpass(signalIn, min(centerFreqs(5), fs / 4), fs) * 10 ^ (gainsDb(5) / 20);
            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
        end

        function signalOut = applyFiveBandEQ(signalIn, fs, gainsDb)
            edge1 = min(120, 0.18 * fs);
            edge2 = min(500, 0.32 * fs);
            edge3 = min(2000, 0.40 * fs);
            edge4 = min(5650, 0.46 * fs);
            signalOut = lowpass(signalIn, edge1, fs, "ImpulseResponse", "iir") * 10 ^ (gainsDb(1) / 20);
            signalOut = signalOut + bandpass(signalIn, [edge1, edge2], fs) * 10 ^ (gainsDb(2) / 20);
            signalOut = signalOut + bandpass(signalIn, [edge2, edge3], fs) * 10 ^ (gainsDb(3) / 20);
            signalOut = signalOut + bandpass(signalIn, [edge3, edge4], fs) * 10 ^ (gainsDb(4) / 20);
            signalOut = signalOut + highpass(signalIn, edge4, fs, "ImpulseResponse", "iir") * 10 ^ (gainsDb(5) / 20);
            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
        end

        function signalOut = voicePitchShift(signalIn, semitone)
            signalIn = signalIn(:);
            if abs(semitone) < 0.05
                signalOut = signalIn;
                return;
            end

            factor = 2 .^ (semitone / 12);
            stretchedSignal = SignalSystemDSP.voiceTimeScaleOLA(signalIn, factor);
            signalOut = SignalSystemDSP.voiceResampleLinear(stretchedSignal, numel(signalIn));
            signalOut = SignalSystemDSP.normalizeAudio(signalOut);
        end

        function signalOut = voiceTimeScaleOLA(signalIn, scaleFactor)
            signalIn = signalIn(:);
            scaleFactor = min(max(scaleFactor, 0.5), 2.0);
            if abs(scaleFactor - 1.0) < 0.02 || numel(signalIn) < 512
                signalOut = signalIn;
                return;
            end

            frameLength = min(1024, max(256, 2 ^ nextpow2(min(numel(signalIn), 512))));
            analysisHop = max(32, round(frameLength / 4));
            synthesisHop = max(16, round(analysisHop * scaleFactor));
            window = hann(frameLength, "periodic");
            paddedSignal = [signalIn; zeros(2 * frameLength, 1)];
            targetLength = max(frameLength, round(numel(signalIn) * scaleFactor) + 2 * frameLength);
            outputBuffer = zeros(targetLength, 1);
            weightBuffer = zeros(targetLength, 1);

            inputPos = 1;
            outputPos = 1;
            while inputPos + frameLength - 1 <= numel(paddedSignal) && outputPos + frameLength - 1 <= targetLength
                frame = paddedSignal(inputPos:inputPos + frameLength - 1) .* window;
                outputBuffer(outputPos:outputPos + frameLength - 1) = outputBuffer(outputPos:outputPos + frameLength - 1) + frame;
                weightBuffer(outputPos:outputPos + frameLength - 1) = weightBuffer(outputPos:outputPos + frameLength - 1) + window .^ 2;
                inputPos = inputPos + analysisHop;
                outputPos = outputPos + synthesisHop;
            end

            weightBuffer(weightBuffer < 1e-6) = 1;
            signalOut = outputBuffer ./ weightBuffer;
            signalOut = signalOut(1:min(round(numel(signalIn) * scaleFactor), numel(signalOut)));
        end

        function signalOut = voiceResampleLinear(signalIn, targetLength)
            signalIn = signalIn(:);
            targetLength = max(8, round(targetLength));
            if numel(signalIn) < 2
                signalOut = repmat(signalIn(1), targetLength, 1);
                return;
            end

            sampleAxis = (1:numel(signalIn)).';
            readAxis = linspace(1, numel(signalIn), targetLength).';
            signalOut = interp1(sampleAxis, signalIn, readAxis, "linear", "extrap");
            signalOut = signalOut(:);
        end

        function channelSignal = applyChannelNoise(signalIn, snrDb)
            channelSignal = awgn(signalIn, snrDb, "measured");
            channelSignal = SignalSystemDSP.normalizeAudio(channelSignal);
        end

        function bitstream = audioToBitstream(signalIn)
            x = uint8(round((SignalSystemDSP.normalizeAudio(signalIn) + 1) * 127.5));
            bitstream = reshape(de2bi(x, 8, "left-msb").', [], 1);
        end

        function signalOut = bitstreamToAudio(bitstream)
            bitstream = logical(bitstream(:));
            paddedLength = ceil(numel(bitstream) / 8) * 8;
            bitstream(end + 1:paddedLength) = false;
            bytes = uint8(bi2de(reshape(bitstream, 8, []).', "left-msb"));
            signalOut = double(bytes) / 127.5 - 1;
            signalOut = SignalSystemDSP.normalizeAudio(signalOut(:));
        end

        function bits = resolveCommunicationBits(signalIn, config)
            if isfield(config, "inputBitSequence") && ~isempty(config.inputBitSequence)
                bits = logical(config.inputBitSequence(:));
            else
                candidateBits = SignalSystemDSP.audioToBitstream(signalIn);
                if isempty(candidateBits)
                    candidateBits = randi([0, 1], max(8, round(config.bitCount)), 1) > 0;
                end
                bits = logical(candidateBits(:));
            end

            targetCount = max(8, round(config.bitCount));
            if numel(bits) < targetCount
                repeatCount = ceil(targetCount / max(numel(bits), 1));
                bits = repmat(bits, repeatCount, 1);
            end
            bits = bits(1:targetCount);
        end

        function waveform = bitstreamToWaveform(bitstream, fs, symbolRate)
            bits = double(logical(bitstream(:)));
            if isempty(bits)
                waveform = zeros(0, 1);
                return;
            end
            samplesPerBit = max(8, round(fs / max(symbolRate, 1)));
            waveform = repelem(bits * 2 - 1, samplesPerBit);
            waveform = SignalSystemDSP.normalizeAudio(waveform(:));
        end

        function previewLines = buildBitPreview(info)
            previewLines = ["通信链未提供比特预览。"];
            if ~isfield(info, "sourceBits") || isempty(info.sourceBits)
                return;
            end
            sourceBits = char(info.sourceBits(:).' + '0');
            previewLines = [ ...
                "Bit Preview"; ...
                "Tx: " + string(sourceBits(1:min(64, numel(sourceBits))))];
            if isfield(info, "recoveredBits") && ~isempty(info.recoveredBits)
                recoveredBits = char(info.recoveredBits(:).' + '0');
                previewLines(end + 1, 1) = "Rx: " + string(recoveredBits(1:min(64, numel(recoveredBits)))); %#ok<AGROW>
            end
            if isfield(info, "bitErrorRate") && ~isnan(info.bitErrorRate)
                previewLines(end + 1, 1) = sprintf("BER: %.6f", info.bitErrorRate); %#ok<AGROW>
            end
        end

        function encodedBits = hamming74Encode(bits)
            bits = logical(bits(:));
            paddedLength = ceil(numel(bits) / 4) * 4;
            bits(end + 1:paddedLength) = false;
            data = reshape(bits, 4, []).';
            d1 = data(:, 1); d2 = data(:, 2); d3 = data(:, 3); d4 = data(:, 4);
            p1 = xor(xor(d1, d2), d4);
            p2 = xor(xor(d1, d3), d4);
            p3 = xor(xor(d2, d3), d4);
            encoded = [p1, p2, d1, p3, d2, d3, d4];
            encodedBits = encoded.';
            encodedBits = encodedBits(:);
        end

        function decodedBits = hamming74Decode(bits)
            bits = logical(bits(:));
            paddedLength = ceil(numel(bits) / 7) * 7;
            bits(end + 1:paddedLength) = false;
            codewords = reshape(bits, 7, []).';
            s1 = xor(xor(xor(codewords(:, 1), codewords(:, 3)), codewords(:, 5)), codewords(:, 7));
            s2 = xor(xor(xor(codewords(:, 2), codewords(:, 3)), codewords(:, 6)), codewords(:, 7));
            s3 = xor(xor(xor(codewords(:, 4), codewords(:, 5)), codewords(:, 6)), codewords(:, 7));
            syndrome = double(s1) + 2 * double(s2) + 4 * double(s3);

            for idx = 1:size(codewords, 1)
                if syndrome(idx) >= 1 && syndrome(idx) <= 7
                    codewords(idx, syndrome(idx)) = ~codewords(idx, syndrome(idx));
                end
            end

            decoded = codewords(:, [3, 5, 6, 7]);
            decodedBits = decoded.';
            decodedBits = decodedBits(:);
        end

        function config = normalizeCommConfig(configIn, fs)
            config = struct( ...
                "modulationType", "BPSK", ...
                "carrierHz", 2200, ...
                "modulationIndex", 0.75, ...
                "frequencyDeviationHz", 280, ...
                "channelSnrDb", 18, ...
                "symbolRate", 1000, ...
                "bitCount", 128, ...
                "inputBitSequence", []);
            fields = fieldnames(configIn);
            for idx = 1:numel(fields)
                config.(fields{idx}) = configIn.(fields{idx});
            end
            config.carrierHz = min(max(config.carrierHz, 300), 0.42 * fs);
            config.modulationIndex = min(max(config.modulationIndex, 0.1), 0.95);
            config.frequencyDeviationHz = min(max(config.frequencyDeviationHz, 40), 1500);
            config.channelSnrDb = min(max(config.channelSnrDb, 0), 40);
            config.symbolRate = min(max(config.symbolRate, 100), fs / 4);
            config.bitCount = min(max(round(config.bitCount), 8), 4096);
            if ~isempty(config.inputBitSequence)
                config.inputBitSequence = logical(config.inputBitSequence(:));
            end
        end

        function [modulatedSignal, txSymbols, mappingInfo] = modulateBitstream(encodedBits, fs, config, symbolsPerBit)
            bits = logical(encodedBits(:));
            modulationType = string(config.modulationType);
            carrierHz = config.carrierHz;
            tBit = (0:symbolsPerBit - 1).' / fs;
            modulatedSignal = zeros(0, 1);
            txSymbols = zeros(0, 1);
            mappingInfo = struct("bitsPerSymbol", 1);

            switch modulationType
                case "ASK"
                    for idx = 1:numel(bits)
                        amplitude = 0.35 + 0.65 * double(bits(idx));
                        symbolWave = amplitude * cos(2 * pi * carrierHz * tBit);
                        modulatedSignal = [modulatedSignal; symbolWave]; %#ok<AGROW>
                        txSymbols(end + 1, 1) = amplitude; %#ok<AGROW>
                    end
                case "FSK"
                    for idx = 1:numel(bits)
                        fShift = carrierHz + (double(bits(idx)) * 2 - 1) * 180;
                        symbolWave = cos(2 * pi * fShift * tBit);
                        modulatedSignal = [modulatedSignal; symbolWave]; %#ok<AGROW>
                        txSymbols(end + 1, 1) = complex(fShift, 0); %#ok<AGROW>
                    end
                case "BPSK"
                    phases = pi * double(bits);
                    for idx = 1:numel(bits)
                        symbolWave = cos(2 * pi * carrierHz * tBit + phases(idx));
                        modulatedSignal = [modulatedSignal; symbolWave]; %#ok<AGROW>
                    end
                    txSymbols = pskmod(double(bits), 2);
                case "QPSK"
                    mappingInfo.bitsPerSymbol = 2;
                    paddedLength = ceil(numel(bits) / 2) * 2;
                    bits(end + 1:paddedLength) = false;
                    symbolBits = reshape(bits, 2, []).';
                    symbols = bi2de(symbolBits, "left-msb");
                    txSymbols = pskmod(symbols, 4, pi / 4);
                    for idx = 1:numel(symbols)
                        phase = angle(txSymbols(idx));
                        symbolWave = cos(2 * pi * carrierHz * tBit + phase);
                        modulatedSignal = [modulatedSignal; symbolWave]; %#ok<AGROW>
                    end
                otherwise
                    error("Unsupported digital modulation type: %s", modulationType);
            end

            modulatedSignal = SignalSystemDSP.normalizeAudio(modulatedSignal);
        end

        function [decodedBits, rxSymbols, berValue] = demodulateBitstream(channelSignal, referenceBits, fs, config, symbolsPerBit, mappingInfo)
            modulationType = string(config.modulationType);
            carrierHz = config.carrierHz;
            referenceBits = logical(referenceBits(:));
            sampleCount = floor(numel(channelSignal) / symbolsPerBit) * symbolsPerBit;
            segments = reshape(channelSignal(1:sampleCount), symbolsPerBit, []).';
            tBit = (0:symbolsPerBit - 1).' / fs;
            rxSymbols = zeros(size(segments, 1), 1);

            switch modulationType
                case "ASK"
                    metric = max(segments .* cos(2 * pi * carrierHz * tBit).', [], [], 2);
                    decodedBits = metric > median(metric);
                    rxSymbols = metric;
                case "FSK"
                    tone0 = cos(2 * pi * (carrierHz - 180) * tBit);
                    tone1 = cos(2 * pi * (carrierHz + 180) * tBit);
                    proj0 = segments * tone0;
                    proj1 = segments * tone1;
                    decodedBits = proj1 > proj0;
                    rxSymbols = complex(proj0, proj1);
                case "BPSK"
                    referenceCarrier = cos(2 * pi * carrierHz * tBit);
                    proj = segments * referenceCarrier;
                    decodedBits = proj < 0;
                    rxSymbols = complex(proj, 0);
                case "QPSK"
                    iRef = cos(2 * pi * carrierHz * tBit);
                    qRef = -sin(2 * pi * carrierHz * tBit);
                    iVal = segments * iRef;
                    qVal = segments * qRef;
                    rxSymbols = complex(iVal, qVal);
                    phases = angle(rxSymbols);
                    phases = mod(phases - pi / 4, 2 * pi);
                    symbolIdx = mod(round(phases / (pi / 2)), 4);
                    symbolBits = de2bi(symbolIdx, 2, "left-msb");
                    decodedBits = reshape(symbolBits.', [], 1);
                otherwise
                    error("Unsupported digital demodulation type: %s", modulationType);
            end

            decodedBits = logical(decodedBits(:));
            referenceAligned = referenceBits(1:min(numel(referenceBits), numel(decodedBits)));
            decodedAligned = decodedBits(1:numel(referenceAligned));
            berValue = mean(xor(referenceAligned, decodedAligned));

            if mappingInfo.bitsPerSymbol == 2 && numel(decodedBits) < numel(referenceBits)
                decodedBits(end + 1:numel(referenceBits)) = false;
            end
        end

        function [chain, info] = recoverCommunicationFromChannel(channelSignal, fs, commInfo)
            config = SignalSystemDSP.normalizeCommConfig(commInfo.config, fs);
            chain = struct();
            info = commInfo;

            if any(string(config.modulationType) == ["AM璋冨箙", "FM璋冮"])
                [demodulatedSignal, demodInfo] = SignalSystemDSP.demodulateSignal(channelSignal(:), fs, config.modulationType, config.carrierHz, config.frequencyDeviationHz);
                chain.channel = channelSignal(:);
                chain.demodulated = demodulatedSignal(:);
                chain.restored = SignalSystemDSP.normalizeAudio(demodulatedSignal(:));
                info.demodulationInfo = demodInfo;
                info.bitErrorRate = NaN;
                info.summary = sprintf("%s demodulated from updated channel", config.modulationType);
                info.bitPreview = SignalSystemDSP.buildBitPreview(info);
                return;
            end

            encodedBits = logical(commInfo.encodedBits(:));
            symbolsPerBit = max(8, round(fs / max(config.symbolRate, 1)));
            mappingInfo = struct("bitsPerSymbol", 1);
            if string(config.modulationType) == "QPSK"
                mappingInfo.bitsPerSymbol = 2;
            end
            [decodedBits, rxSymbols, berValue] = SignalSystemDSP.demodulateBitstream(channelSignal(:), encodedBits, fs, config, symbolsPerBit, mappingInfo);
            recoveredBits = SignalSystemDSP.hamming74Decode(decodedBits);
            if isfield(commInfo, "sourceBits") && ~isempty(commInfo.sourceBits)
                recoveredBits = recoveredBits(1:min(numel(recoveredBits), numel(commInfo.sourceBits)));
            end

            chain.channel = channelSignal(:);
            chain.demodulated = double(decodedBits(:));
            chain.decoded = double(recoveredBits(:));
            chain.restored = SignalSystemDSP.bitstreamToWaveform(recoveredBits, fs, config.symbolRate);

            info.constellation = struct("tx", commInfo.constellation.tx, "rx", rxSymbols);
            info.recoveredBits = logical(recoveredBits(:));
            info.bitErrorRate = berValue;
            info.summary = sprintf("%s demodulated from updated channel", config.modulationType);
            info.bitPreview = SignalSystemDSP.buildBitPreview(info);
        end

        function stageTitle = resolveStageTitle(stageLabels, stageKey)
            stageTitle = string(stageKey);
            if isstruct(stageLabels)
                fieldName = char(stageKey);
                if isfield(stageLabels, fieldName)
                    stageTitle = string(stageLabels.(fieldName));
                end
            elseif isa(stageLabels, "containers.Map") && isKey(stageLabels, char(stageKey))
                stageTitle = string(stageLabels(char(stageKey)));
            end
        end

        function dominantFrequencyHz = findDominantFrequency(signal, fs)
            [frequencyAxis, magnitudeDb] = SignalSystemDSP.magnitudeSpectrum(signal, fs);
            if isempty(frequencyAxis)
                dominantFrequencyHz = NaN;
                return;
            end
            [~, maxIdx] = max(magnitudeDb);
            dominantFrequencyHz = frequencyAxis(maxIdx);
        end

        function value = sampleKurtosis(signal)
            signal = signal(:);
            signal = signal - mean(signal, "omitnan");
            sigma = std(signal, "omitnan");
            if sigma < eps
                value = 0;
                return;
            end
            value = mean((signal / sigma) .^ 4, "omitnan");
        end
    end
end
