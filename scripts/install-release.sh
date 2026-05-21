#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LiteLLMTokenTracker"
ASSET_NAME="${APP_NAME}-macos.zip"
RELEASE_REPO="${RELEASE_REPO:-brian-lai/litellm_token_tracker}"
RELEASE_METADATA_URL="${RELEASE_METADATA_URL:-https://api.github.com/repos/${RELEASE_REPO}/releases/latest}"
APP_BUNDLE="${APP_NAME}.app"
USER_INSTALL_DIR="${HOME}/Applications"
SYSTEM_INSTALL_DIR="${SYSTEM_APPLICATIONS_DIR:-/Applications}"
USER_INSTALL_PATH="${USER_INSTALL_DIR}/${APP_BUNDLE}"
SYSTEM_INSTALL_PATH="${SYSTEM_INSTALL_DIR}/${APP_BUNDLE}"

note() {
  printf 'INFO: %s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "required command not found: ${cmd}"
}

require_cmd curl
require_cmd python3
require_cmd unzip
require_cmd mktemp
require_cmd open

resolve_install_path() {
  if [[ -d "${USER_INSTALL_PATH}" ]]; then
    printf '%s\n' "${USER_INSTALL_PATH}"
    return 0
  fi

  if [[ -d "${SYSTEM_INSTALL_PATH}" ]]; then
    if [[ -w "${SYSTEM_INSTALL_DIR}" || -w "${SYSTEM_INSTALL_PATH}" ]]; then
      printf '%s\n' "${SYSTEM_INSTALL_PATH}"
      return 0
    fi
    note "found existing app at ${SYSTEM_INSTALL_PATH} but it is not writable; installing to ${USER_INSTALL_PATH} instead"
  fi

  printf '%s\n' "${USER_INSTALL_PATH}"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litellm-install-release.XXXXXX")"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

METADATA_PATH="${TMP_DIR}/release.json"
ZIP_PATH="${TMP_DIR}/${ASSET_NAME}"
EXTRACT_DIR="${TMP_DIR}/extract"

if ! curl -fsSL "${RELEASE_METADATA_URL}" >"${METADATA_PATH}"; then
  fail "failed to fetch release metadata from ${RELEASE_METADATA_URL}"
fi

ASSET_URL="$(
  python3 - "${METADATA_PATH}" "${ASSET_NAME}" <<'PY'
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
asset_name = sys.argv[2]

try:
    payload = json.loads(metadata_path.read_text())
except Exception:
    print("failed to parse release metadata", file=sys.stderr)
    sys.exit(2)

for asset in payload.get("assets", []):
    if asset.get("name") == asset_name and asset.get("browser_download_url"):
        print(asset["browser_download_url"])
        sys.exit(0)

print(f"missing release asset: {asset_name}", file=sys.stderr)
sys.exit(3)
PY
)" || fail "failed to resolve asset URL from release metadata for ${ASSET_NAME}"

if ! curl -fsSL "${ASSET_URL}" -o "${ZIP_PATH}"; then
  fail "failed to download release asset from ${ASSET_URL}"
fi

mkdir -p "${EXTRACT_DIR}"
if ! unzip -q "${ZIP_PATH}" -d "${EXTRACT_DIR}"; then
  fail "unzip failed for ${ASSET_NAME}"
fi

EXTRACTED_APP="${EXTRACT_DIR}/${APP_NAME}.app"
[[ -d "${EXTRACTED_APP}" ]] || fail "archive missing expected app bundle: ${APP_NAME}.app"

INSTALL_PATH="$(resolve_install_path)"
INSTALL_DIR="$(dirname "${INSTALL_PATH}")"
mkdir -p "${INSTALL_DIR}"
rm -rf "${INSTALL_PATH}"
mv "${EXTRACTED_APP}" "${INSTALL_PATH}"

if ! open "${INSTALL_PATH}"; then
  fail "launch failed for ${INSTALL_PATH}"
fi

printf 'Installed %s.app to %s\n' "${APP_NAME}" "${INSTALL_PATH}"
