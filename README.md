<div align="center">

<img src="macperf_icon.png" alt="MacPerf" width="128" height="128" />

# MacPerf

A native macOS performance monitor built with SwiftUI.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)

Real-time graphs and metrics for CPU, memory, disk, network, GPU, and thermals — in a main window dashboard and a menu bar dropdown.

</div>

## Features

- **CPU** — Per-core utilization, system / user / idle breakdown
- **Memory** — Active, wired, compressed, cached breakdown with accurate pressure gauge
- **Disk** — Read/write throughput
- **Network** — Upload / download bandwidth
- **GPU** — Utilization and temperature
- **Thermal** — CPU/GPU temperatures via HID sensors (Apple Silicon) and SMC (Intel)
- **Processes** — Top processes by CPU / memory usage with tree view
- **Battery** — Charge level, charging state, time-to-full / time-to-empty (when present)
- **Storage** — Per-volume capacity and I/O
- **Menu bar dropdown** — Quick-glance metrics that float over fullscreen apps
- **Themes** — Dark, Light, Neon
- **Export** — CSV / JSON for the current session's metric history

## Requirements

- macOS 14.0+
- Apple Silicon or Intel

## Install

Download the latest signed and notarized installer from the [Releases page](https://github.com/thefinder808/macperf/releases/latest), open the `.pkg`, and follow the installer.

## Build from source

```bash
swift build
swift run MacPerf
```

Requires Swift 5.9+.

## Build the installer

```bash
chmod +x build-pkg.sh
./build-pkg.sh
```

Produces `dist/MacPerf.app` and a `.pkg` in `dist/`. To produce a signed and notarized package, set the following environment variables before running:

```bash
export MACPERF_SIGN_APP="Developer ID Application: Your Name (TEAMID)"
export MACPERF_SIGN_PKG="Developer ID Installer: Your Name (TEAMID)"
export MACPERF_APPLE_ID="you@example.com"
export MACPERF_TEAM_ID="TEAMID"
export MACPERF_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # app-specific password
```

Without these set, the script produces an unsigned local build.

## License

[MIT](LICENSE) © Nathaniel Graham
