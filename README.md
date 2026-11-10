<div align="center">

# VoltControl ⚡

**A lightweight, native macOS Menu Bar application for real-time power analytics, intelligent battery charging control, and high-energy process monitoring on Apple Silicon & Intel MacBooks.**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple&style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&style=flat-square)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/banzaez/volt-control?style=flat-square)](https://github.com/banzaez/volt-control/releases/latest)

[Overview](#-overview) • [Key Features](#-key-features) • [Telemetry & Hardware Math](#-telemetry--hardware-math) • [Installation](#-installation) • [Building from Source](#-building-from-source)

</div>

---

## 📖 Overview

MacBook batteries degrade significantly faster when consistently maintained at 100% state-of-charge under high operating temperatures while plugged into power. **VoltControl** provides granular battery charging thresholds, precise real-time wattage tracking across system components, and proactive high-impact process detection—built entirely with native macOS technologies and zero Electron overhead.

---

## 🚀 Key Features

### 1. Real-Time Power Distribution (Watts)
- **Live Hardware Wattmeter**: Continuously calculates power flow across the entire power subsystem:
  - **Adapter Input**: Real-time wattage supplied by USB-C or MagSafe chargers.
  - **System Load**: Active MacBook hardware power consumption.
  - **Battery Flow**: Exact charging rate (`+W`) into the battery or discharge rate (`-W`) during battery operation.
  - **Bypass Detection**: Instantly reflects zero-load battery bypass when charging is inhibited or target limits are achieved.
- **Power Split Balance Bar**: Visual distribution indicator comparing system draw against battery replenishment.

### 2. Intelligent Battery Protection
- **Configurable Charge Limits**: Set custom stopping thresholds between 50% and 100% (default: 80%) to maximize lithium-ion cycle longevity.
- **Sailing Mode (Hysteresis)**: Prevents premature micro-cycling by permitting battery level to float within a user-defined delta (e.g., 4–5%) before charge resumption.
- **One-Click Top Up**: Conveniently charge to 100% ahead of travel, with automatic restoration of the standard threshold upon completion.
- **Thermal Safety Cutoff**: Automatic charging suspension if pack temperature exceeds safety thresholds (configurable between 32°C and 45°C).
- **Direct Battery Operation**: Force bypass mode and run on battery power while remaining physically plugged in.

### 3. Jitter-Free Energy Impact Monitor
- **Fixed 3-Slot Layout**: The menu popover retains an exact, fixed 76 pt vertical footprint—eliminating UI layout jumps during process scanning.
- **Intelligent Status Messaging**: Displays a clean system health card (*"No high energy apps · Process consumption normal"*) whenever background activity remains within normal operating limits.
- **Customizable CPU Thresholds**: Individually adjust sensitivity for *High* and *Very High* consumption tags.
- **Granular Filter Toggles**: Option to include or exclude *Moderate* and *Low* activity apps, as well as core system daemons.
- **Blacklist Support**: Exclude designated utilities and background tools from energy monitoring.

### 4. Refined Menu Bar Display
- **Multiple Icon Styles**:
  - **Capsule Pill**: Displays current charge percentage directly inside the battery enclosure with live AC bolt indicators.
  - **Classic Battery**: Native-proportioned battery gauge with charging bolt overlay.
  - **Minimal Bolt**: Compact status indicator.
- **Flexible Accompanying Readouts**: Combine icon display with numeric percentages, signed wattage (`+24.5 W` / `-5.2 W`), or sensor temperatures.
- **Colorized Status Accents**: Optional state-based tinting (Charging Green, Limit Blue, Low-Power Red) or strict native monochrome.

### 5. Detailed Hardware Diagnostics
- **Comprehensive Metrics Grid**: Uniformly aligned diagnostic cards monitoring:
  - Battery Health Percentage (`CurrentMaxCapacity` vs `DesignCapacity`).
  - Total Recharging Cycle Count.
  - Multi-sensor Battery Pack Temperature (°C).
  - Terminal Voltage (V) & Instant Amperage (mA).
  - Net Battery Wattage & Mac System Consumption.

---

## 🔬 Telemetry & Hardware Math

VoltControl interfaces directly with macOS kernel power services without relying on inaccurate shell wrappers or polling lags:

```mermaid
flowchart LR
    A["DC-In Adapter (PDTR)"] -->|Input Watts| B{"Power Controller"}
    B -->|System Load (PSTR)| C["MacBook Hardware"]
    B -->|Battery Power (SBAP)| D["Smart Battery Pack"]
```

1. **AppleSMC Telemetry**: Reads raw IEEE-754 4-byte floating-point registers:
   - `PDTR` — DC-In Adapter Total Power (Watts).
   - `SBAP` — Smart Battery Average Power (+W on battery discharge, -W when charging).
   - `PSTR` — System Total Load.
2. **IOKit Kernel Services**:
   - Queries `AppleSmartBattery` & `AppleSmartBatteryPack` for internal design thresholds, gas-gauge telemetry, and raw pack thermals.
   - Attaches an asynchronous `IOPSNotificationCreateRunLoopSource` callback to `CFRunLoopGetMain()`, ensuring zero-latency detection of adapter connection and disconnection events.

---

## 📦 Installation

### Prebuilt Binary (Recommended)

1. Download the latest release archive (`VoltControl-v1.0.0.zip`) from [GitHub Releases](https://github.com/banzaez/volt-control/releases/latest).
2. Extract the archive and drag **`VoltControl.app`** into your **`/Applications`** folder.
3. Launch **VoltControl**.

> [!NOTE]
> VoltControl functions as an accessory status bar application without docking clutter. Access preferences at any time by clicking the menu bar icon and selecting **Settings…** (`⌘,`).

---

## 🛠 Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or newer.
- Xcode 15.0+ or Command Line Tools with Swift 6.0+.

### Build & Package

```bash
# Clone the repository
git clone https://github.com/banzaez/volt-control.git
cd volt-control

# Run the release build & packaging script
chmod +x ./build_app.sh
./build_app.sh

# Launch the newly compiled application
open VoltControl.app
```

The `./build_app.sh` script automates:
- Release compilation via Swift Package Manager (`swift build -c release`).
- Creation of the macOS bundle structure (`VoltControl.app`).
- Programmatic vector rendering of the custom Blue Lego Brick icon into multi-resolution `AppIcon.icns`.
- Embedding of bundle metadata (`Info.plist`) and ad-hoc code signature generation.

---

## 🧪 Testing

Execute the native Swift Testing suite:

```bash
swift test
```

---

## 📄 License

VoltControl is open-source software licensed under the [MIT License](LICENSE).
