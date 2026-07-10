#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MacPerf"
BUNDLE_ID="com.macperf.app"
VERSION="1.2.0"
# Universal (arm64 + x86_64) builds land under .build/apple/Products/Release —
# NOT .build/release (that symlink stays single-arch). The README promises
# Intel support and ThermalMonitor carries Intel SMC fallbacks, so ship both.
BUILD_DIR=".build/apple/Products/Release"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="${DIST_DIR}/dmg-staging"
VOL_NAME="${APP_NAME} ${VERSION}"

# Notary credentials live in the macOS keychain as a named profile. One-time setup:
#   xcrun notarytool store-credentials macperf-notary
# (prompts interactively for Apple ID, Team ID, app-specific password)
NOTARY_PROFILE="${MACPERF_NOTARY_PROFILE:-macperf-notary}"

# A DMG is signed with the "Developer ID Application" identity (the same one that
# signs the .app). It does NOT need a "Developer ID Installer" cert — that is only
# required for .pkg installers. Auto-detected from the keychain; override with
# MACPERF_SIGN_APP if you have multiple Developer IDs.
SIGN_APP="${MACPERF_SIGN_APP:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"

# Sparkle auto-update. The appcast feed + signed DMGs are published to the
# public gh-pages branch (MacPerf's repo is public); enclosures live under
# /releases/.
SU_FEED_URL="https://thefinder808.github.io/macperf/appcast.xml"
# generate_appcast emits flat URLs; this prefix must match where
# publish-appcast actually places the DMGs (/releases/) or Sparkle reports
# "no update" with a silent 404 from GitHub Pages.
SU_DOWNLOAD_URL_PREFIX="https://thefinder808.github.io/macperf/releases/"
# EdDSA public key. This is the SHARED fleet key — the same Sparkle key used by
# TraceView and macpad (private key lives once in the login Keychain as
# "https://sparkle-project.org"; never lose it — it signs every future update).
# generate_appcast signs the DMG with that private key automatically. To rotate
# or mint a dedicated key: .build/artifacts/sparkle/Sparkle/bin/generate_keys
# Override via env: SU_PUBLIC_ED_KEY="…" ./build-dmg.sh
SU_PUBLIC_ED_KEY="${SU_PUBLIC_ED_KEY:-OkisT+RinXia2GCpnFmXZ2ArHab4lYWXa9LPg4IsGoM=}"

# ─── Sparkle helpers ─────────────────────────────────────────────────────────

embed_sparkle() {
    # Copy Sparkle.framework from the SwiftPM artifact cache into the .app.
    # SPM extracts the XCFramework under .build/artifacts/sparkle/Sparkle/
    # Sparkle.xcframework/<slice>/Sparkle.framework. Skip the /index-build/
    # mirror (that copy is SourceKit's, not for shipping).
    local sparkle_src
    sparkle_src=$(find .build/artifacts -type d -name 'Sparkle.framework' 2>/dev/null \
                  | grep -v '/index-build/' | head -1)
    if [[ -z "$sparkle_src" || ! -d "$sparkle_src" ]]; then
        echo "✗ Sparkle.framework not found under .build/artifacts/."
        echo "  Run 'swift package resolve' to fetch it, then retry."
        exit 1
    fi
    mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
    rm -rf "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
    cp -R "$sparkle_src" "${APP_BUNDLE}/Contents/Frameworks/"
}

sign_sparkle_components() {
    # Sign the .app INSIDE-OUT. NEVER use `codesign --deep` with Sparkle
    # embedded — it signs Sparkle's nested XPC services in the wrong order /
    # with the wrong entitlements and breaks auto-update. Sign each Sparkle
    # component, then the framework; the .app itself is signed after.
    # Downloader.xpc ships com.apple.security.network.client;
    # --preserve-metadata=entitlements keeps it when re-signing with
    # Developer ID (strip it → downloads fail silently).
    local sparkle_versions="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"
    [ -d "$sparkle_versions" ] || return 0

    local cs=(--force --sign "$SIGN_APP" --options runtime --timestamp)
    codesign "${cs[@]}" "${sparkle_versions}/XPCServices/Installer.xpc"
    codesign "${cs[@]}" --preserve-metadata=entitlements "${sparkle_versions}/XPCServices/Downloader.xpc"
    codesign "${cs[@]}" "${sparkle_versions}/Autoupdate"
    codesign "${cs[@]}" "${sparkle_versions}/Updater.app"
    codesign "${cs[@]}" "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
}

adhoc_sign_sparkle_components() {
    # Unsigned/dev builds still need ad-hoc signatures on the Sparkle bits or
    # the app won't launch (library validation rejects unsigned frameworks).
    local sparkle_versions="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"
    [ -d "$sparkle_versions" ] || return 0
    codesign --force --sign - "${sparkle_versions}/XPCServices/Installer.xpc" >/dev/null 2>&1 || true
    codesign --force --sign - "${sparkle_versions}/XPCServices/Downloader.xpc" >/dev/null 2>&1 || true
    codesign --force --sign - "${sparkle_versions}/Autoupdate" >/dev/null 2>&1 || true
    codesign --force --sign - "${sparkle_versions}/Updater.app" >/dev/null 2>&1 || true
    codesign --force --sign - "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" >/dev/null 2>&1 || true
    codesign --force --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true
}

