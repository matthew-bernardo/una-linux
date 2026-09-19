#!/usr/bin/env bash
# Load a HyprPanel theme folder: merge config.json, copy modules.scss, then
# apply theme.json via `hyprpanel useTheme` (which requires an absolute path).
#
# Prefers themes from this repo (src/themes/hyprpanel). Falls back to the
# installed copy under ~/.config/hyprpanel/themes only when the repo copy is
# missing — otherwise edits in the checkout never take effect.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

REPO_THEMES_DIR="${ASAHI_SETUP_ROOT}/themes/hyprpanel"
INSTALLED_THEMES_DIR="${HOME}/.config/hyprpanel/themes"
HYPRPANEL_DIR="${HOME}/.config/hyprpanel"
LIVE_CONFIG="${HYPRPANEL_DIR}/config.json"
LIVE_MODULES="${HYPRPANEL_DIR}/modules.scss"

usage() {
  echo "Usage: una load_theme <theme-folder>" >&2
  echo "Available themes:" >&2
  local dir
  for dir in "${REPO_THEMES_DIR}" "${INSTALLED_THEMES_DIR}"; do
    if [[ -d "${dir}" ]]; then
      find "${dir}" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort -u >&2
      break
    fi
  done
  exit 1
}

[[ $# -eq 1 ]] || usage

THEME_NAME="${1%/}"
if [[ "${THEME_NAME}" == */* || "${THEME_NAME}" == "." || "${THEME_NAME}" == ".." ]]; then
  echo "error: pass a theme folder name, not a path (${THEME_NAME})" >&2
  usage
fi

THEME_DIR=""
if [[ -d "${REPO_THEMES_DIR}/${THEME_NAME}" ]]; then
  THEME_DIR="$(cd "${REPO_THEMES_DIR}/${THEME_NAME}" && pwd)"
elif [[ -d "${INSTALLED_THEMES_DIR}/${THEME_NAME}" ]]; then
  THEME_DIR="$(cd "${INSTALLED_THEMES_DIR}/${THEME_NAME}" && pwd)"
else
  echo "error: no theme folder named '${THEME_NAME}'" >&2
  usage
fi

THEME_JSON="${THEME_DIR}/theme.json"
THEME_CONFIG="${THEME_DIR}/config.json"
THEME_MODULES="${THEME_DIR}/modules.scss"

if [[ ! -f "${THEME_JSON}" ]]; then
  echo "error: missing ${THEME_JSON}" >&2
  exit 1
fi
if [[ ! -f "${THEME_CONFIG}" ]]; then
  echo "error: missing ${THEME_CONFIG}" >&2
  exit 1
fi
if ! command -v hyprpanel >/dev/null; then
  echo "error: hyprpanel is not on PATH" >&2
  exit 1
fi

mkdir -p "${HYPRPANEL_DIR}"

echo "loading theme from ${THEME_DIR}"

python3 - "${LIVE_CONFIG}" "${THEME_CONFIG}" <<'PY'
import json
import sys
from pathlib import Path

live_path = Path(sys.argv[1])
incoming_path = Path(sys.argv[2])
incoming = json.loads(incoming_path.read_text())
live = json.loads(live_path.read_text()) if live_path.exists() else {}
live.update(incoming)
live_path.write_text(json.dumps(live, indent=2) + "\n")
print(f"merged config ({len(incoming)} keys); theme.bar.scaling={live.get('theme.bar.scaling', '<unset>')}")
PY

if [[ -f "${THEME_MODULES}" ]]; then
  cp "${THEME_MODULES}" "${LIVE_MODULES}"
else
  printf '%s\n' '/* no extra modules.scss for this theme */' > "${LIVE_MODULES}"
fi

hyprpanel useTheme "${THEME_JSON}"

echo "loaded ${THEME_NAME}"
