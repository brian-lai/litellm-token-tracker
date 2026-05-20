#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="${ROOT_DIR}/scripts/install-release.sh"
FIXTURE_DIR="${ROOT_DIR}/scripts/fixtures/install-release"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "${haystack}" == *"${needle}"* ]] || fail "${label}: expected output to include '${needle}'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "${haystack}" != *"${needle}"* ]] || fail "${label}: output unexpectedly included '${needle}'"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  [[ "${actual}" == "${expected}" ]] || fail "${label}: expected '${expected}', got '${actual}'"
}

assert_file_exists() {
  local path="$1"
  local label="$2"
  [[ -f "${path}" ]] || fail "${label}: expected file ${path}"
}

assert_dir_exists() {
  local path="$1"
  local label="$2"
  [[ -d "${path}" ]] || fail "${label}: expected directory ${path}"
}

[[ -x "${INSTALL_SCRIPT}" ]] || fail "missing installer script at ${INSTALL_SCRIPT}"

make_test_bundle_zip() {
  local zip_path="$1"
  local bundle_name="$2"
  local tmp_dir="$3"
  local app_dir="${tmp_dir}/${bundle_name}"

  mkdir -p "${app_dir}/Contents/MacOS"
  cat > "${app_dir}/Contents/MacOS/LiteLLMTokenTracker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod 755 "${app_dir}/Contents/MacOS/LiteLLMTokenTracker"
  (
    cd "${tmp_dir}"
    zip -qry "${zip_path}" "${bundle_name}"
  )
}

run_installer_case() {
  local case_name="$1"
  local metadata_fixture="$2"
  local asset_zip_mode="$3"
  local open_exit="$4"
  local disable_python3="$5"
  local expect_exit="$6"
  local expect_contains="$7"
  local use_default_metadata_url="${8:-0}"

  local case_dir
  case_dir="$(mktemp -d "${TMPDIR:-/tmp}/litellm-install-test-${case_name}.XXXXXX")"
  local app_home="${case_dir}/home"
  local mock_bin="${case_dir}/mock-bin"
  local work_dir="${case_dir}/work"
  mkdir -p "${app_home}/Applications" "${mock_bin}" "${work_dir}" "${case_dir}/fixtures"

  local metadata_path="${FIXTURE_DIR}/${metadata_fixture}"
  local success_template="${FIXTURE_DIR}/release-success.json"
  local resolved_metadata="${case_dir}/fixtures/release.json"
  local asset_zip_path="${case_dir}/fixtures/LiteLLMTokenTracker-macos.zip"
  local bad_zip_path="${case_dir}/fixtures/not-a-zip.zip"
  local metadata_url="https://api.github.com/repos/brian-lai/litellm_token_tracker/releases/latest"
  local asset_url="https://download.example.invalid/LiteLLMTokenTracker-macos.zip"
  local existing_marker="${app_home}/Applications/LiteLLMTokenTracker.app/existing.txt"
  local out_file="${case_dir}/out.log"

  if [[ "${metadata_fixture}" == "release-success.json" ]]; then
    sed "s#__ASSET_URL__#${asset_url}#g" "${success_template}" > "${resolved_metadata}"
  else
    cp "${metadata_path}" "${resolved_metadata}"
  fi

  case "${asset_zip_mode}" in
    good)
      make_test_bundle_zip "${asset_zip_path}" "LiteLLMTokenTracker.app" "${case_dir}/fixtures"
      ;;
    missing_bundle)
      make_test_bundle_zip "${asset_zip_path}" "WrongName.app" "${case_dir}/fixtures"
      ;;
    bad_zip)
      printf 'not-a-zip\n' > "${bad_zip_path}"
      ;;
  esac

  mkdir -p "${app_home}/Applications/LiteLLMTokenTracker.app"
  printf 'legacy\n' > "${existing_marker}"

  cat > "${mock_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out_file=""
url=""
while (($#)); do
  case "$1" in
    -o)
      out_file="$2"
      shift 2
      ;;
    -f|-s|-S|-L|-fsSL)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ "${url}" == "${MOCK_RELEASE_METADATA_URL}" ]]; then
  if [[ -n "${out_file}" ]]; then
    cp "${MOCK_RELEASE_METADATA_PATH}" "${out_file}"
  else
    cat "${MOCK_RELEASE_METADATA_PATH}"
  fi
  exit 0
fi

if [[ "${url}" == "${MOCK_RELEASE_ASSET_URL}" ]]; then
  if [[ "${MOCK_ASSET_MODE}" == "bad_zip" ]]; then
    cp "${MOCK_BAD_ZIP_PATH}" "${out_file}"
  else
    cp "${MOCK_RELEASE_ASSET_PATH}" "${out_file}"
  fi
  exit 0
