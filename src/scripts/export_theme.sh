#!/usr/bin/env bash
# Save the live Wayle install as a new theme in this checkout.
# Inverse of load_theme: ~/.config/wayle/config.toml and
# ~/.config/wayle/styles/index.scss become
# themes/wayle/<name>/config.toml and style.css.
# The name is stored in .una_asahi_setup.json so `una sync` tracks it.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

REPO_THEMES_DIR="${ASAHI_SETUP_ROOT}/themes/wayle"
WAYLE_DIR="${HOME}/.config/wayle"
LIVE_CONFIG="${WAYLE_DIR}/config.toml"
LIVE_STYLES="${WAYLE_DIR}/styles/index.scss"
GUI_THEMES_DIR="${WAYLE_DIR}/themes"
WAYLE_THEME_PY="${_ASAHI_SETUP_SCRIPTS_DIR}/_wayle_theme.py"

usage() {
  echo "Usage: una export theme <name>" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage

THEME_NAME="$1"
if [[ ! "${THEME_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
  echo "error: invalid theme name '${THEME_NAME}'" >&2
  echo "use letters, digits, '_' and '-', starting with a letter or digit" >&2
  exit 1
fi

if [[ ! -f "${LIVE_CONFIG}" ]]; then
  echo "error: no live Wayle config at ${LIVE_CONFIG}" >&2
  exit 1
fi
if [[ ! -f "${LIVE_STYLES}" ]]; then
  echo "error: no live Wayle styles at ${LIVE_STYLES}" >&2
  exit 1
fi

DEST_DIR="${REPO_THEMES_DIR}/${THEME_NAME}"
if [[ -e "${DEST_DIR}" ]]; then
  echo "error: theme '${THEME_NAME}' already exists at ${DEST_DIR}" >&2
  exit 1
fi

mkdir -p "${REPO_THEMES_DIR}"
stage="$(mktemp -d "${REPO_THEMES_DIR}/.export.XXXXXX")"
cleanup_stage() {
  rm -rf "${stage}"
}
trap cleanup_stage EXIT
cp --preserve=mode -- "${LIVE_CONFIG}" "${stage}/config.toml"
cp --preserve=mode -- "${LIVE_STYLES}" "${stage}/style.css"
mv "${stage}" "${DEST_DIR}"
trap - EXIT

python3 "${RUN_LOG_PY}" set-theme "${RUN_LOG_FILE}" "${THEME_NAME}"

mkdir -p "${GUI_THEMES_DIR}"
if ! python3 "${WAYLE_THEME_PY}" extract-palette "${DEST_DIR}/config.toml" \
  "${GUI_THEMES_DIR}/${THEME_NAME}.toml"; then
  echo "warning: theme saved, but the Wayle settings palette could not be extracted" >&2
fi

repo_root="$(cd "${ASAHI_SETUP_ROOT}/.." && pwd)"
echo "exported ${THEME_NAME} to ${DEST_DIR#"${repo_root}/"}"
