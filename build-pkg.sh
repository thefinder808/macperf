#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MacPerf"
BUNDLE_ID="com.macperf.app"
VERSION="1.2.1"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
PKG_UNSIGNED="${DIST_DIR}/${APP_NAME}-unsigned.pkg"
PKG_SIGNED="${DIST_DIR}/${APP_NAME}-${VERSION}.pkg"

# ─── Code signing config ─────────────────────────────────────────────────────
# Notary credentials live in the macOS keychain as a named profile, not in
# environment variables. One-time setup:
#   xcrun notarytool store-credentials macperf-notary
# (prompts interactively for Apple ID, Team ID, app-specific password)
NOTARY_PROFILE="${MACPERF_NOTARY_PROFILE:-macperf-notary}"

# Signing identities are auto-detected from the keychain. Override with the
# MACPERF_SIGN_APP / MACPERF_SIGN_PKG env vars if you have multiple Developer
# IDs and need to pick a specific one.
SIGN_APP="${MACPERF_SIGN_APP:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
SIGN_INSTALLER="${MACPERF_SIGN_PKG:-$(security find-identity -v -p basic 2>/dev/null | awk -F'"' '/Developer ID Installer/ {print $2; exit}')}"

# ─── Signing pre-flight ──────────────────────────────────────────────────────
# Refuse to silently build an unsigned pkg. For a local dev build without
# signing, set MACPERF_UNSIGNED=1 explicitly.
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    problems=()
    [ -z "${SIGN_APP}" ]       && problems+=("no 'Developer ID Application' identity in keychain")
    [ -z "${SIGN_INSTALLER}" ] && problems+=("no 'Developer ID Installer' identity in keychain")
    if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
        problems+=("notary keychain profile '${NOTARY_PROFILE}' missing — run: xcrun notarytool store-credentials ${NOTARY_PROFILE}")
    fi
    if [ "${#problems[@]}" -gt 0 ]; then
        echo "error: signing prerequisites not met:" >&2
        for p in "${problems[@]}"; do echo "       - $p" >&2; done
        echo "       (set MACPERF_UNSIGNED=1 for a local dev build instead)" >&2
        exit 1
    fi
fi

# ─── Build ───────────────────────────────────────────────────────────────────
echo "=== Building ${APP_NAME} v${VERSION} ==="

echo "Building release binary..."
swift build -c release

# ─── App Bundle ──────────────────────────────────────────────────────────────
echo "Creating app bundle..."
if [ -d "${DIST_DIR}" ]; then
    rm -rf "${DIST_DIR}" 2>/dev/null || sudo rm -rf "${DIST_DIR}"
fi
mkdir -p "${DIST_DIR}"
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

# ─── Code Signing ────────────────────────────────────────────────────────────
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Signing app bundle..."
    codesign --deep --force --options runtime \
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

# ─── Build .pkg ──────────────────────────────────────────────────────────────
echo ""
echo "Building installer package..."

COMPONENT_PKG="${DIST_DIR}/${APP_NAME}-component.pkg"

pkgbuild \
    --component "${APP_BUNDLE}" \
    --install-location "/Applications" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    "${COMPONENT_PKG}"

cat > "${DIST_DIR}/distribution.xml" << DIST
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>${APP_NAME}</title>
    <welcome mime-type="text/plain"><![CDATA[Welcome to the ${APP_NAME} installer.

${APP_NAME} is a native macOS performance monitor with real-time graphs for CPU, Memory, Disk, Network, GPU, and Thermal metrics.

Click Continue to install ${APP_NAME} to your Applications folder.]]></welcome>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="${BUNDLE_ID}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${BUNDLE_ID}" visible="false">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" onConclusion="none">${APP_NAME}-component.pkg</pkg-ref>
</installer-gui-script>
DIST

productbuild \
    --distribution "${DIST_DIR}/distribution.xml" \
    --package-path "${DIST_DIR}" \
    "${PKG_UNSIGNED}"

rm -f "${COMPONENT_PKG}" "${DIST_DIR}/distribution.xml"

# ─── Sign the .pkg ───────────────────────────────────────────────────────────
if [ -n "${SIGN_INSTALLER}" ]; then
    echo "Signing installer package..."
    productsign \
        --sign "${SIGN_INSTALLER}" \
        "${PKG_UNSIGNED}" \
        "${PKG_SIGNED}"
    rm -f "${PKG_UNSIGNED}"
    echo "  Package signature: OK"
else
    mv "${PKG_UNSIGNED}" "${PKG_SIGNED}"
    echo "Skipping package signing (no MACPERF_SIGN_PKG set)"
fi

# ─── Notarize ────────────────────────────────────────────────────────────────
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo ""
    echo "Submitting for notarization (profile: ${NOTARY_PROFILE})..."
    xcrun notarytool submit "${PKG_SIGNED}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "${PKG_SIGNED}"

    echo "Verifying notarization..."
    spctl --assess --type install --verbose "${PKG_SIGNED}"
    echo "  Notarization: OK"
else
    echo ""
    echo "Skipping notarization (MACPERF_UNSIGNED=1)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
echo "  App bundle: $(pwd)/${APP_BUNDLE}"
echo "  Installer:  $(pwd)/${PKG_SIGNED}"
echo "  App size:   $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo "  Pkg size:   $(du -sh "${PKG_SIGNED}" | cut -f1)"
if [ -z "${MACPERF_UNSIGNED:-}" ]; then
    echo "  Signed:     YES"
    echo "  Notarized:  YES"
else
    echo "  Signed:     NO (MACPERF_UNSIGNED=1 dev build)"
fi
echo ""
echo "To install pkg:     open ${PKG_SIGNED}"
echo "To run directly:    open ${APP_BUNDLE}"
echo ""

# ─── Local install option (for unsigned builds) ─────────────────────────────
if [ -n "${MACPERF_UNSIGNED:-}" ]; then
    read -p "Install directly to /Applications? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing to /Applications (may require password)..."
        if [ -d "/Applications/${APP_NAME}.app" ]; then
            sudo rm -rf "/Applications/${APP_NAME}.app"
        fi
        sudo cp -R "${APP_BUNDLE}" /Applications/
        sudo chmod -R 755 "/Applications/${APP_NAME}.app"
        sudo xattr -cr "/Applications/${APP_NAME}.app"
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/${APP_NAME}.app"
        echo "Installed to /Applications/${APP_NAME}.app"
    fi
fi