fi

printf 'unexpected curl URL: %s\n' "${url}" >&2
exit 1
EOF
  chmod 755 "${mock_bin}/curl"

  cat > "${mock_bin}/open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit "${MOCK_OPEN_EXIT}"
EOF
  chmod 755 "${mock_bin}/open"

  local run_path="${mock_bin}:/usr/bin:/bin:/usr/sbin:/sbin"
  if [[ "${disable_python3}" == "1" ]]; then
    run_path="${mock_bin}:/bin:/usr/sbin:/sbin"
  fi

  set +e
  if [[ "${use_default_metadata_url}" == "1" ]]; then
    (
      cd "${work_dir}"
      HOME="${app_home}" \
      PATH="${run_path}" \
      MOCK_RELEASE_METADATA_URL="${metadata_url}" \
      MOCK_RELEASE_METADATA_PATH="${resolved_metadata}" \
      MOCK_RELEASE_ASSET_URL="${asset_url}" \
      MOCK_RELEASE_ASSET_PATH="${asset_zip_path}" \
      MOCK_BAD_ZIP_PATH="${bad_zip_path}" \
      MOCK_ASSET_MODE="${asset_zip_mode}" \
      MOCK_OPEN_EXIT="${open_exit}" \
      "${INSTALL_SCRIPT}"
    ) >"${out_file}" 2>&1
  else
    (
      cd "${work_dir}"
      HOME="${app_home}" \
      PATH="${run_path}" \
      MOCK_RELEASE_METADATA_URL="${metadata_url}" \
      MOCK_RELEASE_METADATA_PATH="${resolved_metadata}" \
      MOCK_RELEASE_ASSET_URL="${asset_url}" \
      MOCK_RELEASE_ASSET_PATH="${asset_zip_path}" \
      MOCK_BAD_ZIP_PATH="${bad_zip_path}" \
      MOCK_ASSET_MODE="${asset_zip_mode}" \
      MOCK_OPEN_EXIT="${open_exit}" \
      RELEASE_METADATA_URL="${metadata_url}" \
      RELEASE_REPO="brian-lai/litellm_token_tracker" \
      "${INSTALL_SCRIPT}"
    ) >"${out_file}" 2>&1
  fi
  local exit_code=$?
  set -e

  local output
  output="$(cat "${out_file}")"
  assert_equals "${exit_code}" "${expect_exit}" "${case_name} exit code"
  assert_contains "${output}" "${expect_contains}" "${case_name} output"

  if [[ "${case_name}" == "success" ]]; then
    assert_dir_exists "${app_home}/Applications/LiteLLMTokenTracker.app" "${case_name} install dir"
    assert_file_exists "${app_home}/Applications/LiteLLMTokenTracker.app/Contents/MacOS/LiteLLMTokenTracker" "${case_name} executable"
    assert_not_contains "${output}" "existing.txt" "${case_name} output safety"
  fi

  if [[ "${case_name}" == "replace_existing_app" ]]; then
    [[ ! -f "${existing_marker}" ]] || fail "${case_name}: existing app marker should be replaced"
    assert_file_exists "${app_home}/Applications/LiteLLMTokenTracker.app/Contents/MacOS/LiteLLMTokenTracker" "${case_name} executable"
  fi

  rm -rf "${case_dir}"
}

run_installer_case "success" "release-success.json" "good" "0" "0" "0" "Installed LiteLLMTokenTracker.app"
run_installer_case "missing_asset" "release-missing-asset.json" "good" "0" "0" "1" "LiteLLMTokenTracker-macos.zip"
run_installer_case "bad_metadata" "release-bad-metadata.json" "good" "0" "0" "1" "release metadata"
run_installer_case "bad_zip" "release-success.json" "bad_zip" "0" "0" "1" "unzip"
run_installer_case "missing_bundle" "release-success.json" "missing_bundle" "0" "0" "1" "LiteLLMTokenTracker.app"
run_installer_case "missing_python3" "release-success.json" "good" "0" "1" "1" "required command not found: python3"
run_installer_case "replace_existing_app" "release-success.json" "good" "0" "0" "0" "Installed LiteLLMTokenTracker.app"
run_installer_case "launch_failure" "release-success.json" "good" "1" "0" "1" "launch"
run_installer_case "default_metadata_url" "release-success.json" "good" "0" "0" "0" "Installed LiteLLMTokenTracker.app" "1"

printf 'PASS testInstallReleaseContract\n'
