#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LiteLLMTokenTracker"
APP_DIR="${HOME}/Applications/${APP_NAME}.app"
PLIST_PATH="${APP_DIR}/Contents/Info.plist"
MACOS_DIR="${APP_DIR}/Contents/MacOS"

mkdir -p "${HOME}/Applications"

swift build -c release --product "${APP_NAME}" --package-path "${ROOT_DIR}"
BUILD_DIR="$(swift build -c release --show-bin-path --package-path "${ROOT_DIR}")"
EXECUTABLE_PATH="${BUILD_DIR}/${APP_NAME}"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

cat > "${PLIST_PATH}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>LiteLLMTokenTracker</string>
	<key>CFBundleIdentifier</key>
	<string>app.litellm-token-tracker.local</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>LiteLLMTokenTracker</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

touch "${APP_DIR}"
open "${APP_DIR}"

printf 'Installed %s to %s\n' "${APP_NAME}" "${APP_DIR}"