ensure_gh_pages_worktree() {
    # (Re)create a clean worktree for the gh-pages branch at $1. Robust to a
    # stale/orphaned registration left by a prior publish (or the dist/ wipe):
    # rm -rf'ing the dir without deregistering makes a later `git worktree add`
    # fail with "missing but already registered", so remove + prune first.
    local wt="$1"
    git worktree remove --force "$wt" 2>/dev/null || true
    rm -rf "$wt"
    git worktree prune
    git worktree add -f "$wt" gh-pages 2>/dev/null \
        || { git fetch origin gh-pages && git worktree add -f "$wt" gh-pages; }
}

generate_appcast_for_release() {
    # Stage the new DMG alongside prior releases pulled from gh-pages, then run
    # generate_appcast against the combined folder (it emits delta updates vs
    # prior versions). Output: dist/appcast/{appcast.xml,*.dmg,*.delta}.
    local new_dmg="$1"
    local appcast_dir="${DIST_DIR}/appcast"
    local gh_pages_wt="${DIST_DIR}/gh-pages"
    local generate_appcast
    generate_appcast=$(find .build/artifacts -type f -name generate_appcast 2>/dev/null \
                       | grep -v '/index-build/' | head -1)
    if [[ -z "$generate_appcast" || ! -x "$generate_appcast" ]]; then
        echo "✗ generate_appcast not found under .build/artifacts — run 'swift package resolve'."
        exit 1
    fi

    rm -rf "$appcast_dir"
    mkdir -p "$appcast_dir"
    cp "$new_dmg" "$appcast_dir/"

    # Pull prior releases from gh-pages so generate_appcast can build deltas.
    # No-op on the first release (branch doesn't exist yet).
    if git show-ref --verify --quiet refs/remotes/origin/gh-pages \
       || git show-ref --verify --quiet refs/heads/gh-pages; then
        ensure_gh_pages_worktree "$gh_pages_wt"
        if [[ -d "${gh_pages_wt}/releases" ]]; then
            cp -R "${gh_pages_wt}/releases/." "$appcast_dir/" 2>/dev/null || true
        fi
    else
        echo "  (no gh-pages branch yet — generating the initial appcast only)"
    fi

    "$generate_appcast" --download-url-prefix "$SU_DOWNLOAD_URL_PREFIX" "$appcast_dir"
    echo "✓ Appcast at ${appcast_dir}/appcast.xml"
}

publish_appcast() {
    # Copy appcast.xml (root) + DMGs/deltas (releases/) onto the gh-pages
    # worktree, commit, push. Kept separate from the build so re-building
    # doesn't touch the public feed. Sparkle URLs in the appcast are relative
    # to SU_DOWNLOAD_URL_PREFIX, so the DMGs MUST land under releases/.
    local appcast_dir="${DIST_DIR}/appcast"
    local gh_pages_wt="${DIST_DIR}/gh-pages"

    if [[ ! -f "${appcast_dir}/appcast.xml" ]]; then
        echo "✗ No appcast at ${appcast_dir}/appcast.xml — run './build-dmg.sh' first."
        exit 1
    fi
    ensure_gh_pages_worktree "$gh_pages_wt"

    mkdir -p "${gh_pages_wt}/releases"
    cp "${appcast_dir}/appcast.xml" "${gh_pages_wt}/appcast.xml"
    find "$appcast_dir" -maxdepth 1 -type f \( -name '*.dmg' -o -name '*.delta' \) \
        -exec cp {} "${gh_pages_wt}/releases/" \;

    (
        cd "$gh_pages_wt"
        git add appcast.xml releases/
        if git diff --cached --quiet; then
            echo "✓ Nothing to publish — appcast already current."
        else
            git commit -m "Publish appcast for v${VERSION}"
            git push origin gh-pages
            echo "✓ Appcast published to ${SU_FEED_URL}"
        fi
    )
}

# ─── Subcommands ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "publish-appcast" ]]; then
    publish_appcast
    exit 0
fi

# ─── Signing pre-flight ──────────────────────────────────────────────────────
# Refuse to silently build an unsigned DMG. For a local unsigned build, set
# MACPERF_UNSIGNED=1 explicitly.
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    problems=()
    [ -z "${SIGN_APP}" ] && problems+=("no 'Developer ID Application' identity in keychain")
    if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
        problems+=("notary keychain profile '${NOTARY_PROFILE}' missing — run: xcrun notarytool store-credentials ${NOTARY_PROFILE}")
    fi
    if [ "${#problems[@]}" -gt 0 ]; then
        echo "error: signing prerequisites not met:" >&2
        for p in "${problems[@]}"; do echo "       - $p" >&2; done
        echo "       (set MACPERF_UNSIGNED=1 for an unsigned local DMG instead)" >&2
        exit 1
    fi
