# MacPerf

A native macOS performance monitor built with SwiftUI. Real-time graphs and metrics for CPU, memory, disk, network, GPU, and thermals.

## Features

- **CPU** — Per-core utilization, system/user/idle breakdown
- **Memory** — Usage breakdown (active, wired, compressed, cached) with accurate pressure gauge
- **Disk** — Read/write throughput
- **Network** — Upload/download bandwidth
- **GPU** — Utilization and temperature
- **Thermal** — CPU/GPU temperatures via HID sensors (Apple Silicon) and SMC (Intel)
- **Processes** — Top processes by CPU/memory usage
- **Overview** — Dashboard with mini sparklines for all metrics
- Theme support (dark, light, neon) and CSV/JSON export

## Requirements

- macOS 14.0+
- Swift 5.9+

## Build & Run

```bash
swift build
swift run MacPerf
```

## Build Installer

```bash
chmod +x build-pkg.sh
./build-pkg.sh
```

This produces `dist/MacPerf.app` and a `.pkg` installer. See the script for optional code signing and notarization via environment variables.
