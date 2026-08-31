#!/usr/bin/env bash
#
#  build-app.sh
#  Stella
#
#  Created by euijjang97 on 4/29/26.
#

# Wraps the SwiftPM `stella` executable into a macOS .app bundle.
#
# Output: dist/Stella.app
#
# Usage:
#   scripts/build-app.sh [--no-build]

set -euo pipefail

cd "$(dirname "$0")/.."

APP_DISPLAY_NAME="Stella"
EXEC_PRODUCT="stella"
BUNDLE_ID="com.umc.stella"
APP_VERSION="0.1.0"
RESOURCE_BUNDLE="Stella_StellaApp.bundle"
ICON_SOURCE="Sources/StellaApp/Resources/AppIcon.png"

DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_DISPLAY_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

if [[ "${1:-}" != "--no-build" ]]; then
    echo "▶︎ swift build -c release --product ${EXEC_PRODUCT}"
    swift build -c release --product "${EXEC_PRODUCT}"
fi

BUILD_DIR=".build/release"
if [[ ! -x "${BUILD_DIR}/${EXEC_PRODUCT}" ]]; then
    echo "❌ ${BUILD_DIR}/${EXEC_PRODUCT} not found — run without --no-build first"
    exit 1
fi

echo "▶︎ resetting ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

echo "▶︎ copying executable + resource bundle"
cp "${BUILD_DIR}/${EXEC_PRODUCT}" "${MACOS}/${EXEC_PRODUCT}"
chmod +x "${MACOS}/${EXEC_PRODUCT}"
if [[ -d "${BUILD_DIR}/${RESOURCE_BUNDLE}" ]]; then
    cp -R "${BUILD_DIR}/${RESOURCE_BUNDLE}" "${RESOURCES}/${RESOURCE_BUNDLE}"
fi

echo "▶︎ masking ${ICON_SOURCE} into macOS squircle"
WORK_DIR="$(mktemp -d)"
MASKED_ICON="${WORK_DIR}/AppIcon-masked.png"
swift scripts/mask-icon.swift "${ICON_SOURCE}" "${MASKED_ICON}"

echo "▶︎ generating AppIcon.icns"
ICONSET_DIR="${WORK_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"
for spec in \
    "16:icon_16x16" \
    "32:icon_16x16@2x" \
    "32:icon_32x32" \
    "64:icon_32x32@2x" \
    "128:icon_128x128" \
    "256:icon_128x128@2x" \
    "256:icon_256x256" \
    "512:icon_256x256@2x" \
    "512:icon_512x512" \
    "1024:icon_512x512@2x"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    sips -z "${size}" "${size}" "${MASKED_ICON}" --out "${ICONSET_DIR}/${name}.png" >/dev/null
done
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES}/AppIcon.icns"
rm -rf "${WORK_DIR}"

echo "▶︎ writing Info.plist"
cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXEC_PRODUCT}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▶︎ ad-hoc codesign"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null

echo
echo "✅ ${APP_DIR}"
du -sh "${APP_DIR}" | awk '{print "   size: " $1}'
echo "   open with: open \"${APP_DIR}\""
