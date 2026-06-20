# MATLAB-Signals-and-Systems-Interactive-APP
MATLAB Signals and Systems Interactive APP for course

[![MATLAB R2020b+](https://img.shields.io/badge/MATLAB-R2020b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Course: Signals and Systems](https://img.shields.io/badge/Course-Signals%20and%20Systems-green.svg)]()

A comprehensive, production-ready interactive APP for the **Signals and Systems** university course. Built entirely in MATLAB with a native GUI, it covers all core course topics with robust error handling, automatic demo mode, and one-click experiment report export.

## 📖 Project Overview

This APP is designed as a complete teaching and learning tool for signals and systems courses. It provides hands-on experience with audio signal processing, filtering, modulation, and communication systems. All features are optimized for classroom demonstration and student experiments, with extensive fault tolerance to ensure smooth operation even in environments with missing toolboxes or hardware limitations.

## ✨ Core Features

### 1. Signal Acquisition

- 📁 Load local audio files (WAV/MP3)
- 🎤 Real-time microphone recording with live waveform analysis
- 🔧 Generate synthetic test signals (sine, square, chirp, etc.)
- 📦 Built-in sample speech signals for quick testing

### 2. Noise & Interference

- Add white Gaussian noise with adjustable SNR
- Simulate 50/60 Hz power line interference
- Mixed noise generation for realistic scenarios
- Automatic processing chain history tracking

### 3. Advanced Filtering

- Butterworth, Chebyshev, FIR, notch, median, and wavelet filters
- Lowpass, highpass, bandpass, and bandstop configurations
- **Intelligent filter recommendation**: Automatically detects noise types and suggests optimal filters
- Automatic fallback to FFT-based filtering when toolbox functions are unavailable

### 4. Voice Transformation

- 8 built-in voice effects: Original, Male, Female, Robot, Telephone, Echo, Monster, Custom EQ
- A/B side-by-side comparison of waveforms and spectra
- Real-time playback of transformed audio

### 5. Digital Communication

- Analog modulation: AM, FM, ASK, FSK
- Digital modulation: BPSK, QPSK with constellation diagrams
- Complete communication chain: Encoding → Modulation → AWGN channel → Demodulation → Decoding
- BER (Bit Error Rate) calculation and analysis

### 6. Data Visualization & Export

- Time-domain waveforms, frequency spectra, spectrograms/waterfall plots
- Filter frequency response, processing metrics, and operation history
- **One-click experiment report export**: Automatically saves all figures, CSV metrics, audio files, and screenshots to a timestamped folder
- A/B comparison between any two processing stages

### 7. Preset Scenarios

- Classroom Demonstration
- Speech Denoising
- Power Line Interference Suppression
- Secure Communication
- Digital Modulation Analysis

## 🚀 Quick Start

1. Clone or download this repository
2. Open MATLAB (R2020b or later recommended)
3. Set your current working directory to the project folder
4. Run the APP from the MATLAB command line:

   ```matlab
   launch_signal_system_app
   ```

## 🎬 Automatic Demo Mode

Run the fully automated demonstration script to generate all experiment materials in one go:

```matlab
run_assignment_demo
```

This will create an `outputs/` folder containing:

- All demonstration figures
- Performance metrics in CSV format
- Key audio files
- Complete experiment report bundle (`report_bundle_YYYYMMDD_HHMMSS/`)
- Individual scenario preset results

## 📂 Project Structure

```
Signals-Systems-APP/
├── launch_signal_system_app.m    # Main entry point
├── SignalSystemDSP.m             # Core signal processing engine
├── run_assignment_demo.m         # Automatic demo script
└── README.md
```

## 🌟 Key Highlights

- **Maximum Compatibility**: Automatic fallback mechanisms for missing Signal Processing Toolbox functions
- **Robust Error Handling**: Gracefully handles missing audio devices, invalid inputs, and short signals
- **Zero Configuration**: No external dependencies beyond standard MATLAB
- **Experiment-Friendly**: One-click export of all materials needed for lab reports
- **Modular Design**: Easy to extend with new filters, effects, or modulation schemes

## ⚠️ Notes

- MATLAB R2020b or later is recommended. Older versions may have limited GUI functionality.
- Some advanced features (wavelet filtering, professional voice transformation) require the Signal Processing Toolbox. The APP will automatically degrade to equivalent basic implementations if the toolbox is missing.
- Voice transformation effects are optimized for educational demonstration, not commercial-grade quality.
- BPSK/QPSK implementation focuses on core modulation/demodulation concepts for teaching purposes.

## 🔮 Future Improvements

- Upgrade voice transformation with Phase Vocoder or PSOLA algorithms
- Add carrier recovery and symbol timing synchronization for digital communication
- Implement automated unit tests
- Redesign GUI with a dark theme and card-based layout
- Add direct export to Word/PDF experiment reports

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

If you find this project useful for your course or research, please give it a ⭐ on GitHub! For any issues or bug reports, please open an issue with your MATLAB version and full error message.
