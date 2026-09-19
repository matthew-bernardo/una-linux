#!/usr/bin/env bash
# Load a Wayle theme folder: copy its config.toml over the live Wayle
# config, copy style.css to ~/.config/wayle/styles/index.scss, extract a
# GUI palette, drop runtime.toml overrides, and record the name in
# .una_asahi_setup.json so `una sync` can round-trip it.
#
# Prefers themes from this repo (src/themes/wayle/<name>/config.toml).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

export PATH="${HOME}/.cargo/bin:${PATH}"
if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

REPO_THEMES_DIR="${ASAHI_SETUP_ROOT}/themes/wayle"
WAYLE_DIR="${HOME}/.config/wayle"
LIVE_CONFIG="${WAYLE_DIR}/config.toml"
LIVE_RUNTIME="${WAYLE_DIR}/runtime.toml"
GUI_THEMES_DIR="${WAYLE_DIR}/themes"
WAYLE_THEME_PY="${_ASAHI_SETUP_SCRIPTS_DIR}/_wayle_theme.py"

list_themes() {
  local dir
  if [[ -d "${REPO_THEMES_DIR}" ]]; then
    for dir in "${REPO_THEMES_DIR}"/*/; do
      [[ -f "${dir}config.toml" && -f "${dir}style.css" ]] || continue
      printf '  %s\n' "$(basename "${dir}")"
    done | sort >&2
  fi
}

usage() {
  echo "Usage: una load_theme <theme>" >&2
  echo "Available themes:" >&2
  list_themes
  exit 1
}

[[ $# -eq 1 ]] || usage

THEME_NAME="${1%/}"
THEME_NAME="${THEME_NAME%.toml}"
if [[ "${THEME_NAME}" == */* || "${THEME_NAME}" == "." || "${THEME_NAME}" == ".." ]]; then
  echo "error: pass a theme name, not a path (${THEME_NAME})" >&2
  usage
fi

THEME_CONFIG="${REPO_THEMES_DIR}/${THEME_NAME}/config.toml"
THEME_STYLE="${REPO_THEMES_DIR}/${THEME_NAME}/style.css"
if [[ ! -f "${THEME_CONFIG}" ]]; then
  echo "error: no Wayle theme named '${THEME_NAME}'" >&2
  usage
fi
if [[ ! -f "${THEME_STYLE}" ]]; then
  echo "error: missing ${THEME_STYLE}" >&2
  exit 1
fi

THEME_DIR="$(cd "$(dirname "${THEME_CONFIG}")" && pwd)"
THEME_CONFIG="${THEME_DIR}/config.toml"
THEME_STYLE="${THEME_DIR}/style.css"
LIVE_STYLES="${WAYLE_DIR}/styles/index.scss"

mkdir -p "${WAYLE_DIR}" "${GUI_THEMES_DIR}" "$(dirname "${LIVE_STYLES}")"

echo "loading theme from ${THEME_DIR}"
cp --preserve=mode -- "${THEME_CONFIG}" "${LIVE_CONFIG}"
cp --preserve=mode -- "${THEME_STYLE}" "${LIVE_STYLES}"
python3 "${WAYLE_THEME_PY}" extract-palette "${THEME_CONFIG}" \
  "${GUI_THEMES_DIR}/${THEME_NAME}.toml"
rm -f "${LIVE_RUNTIME}"
python3 "${RUN_LOG_PY}" set-theme "${RUN_LOG_FILE}" "${THEME_NAME}"

echo "loaded ${THEME_NAME}"
