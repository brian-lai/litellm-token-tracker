#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_SCRIPT="${ROOT_DIR}/scripts/package-release.sh"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_PATH="${DIST_DIR}/LiteLLMTokenTracker-macos.zip"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  local description="$2"
  [[ -f "${path}" ]] || fail "${description}: expected file ${path}"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local description="$3"
  [[ "${actual}" == "${expected}" ]] || fail "${description}: expected '${expected}', got '${actual}'"
}

[[ -x "${PACKAGE_SCRIPT}" ]] || fail "missing packaging script at ${PACKAGE_SCRIPT}"

rm -rf "${DIST_DIR}"
"${PACKAGE_SCRIPT}"

assert_file_exists "${ZIP_PATH}" "release zip missing"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litellm-package-test.XXXXXX")"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

unzip -q "${ZIP_PATH}" -d "${TMP_DIR}" || fail "unable to unzip release archive"
[[ -d "${TMP_DIR}/LiteLLMTokenTracker.app" ]] || fail "archive must contain LiteLLMTokenTracker.app at root"

top_entries=()
while IFS= read -r entry; do
  top_entries+=("${entry}")
done < <(zipinfo -1 "${ZIP_PATH}" | awk -F/ 'NF {print $1}' | sort -u)

assert_equals "${#top_entries[@]}" "1" "archive root entry count"
assert_equals "${top_entries[0]}" "LiteLLMTokenTracker.app" "archive root entry name"

printf 'PASS testPackageReleaseContract\n'
