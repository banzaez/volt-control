<div align="center">

# VoltControl ⚡

**A lightweight, native macOS Menu Bar application for real-time power analytics, intelligent battery charging control, and high-energy process monitoring on Apple Silicon & Intel MacBooks.**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple&style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&style=flat-square)](https://swift.org/)
[![Release](https://img.shields.io/github/v/release/banzaez/volt-control?style=flat-square)](https://github.com/banzaez/volt-control/releases/latest)

[Overview](#-overview) • [Core Features](#-core-features) • [Engineering & Architecture](#-engineering--architecture) • [Configuration Guide](#-configuration-guide) • [Installation](#-installation) • [Building](#-building)

</div>

---

## 📖 Overview

MacBook lithium-ion cells experience accelerated chemical aging when continuously kept at 100% capacity under sustained charging voltage and elevated operating temperatures.

**VoltControl** is engineered as a modern, lightweight native utility that provides:
1. **Real-time power flow tracking**: Watt-level monitoring across DC adapter input, internal battery charging/discharging, and Mac system load.
2. **Proactive charging thresholds**: Custom charge limits, hysteresis-based Sailing Mode, and thermal safeguards.
3. **Stabilized process monitoring**: A fixed 3-slot energy consumer panel designed to eliminate menu bar popover flickering and height jumping.
4. **Native efficiency**: Built using SwiftUI, AppKit, and IOKit, consuming less than 25 MB of memory with near-zero CPU footprint.

---

## 🚀 Core Features

### ⚡ Real-Time Power Telemetry
Unlike conventional battery utilities that only display percentage increments, VoltControl reads live wattage directly from hardware sensors:

| Metric | Source Sensor | Description |
| :--- | :--- | :--- |
| **Adapter Input** | `PDTR` (SMC) / `PowerTelemetryData` | Total DC-In power arriving from USB-C or MagSafe chargers. |
| **Battery Power** | `SBAP` (SMC) / `AppleSmartBattery` | Signed wattage flow: `+W` when replenishing, `-W` during discharge. |
| **System Load** | `PSTR` (SMC) / Computed Balance | Net real-time power consumed by the SoC, display, and peripherals. |
| **Split Balance** | Real-time Ratio | Proportional balance bar showing how incoming power splits between system and cells. |

### 🛡️ Smart Charging Protection
- **Target Limiting (50% – 100%)**: Set custom stopping limits (recommended 80%) to minimize cell voltage stress.
- **Sailing Mode (Hysteresis)**: Allows charge to naturally settle within a customizable delta (e.g., 4%) before topping back up, avoiding harmful micro-cycles.
- **One-Click Top Up**: Rapidly charges to 100% on demand prior to mobile sessions, then automatically restores your previous limit.
- **Thermal Safety Cutoff**: Suspends charging automatically when pack thermals exceed a configured threshold (32°C to 45°C).
- **Direct Battery Mode**: Temporarily pause power delivery to run on internal battery while physically connected to AC.

### 📊 Stable Energy Impact Panel
- **Zero-Jitter Fixed Layout**: The process monitor occupies an exact 76 pt vertical frame, ensuring popover menus never resize or jump during background scans.
- **Informative Empty State**: Displays a reassuring status card (*"No high energy apps · Process consumption normal"*) when running software stays within baseline CPU limits.
- **Adjustable Sensitivity**: Fine-tune custom thresholds for *High* and *Very High* consumption categories.
- **Process Filters**: Toggle inclusion of moderate activity, background daemons, or define an app blacklist.

### 🎨 Menu Bar Customization
- **Icon Styles**:
  - **Capsule Pill**: Displays battery level percentage inside the battery shape, accompanied by live lightning indicators on AC.
  - **Classic Battery**: Traditional proportional fill bar with embedded vector charging indicator.
  - **Minimal Symbol**: Compact bolt indicator for minimal status bars.
- **Status Readouts**: Pair icons with text labels displaying numeric percent, signed wattage (`+24.5 W` / `-5.6 W`), or pack temperature.
- **Colorized Accents**: Optional native green/blue/red state highlights or clean monochrome.

---

## 🔬 Engineering & Architecture

### Power Telemetry Pipeline

VoltControl uses a dual-source telemetry architecture for zero-latency accuracy:

```
┌─────────────────────────────────┐
│     AppleSmartBattery (IOKit)   │───► [IOPSNotification Source] ───► Instant AC State
└─────────────────────────────────┘
┌─────────────────────────────────┐
│        AppleSMC Kernel          │───► [PDTR: DC-In Watts]      ───► Adapter Power
│                                 │───► [SBAP: Signed Battery W]  ───► Cell Charge/Discharge
│                                 │───► [PSTR: System Total W]    ───► MacBook Net Load
└─────────────────────────────────┘
```

- **Instantaneous State Detection**: Leverages `IOPSNotificationCreateRunLoopSource` attached to `CFRunLoopGetMain()`, ensuring zero latency when plugging or unplugging adapters.
- **SMC Float Decoder**: Reads raw IEEE-754 4-byte values directly from `AppleSMC`, eliminating inaccurate shell approximations.
- **Integer Sign Safety**: Employs signed 64-bit integer bit-pattern reconstruction to guard against two's-complement overflow on 64-bit IOKit telemetry keys.

---

## ⚙️ Configuration Guide

The Settings window (`⌘,`) organizes configuration into dedicated sections:

1. **General**: Launch at login registration (`SMAppService`), sensor sampling frequency (1–10s), popover action behavior.
2. **Charging**: Target charge limit slider, sailing delta configuration, temperature cutoff controls.
3. **Energy**: CPU percentage threshold sliders, system process inclusion, moderate/low consumption toggles, process ignore list.
4. **Menu**: Granular visibility switches for remaining time, elapsed time, power distribution block, and process monitoring.
5. **Icon**: Menu bar style selector, readout mode, and preview canvas.
6. **Diagnostics**: Uniform 2x3 grid displaying cycle count, pack thermals, voltage, amperage, net battery wattage, and system draw.
7. **Notifications**: System alerts for limit reached, full top-up completion, thermal warning, and low battery.
8. **SMC Controller**: Hardware register access verification and privileged helper status.
9. **About**: Version information, driver status, and architecture overview.

---

## 📦 Installation

### Prebuilt Binary

1. Download **`VoltControl-v1.0.0.zip`** from [GitHub Releases](https://github.com/banzaez/volt-control/releases/latest).
2. Decompress the archive and place **`VoltControl.app`** in your `/Applications` directory.
3. Open the application. Access preferences at any time from the status item menu (`⌘,`).

---

## 🛠 Building

### Requirements
- macOS 14.0 (Sonoma) or later
- Swift 6.0+ toolchain / Xcode 15.0+

```bash
# Clone repository
git clone https://github.com/banzaez/volt-control.git
cd volt-control

# Build release bundle
./build_app.sh

# Run
open VoltControl.app
```

The `./build_app.sh` script compiles the release binary via SwiftPM, constructs the application bundle layout, dynamically renders the custom vector app icon into `AppIcon.icns`, and applies an ad-hoc code signature.
