#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MacPerf"
BUNDLE_ID="com.macperf.app"
VERSION="1.0.2"
BUILD_DIR=".build/release"
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

echo "Building release binary..."
swift build -c release

# ─── App Bundle ──────────────────────────────────────────────────────────────
echo "Creating app bundle..."
if [ -d "${DIST_DIR}" ]; then
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

# Verify
echo "Verifying app bundle..."
[ -f "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ] && echo "  Binary: OK" || { echo "  Binary: MISSING"; exit 1; }
[ -f "${APP_BUNDLE}/Contents/Info.plist" ] && echo "  Info.plist: OK" || { echo "  Info.plist: MISSING"; exit 1; }

# ─── Code Signing (app) ──────────────────────────────────────────────────────
# The .app must be signed with the hardened runtime and a secure timestamp
# before it goes into the DMG, otherwise notarization is rejected.
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Signing app bundle..."
    codesign --deep --force --options runtime --timestamp \
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
    echo "Skipping code signing (MACPERF_UNSIGNED=1 — local dev build)"
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

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
echo "  App bundle: $(pwd)/${APP_BUNDLE}"
echo "  Disk image: $(pwd)/${DMG_PATH}"
echo "  DMG size:   $(du -sh "${DMG_PATH}" | cut -f1)"
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo "  Signed:     YES"
    echo "  Notarized:  YES (stapled)"
else
    echo "  Signed:     NO (MACPERF_UNSIGNED=1 dev build)"
fi
echo ""
echo "To mount:    open ${DMG_PATH}"
echo "To run app:  open ${APP_BUNDLE}"
echo ""
