#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LiteLLMTokenTracker"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-macos.zip"

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "${cmd}" >&2
    exit 1
  }
}

require_cmd swift
require_cmd zip
require_cmd mktemp

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litellm-package.XXXXXX")"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

APP_DIR="${TMP_DIR}/${APP_NAME}.app"
PLIST_PATH="${APP_DIR}/Contents/Info.plist"
MACOS_DIR="${APP_DIR}/Contents/MacOS"

swift build -c release --product "${APP_NAME}" --package-path "${ROOT_DIR}"
BUILD_DIR="$(swift build -c release --show-bin-path --package-path "${ROOT_DIR}")"
EXECUTABLE_PATH="${BUILD_DIR}/${APP_NAME}"

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

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"
(
  cd "${TMP_DIR}"
  zip -qry "${ZIP_PATH}" "${APP_NAME}.app"
)

printf 'Packaged release archive: %s\n' "${ZIP_PATH}"
