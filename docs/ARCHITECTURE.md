# MacPerf Architecture

A native macOS system monitor (SwiftUI + AppKit, SwiftPM). This document focuses on
the runtime data-flow and the **efficiency model**, since several behaviors there are
deliberate and easy to regress.

## Layers

- **Monitors** (`Sources/MacPerf/Monitors/`) — stateless-ish samplers over Mach /
  `sysctl` / IOKit / SMC. Each `sample()` returns a snapshot struct. No timers, no
  published state. Cheap counters (CPU, memory, disk, network, GPU); process
  enumeration (`ProcessMonitor`) is the heaviest.
- **View models** (`Sources/MacPerf/ViewModels/`) — one `ObservableObject` per metric.
  Each `update()` reads its monitor, publishes scalar `@Published` values, and appends
  to its `TimeSeries` chart buffers.
- **`AppState`** (`Sources/MacPerf/App/AppState.swift`) — owns all view models, the
  single master timer, and the navigation/UI state. It is the update orchestrator.
- **Views** (`Sources/MacPerf/Views/`) — SwiftUI. Charts are `NeonChartView`
  (Swift Charts) observing a `TimeSeries` directly.
- **`StatusBarController`** — the menu-bar `NSStatusItem` + dropdown `NSPanel`. The
  panel's "Open MacPerf" button calls `AppState.showMainWindow()`, which focuses an
  existing dashboard window (matched by its `main-` window identifier) or recreates
  one through `openWindowAction` — an `openWindow(id: "main")` capture that
  `ContentView` stores on `AppState`, since the panel's own environment has no
  working `openWindow`.

## Update cycle

A single `Timer.publish(every: samplingInterval …)` in `AppState.startTimer()` drives
everything; `update()` staggers work by tick count (cheap counters every tick,
processes every 2, thermal/storage/battery every 5). `samplingInterval` (1/2/5 s) is
user-configurable in Settings and persisted to `UserDefaults`; changing it restarts the
timer.

View models forward their `objectWillChange` into `AppState.objectWillChange` (the
"fan-in") so views observing `AppState` refresh each tick.

## Efficiency model (read before changing the update path)

MacPerf is a long-running, mostly-background app, so **doing no work when nothing is
visible** is the core performance property. Invariants:

1. **Menu-bar icons are cached.** `StatusBarController` caches its SF Symbol `NSImage`s
   and font once and dedups by rendered string. Recreating `NSImage(systemSymbolName:)`
   every tick re-parses the symbol's SVG and **leaks CoreSVG allocations** — this was
   the cause of multi-GB RSS growth over days. Do not recreate symbols per refresh.

2. **Visibility gating.** `AppState.isWindowVisible` is recomputed from
   `NSApp.isHidden`, `NSApp.occlusionState`, and window state (titled, on-screen,
   not minimized). It is false when the app is hidden (`Cmd-H`), minimized, fully
   occluded, or its window is closed. The gate that actually drives the update path
   is **`isUIVisible = isWindowVisible || isMenuPanelOpen`** — the menu-bar panel is
   a *borderless* `NSPanel` that never counts as a visible window, but it renders
   live metrics, so it must count as visible UI. (Gating on `isWindowVisible` alone
   shipped in 1.1.0 and froze the pop-down whenever the dashboard was closed.)

3. **Idle when not visible.** When `!isUIVisible`, `update()` takes a lightweight
   branch: it refreshes only the menu-bar metric *scalars* (`update(appendHistory:
   false)` — skips `TimeSeries` appends so charts don't re-render) and calls
   `menuBarRefresh`. It also **suppresses the fan-in** so SwiftUI doesn't re-evaluate /
   re-draw the off-screen window. Result: ~0 % CPU and minimal RSS while backgrounded.
   On becoming visible again — `recomputeWindowVisibility()` or the panel opening
   (`isMenuPanelOpen` didSet) — one `objectWillChange` refreshes the now-visible UI.

4. **The status item stays live while hidden** via `AppState.menuBarRefresh`, a closure
   `StatusBarController` sets to `updateLabel()`. The menu bar updates through this hook
   every tick — *independent of the suppressed fan-in* — so hiding the app does not
   freeze the menu-bar numbers. (Do not route the menu bar back through
   `appState.objectWillChange`, or it will go stale while hidden.) The label dedup
   **self-heals**: even when the rendered string is unchanged it is re-applied every
   ~10 ticks, because AppKit can transiently drop a status button's content (space
   switches, wake) and rounded values can stay identical for minutes — a pure dedup
   left the item blank until a value happened to change. The re-apply reuses the
   cached images, so it never re-parses symbols.

5. **Process enumeration is gated** behind `needsProcessData` (Processes tab visible, or
   the menu panel / command palette open) — it's the heaviest sample and is invisible
   otherwise. It refreshes immediately when a process view appears.

6. **Continuous animations** (`OverviewView` live-pulse, `PressureGauge` glow) run only
   while the app is the active app (`controlActiveState`), and charts opt out of
   Swift Charts' per-redraw accessibility-data generation (`.accessibilityHidden(true)`).

## Auto-update (Sparkle)

`UpdaterService` (`Sources/MacPerf/Services/`) wraps Sparkle 2's
`SPUStandardUpdaterController` — ported from macpad/TraceView, including the
macOS App Management TCC alert (Sparkle error 4012 means "grant permission in
System Settings", not "update failed"). The appcast feed and signed DMGs live
on the public **gh-pages** branch (`https://thefinder808.github.io/macperf/appcast.xml`);
updates are EdDSA-signed with the shared fleet Sparkle key (private key in the
login Keychain).

Build integration (`build-dmg.sh`): `embed_sparkle()` copies the framework from
the SPM artifact cache into `Contents/Frameworks/` (the binary finds it via an
`@rpath` linker flag in `Package.swift`); signing is **inside-out** (each Sparkle
XPC service, then the framework, then the app — never `codesign --deep`, which
breaks Sparkle's nested services; `Downloader.xpc` keeps its network-client
entitlement via `--preserve-metadata=entitlements`). After notarization the
script runs `generate_appcast`, and `./build-dmg.sh publish-appcast` pushes
`appcast.xml` + DMGs to gh-pages.

## Data retention

`TimeSeries` is a ring buffer capped at 3600 points (1 h at 1 s). Per-process CPU
sparkline history is capped at 60 samples and pruned for dead PIDs. Memory is bounded.
