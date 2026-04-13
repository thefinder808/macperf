# MacPerf UX Overhaul — Design Spec

## Context

MacPerf is a native SwiftUI macOS performance monitoring app (macOS 14+, ~5,700 LOC) at v1.0.0. It monitors CPU, Memory, GPU, Network, Disk, Thermal, Battery, Processes, and Storage with a NavigationSplitView layout, menu bar popover, command palette, and 3 themes (Dark/Light/Neon).

The competitive landscape (iStat Menus, Stats, Activity Monitor) leaves room for a visually distinctive, modern alternative. iStat Menus v7 is buggy and complex; Stats is bare-bones; Activity Monitor is too basic. MacPerf can differentiate by being the best-looking, most polished system monitor on Mac.

**Goal:** A comprehensive UX overhaul in 4 phases, starting with a modular chart system that establishes a neon/cyberpunk visual identity and user-configurable chart types.

---

## Phase 1: Modular Chart System & Richer Visualizations (BUILD FIRST)

### New Component: `NeonChartView`

A single reusable SwiftUI view replacing the current `PerformanceGraph` across the entire app.

**Inputs:**
- `data: TimeSeries` — existing model, no changes needed
- `chartType: ChartType` — enum: `.line`, `.bar`, `.area`
- `sizeVariant: ChartSizeVariant` — enum: `.compact`, `.medium`, `.full`
- `colorScheme` — pulled from ThemeManager automatically

**Chart Types:**
- **Line**: Smooth curved line with gradient fill below (existing style, enhanced with neon glow)
- **Bar**: Vertical bars with gradient fills (cyan to magenta for Neon theme)
- **Area**: Filled area chart with translucent gradient

**Neon Styling:**
- Gradient fills: cyan (`#00ffcc`) to magenta (`#ff00ff`) for primary metrics
- Glow/shadow effects on lines and data points via SwiftUI `.shadow` modifiers
- Animated transitions when switching chart types or on data updates
- Dark/Light themes get their own appropriate color mappings (subtle, not neon)

**Size Variants:**
- `.compact` — sparkline size for menu bar and sidebar (~60x24pt)
- `.medium` — dashboard card size (~200x120pt)
- `.full` — detail view size (fills available width, ~200pt tall)

### Chart Type Selector

- Segmented control using SF Symbols: `chart.line.uptrend.xyaxis`, `chart.bar.fill`, `chart.xyaxis.line`
- Placed in `MetricHeader` area of each detail view
- User's choice persisted per metric category in `SettingsManager` (UserDefaults)
- Default: `.line` for all metrics

### New Models

```swift
enum ChartType: String, CaseIterable, Codable {
    case line, bar, area
}

enum ChartSizeVariant {
    case compact, medium, full
}
```

### Files to Modify

| File | Change |
|------|--------|
| `Sources/MacPerf/Views/Components/PerformanceGraph.swift` | Replace with `NeonChartView` — this file becomes unused and can be removed |
| `Sources/MacPerf/Views/Components/MiniGraphCard.swift` | Use `NeonChartView(.compact)` |
| `Sources/MacPerf/Views/Components/MiniSparkline.swift` | Use `NeonChartView(.compact)` |
| `Sources/MacPerf/Views/Components/MetricHeader.swift` | Add chart type segmented control |
| `Sources/MacPerf/Views/Detail/CPUDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/MemoryDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/GPUDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/NetworkDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/DiskDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/ThermalDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/Views/Detail/BatteryDetailView.swift` | Swap to `NeonChartView(.full)` |
| `Sources/MacPerf/App/SettingsManager.swift` | Add per-metric chart type preferences |
| `Sources/MacPerf/Theme/AppTheme.swift` | Extend protocol with chart-specific colors (glow, gradient stops) |
| `Sources/MacPerf/Theme/Themes/NeonTheme.swift` | Add neon chart colors |
| `Sources/MacPerf/Theme/Themes/DarkTheme.swift` | Add dark chart colors |
| `Sources/MacPerf/Theme/Themes/LightTheme.swift` | Add light chart colors |

