# MacPerf — project notes

## Release runbook

1. Bump `VERSION` in `build-dmg.sh` and `build-pkg.sh` (via PR — never push main directly).
2. `MACPERF_NOTARY_PROFILE=traceview-notary ./build-dmg.sh` — builds, signs
   **inside-out** (never `codesign --deep`; it breaks Sparkle's nested XPC
   services), notarizes + staples the DMG, and generates `dist/appcast/appcast.xml`.
3. `gh release create v<X.Y.Z> dist/MacPerf-<X.Y.Z>.dmg --title "MacPerf v<X.Y.Z>" --notes '…'`
4. `./build-dmg.sh publish-appcast` — pushes `appcast.xml` + DMG to `gh-pages`.
   **This step is what delivers the update to installed apps** (Sparkle feed:
   `https://thefinder808.github.io/macperf/appcast.xml`); the GitHub release is
   only the manual-download channel.

The Sparkle EdDSA private key is the shared fleet key in the login keychain
(item "https://sparkle-project.org") — the same key TraceView and macpad use.
`generate_appcast` picks it up automatically.

## Before touching the update or render path

Read `docs/ARCHITECTURE.md` ("Efficiency model") first. The idle-when-hidden
gating and menu-bar label caching encode deliberate, easy-to-regress invariants:
`isUIVisible` must include the menu-bar panel (it's a borderless NSPanel, not a
window); the status-label dedup must keep its periodic self-heal re-apply; and
SF Symbol `NSImage`s must never be recreated per tick (CoreSVG leak).