fi

# ─── Build ───────────────────────────────────────────────────────────────────
echo "=== Building ${APP_NAME} v${VERSION} disk image ==="

echo "Building universal release binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64
lipo -archs "${BUILD_DIR}/${APP_NAME}" | grep -q "x86_64 arm64" \
    || { echo "✗ binary is not universal: $(lipo -archs "${BUILD_DIR}/${APP_NAME}")"; exit 1; }

# ─── App Bundle ──────────────────────────────────────────────────────────────
echo "Creating app bundle..."
if [ -d "${DIST_DIR}" ]; then
    git worktree remove --force "${DIST_DIR}/gh-pages" 2>/dev/null || true
    git worktree prune
    rm -rf "${DIST_DIR}" 2>/dev/null || sudo rm -rf "${DIST_DIR}"
fi
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>SUFeedURL</key>
    <string>${SU_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SU_PUBLIC_ED_KEY}</string>
</dict>
</plist>
PLIST

# Copy app icon
if [ -f "MacPerf.icns" ]; then
    cp "MacPerf.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "  Icon: OK"
else
    echo "  Icon: MISSING (MacPerf.icns not found, build will have no icon)"
fi

echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Embed Sparkle.framework (the binary looks it up via @rpath — see Package.swift)
echo "Embedding Sparkle.framework..."
embed_sparkle

# Verify
echo "Verifying app bundle..."
[ -f "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ] && echo "  Binary: OK" || { echo "  Binary: MISSING"; exit 1; }
[ -f "${APP_BUNDLE}/Contents/Info.plist" ] && echo "  Info.plist: OK" || { echo "  Info.plist: MISSING"; exit 1; }
[ -d "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" ] && echo "  Sparkle: OK" || { echo "  Sparkle: MISSING"; exit 1; }

# ─── Code Signing (app) ──────────────────────────────────────────────────────
# The .app must be signed with the hardened runtime and a secure timestamp
# before it goes into the DMG, otherwise notarization is rejected. Signed
# inside-out (Sparkle components first, app last) — never --deep.
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Signing app bundle..."
    sign_sparkle_components
    codesign --force --options runtime --timestamp \
        --sign "${SIGN_APP}" \
        --entitlements /dev/stdin \
        "${APP_BUNDLE}" << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
ENTITLEMENTS

    echo "Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
    echo "  Signature: OK"
else
    echo ""
    echo "Skipping Developer ID signing (MACPERF_UNSIGNED=1 — ad-hoc signing dev build)"
    adhoc_sign_sparkle_components
fi

# ─── Build DMG ───────────────────────────────────────────────────────────────
# create-dmg handles the disk image layout (Applications drop-link), and with
# --codesign / --notarize it signs the .dmg, submits it for notarization, waits,
# and staples the ticket — all in one call.
echo ""
echo "Building disk image..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

dmg_args=(
    --volname "${VOL_NAME}"
    --window-pos 200 120
    --window-size 540 380
    --icon-size 110
    --icon "${APP_NAME}.app" 150 190
    --app-drop-link 390 190
    --hide-extension "${APP_NAME}.app"
    --no-internet-enable
)
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    dmg_args+=(--codesign "${SIGN_APP}" --notarize "${NOTARY_PROFILE}")
fi

rm -f "${DMG_PATH}"
create-dmg "${dmg_args[@]}" "${DMG_PATH}" "${STAGING_DIR}"
rm -rf "${STAGING_DIR}"

# ─── Verify ──────────────────────────────────────────────────────────────────
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Verifying stapled notarization ticket..."
    xcrun stapler validate "${DMG_PATH}"
    spctl --assess --type open --context context:primary-signature --verbose "${DMG_PATH}" || true
    echo "  Notarization: OK"
fi

# ─── Sparkle appcast ─────────────────────────────────────────────────────────
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Generating Sparkle appcast (diffs against prior gh-pages releases)..."
    generate_appcast_for_release "${DMG_PATH}"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
echo "  App bundle: $(pwd)/${APP_BUNDLE}"
echo "  Disk image: $(pwd)/${DMG_PATH}"
echo "  DMG size:   $(du -sh "${DMG_PATH}" | cut -f1)"
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo "  Signed:     YES"
    echo "  Notarized:  YES (stapled)"
    echo ""
    echo "Next steps:"
    echo "  1. gh release create v${VERSION} ${DMG_PATH} --notes '…'"
    echo "  2. ./build-dmg.sh publish-appcast    # push appcast.xml + DMG to gh-pages"
else
    echo "  Signed:     NO (MACPERF_UNSIGNED=1 dev build, ad-hoc only)"
fi
echo ""
echo "To mount:    open ${DMG_PATH}"
echo "To run app:  open ${APP_BUNDLE}"
echo ""