### Files to Create

| File | Purpose |
|------|---------|
| `Sources/MacPerf/Views/Components/NeonChartView.swift` | The new modular chart component |
| `Sources/MacPerf/Models/ChartType.swift` | ChartType and ChartSizeVariant enums |

### What Stays Unchanged

- All 9 monitors and their data collection logic
- All 9 view models and their published properties
- `TimeSeries` model and ring buffer
- `AppState` central observable
- App structure (NavigationSplitView, sidebar categories)
- Command palette, keyboard shortcuts
- Export service (CSV/JSON)

---

## Phase 2: Menu Bar Overhaul

### New Design: Mini-Dashboard Popover

Replace the current basic metric list in `MenuBarView.swift` with a compact 2-column grid of NeonChart cards.

**Layout:**
- 2-column grid of metric cards, each using `NeonChartView(.compact)`
- Each card: metric name, current value, tiny sparkline
- Click any card opens main window focused on that metric
- Quick actions bar at bottom: Export snapshot, toggle alerts, open Settings
- Popover width: ~320pt (up from current)

**Files to Modify:**
- `Sources/MacPerf/Views/MenuBar/MenuBarView.swift` — redesign layout
- `Sources/MacPerf/App/StatusBarController.swift` — adjust popover size

---

## Phase 3: Custom Dashboards

### New View: `DashboardView`

A user-configurable grid as a new sidebar entry above Overview.

**Features:**
- Grid of `NeonChartView(.medium)` cards, one per selected metric
- Users choose which metrics appear and drag to reorder
- SwiftUI `draggable`/`dropDestination` for reordering
- Layout persisted in `SettingsManager` (UserDefaults)
- Accessible from sidebar as "Dashboard" — new entry above Overview (Overview remains as-is)

**Files to Create:**
- `Sources/MacPerf/Views/Detail/DashboardView.swift`
- `Sources/MacPerf/Models/DashboardLayout.swift` (persisted layout config)

**Files to Modify:**
- `Sources/MacPerf/Views/Sidebar/SidebarView.swift` — add Dashboard entry
- `Sources/MacPerf/Models/MetricCategory.swift` — add `.dashboard` case
- `Sources/MacPerf/App/SettingsManager.swift` — persist layout

---

## Phase 4: Desktop Widgets (WidgetKit)

### Widget Extension

macOS WidgetKit widgets for Notification Center and desktop.

**Widget Sizes:**
- Small: Single metric + sparkline
- Medium: 2-3 metrics side by side
- Large: Mini dashboard grid

**Architecture:**
- New widget extension target in Package.swift / Xcode project
- Shared App Group container for data passing (main app writes latest snapshots, widget reads)
- Widget timeline provider refreshes on system schedule (not real-time)
- Neon color scheme applied to widget rendering

**Limitation:** WidgetKit widgets update every few minutes, not in real-time. This is a platform constraint. The UI should set expectations accordingly.

**Files to Create:**
- New `MacPerfWidget/` extension directory with timeline provider, widget views, and entry types

---

## Verification Plan

### Phase 1 Verification
1. `swift build` — project compiles cleanly
2. Launch app — every detail view shows the new NeonChartView
3. Toggle chart types (line/bar/area) via segmented control on each detail view
4. Quit and relaunch — chart type preferences persist per metric
5. Switch themes (Neon/Dark/Light) — charts update styling correctly
6. Overview mini cards use the new compact chart variant
7. Time range picker (1m/5m/15m/1h) still works with new charts

### Phase 2 Verification
1. Click menu bar icon — popover shows 2-column grid with mini charts
2. Click a card — main window opens to that metric
3. Quick actions work (export, alerts, settings)

### Phase 3 Verification
1. Dashboard view shows in sidebar
2. Cards display correctly with medium-size charts
3. Drag-and-drop reordering works
4. Layout persists across app restart

### Phase 4 Verification
1. Widget extension builds and installs
2. Widgets appear in widget gallery
3. All three sizes render correctly
4. Data updates from main app flow to widgets
