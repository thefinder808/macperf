#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="MacPerf"
BUNDLE_ID="com.macperf.app"
VERSION="1.0.1"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
PKG_UNSIGNED="${DIST_DIR}/${APP_NAME}-unsigned.pkg"
PKG_SIGNED="${DIST_DIR}/${APP_NAME}-${VERSION}.pkg"

# Code signing identity — set these when you have an Apple Developer ID
# Leave empty to skip signing/notarization (local dev builds)
SIGN_APP="${MACPERF_SIGN_APP:-}"           # "Developer ID Application: Your Name (TEAMID)"
SIGN_INSTALLER="${MACPERF_SIGN_PKG:-}"     # "Developer ID Installer: Your Name (TEAMID)"
APPLE_ID="${MACPERF_APPLE_ID:-}"           # your@email.com
TEAM_ID="${MACPERF_TEAM_ID:-}"             # 10-char team ID
APP_PASSWORD="${MACPERF_APP_PASSWORD:-}"   # app-specific password from appleid.apple.com

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
if [ -n "${SIGN_APP}" ]; then
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
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

    echo "Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
    echo "  Signature: OK"
else
    echo ""
    echo "Skipping code signing (no MACPERF_SIGN_APP set)"
    echo "  To enable, export these env vars before running:"
    echo "    export MACPERF_SIGN_APP=\"Developer ID Application: Your Name (TEAMID)\""
    echo "    export MACPERF_SIGN_PKG=\"Developer ID Installer: Your Name (TEAMID)\""
    echo "    export MACPERF_APPLE_ID=\"you@email.com\""
    echo "    export MACPERF_TEAM_ID=\"TEAMID\""
    echo "    export MACPERF_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
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
if [ -n "${SIGN_APP}" ] && [ -n "${APPLE_ID}" ] && [ -n "${TEAM_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
    echo ""
    echo "Submitting for notarization..."
    xcrun notarytool submit "${PKG_SIGNED}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${TEAM_ID}" \
        --password "${APP_PASSWORD}" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "${PKG_SIGNED}"

    echo "Verifying notarization..."
    spctl --assess --type install --verbose "${PKG_SIGNED}"
    echo "  Notarization: OK"
else
    echo ""
    echo "Skipping notarization (credentials not set)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
echo "  App bundle: $(pwd)/${APP_BUNDLE}"
echo "  Installer:  $(pwd)/${PKG_SIGNED}"
echo "  App size:   $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo "  Pkg size:   $(du -sh "${PKG_SIGNED}" | cut -f1)"
if [ -n "${SIGN_APP}" ]; then
    echo "  Signed:     YES"
    echo "  Notarized:  $([ -n "${APPLE_ID}" ] && echo 'YES' || echo 'NO')"
else
    echo "  Signed:     NO (local dev build)"
fi
echo ""
echo "To install pkg:     open ${PKG_SIGNED}"
echo "To run directly:    open ${APP_BUNDLE}"
echo ""

# ─── Local install option (for unsigned builds) ─────────────────────────────
if [ -z "${SIGN_APP}" ]; then
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
