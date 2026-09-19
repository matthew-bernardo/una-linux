#!/usr/bin/env bash
# Load a Wayle palette: copy it into ~/.config/wayle/themes, merge it into
# the live config.toml, and drop matching runtime.toml overrides so the
# checkout theme actually takes effect.
#
# Prefers themes from this repo (src/themes/wayle). Falls back to the
# installed copy under ~/.config/wayle/themes only when the repo copy is
# missing — otherwise edits in the checkout never take effect.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

export PATH="${HOME}/.cargo/bin:${PATH}"
if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

REPO_THEMES_DIR="${ASAHI_SETUP_ROOT}/themes/wayle"
INSTALLED_THEMES_DIR="${HOME}/.config/wayle/themes"
WAYLE_DIR="${HOME}/.config/wayle"
LIVE_CONFIG="${WAYLE_DIR}/config.toml"
LIVE_RUNTIME="${WAYLE_DIR}/runtime.toml"
REPO_CONFIG="${ASAHI_SETUP_ROOT}/configs/wayle/config.toml"

list_themes() {
  local dir
  for dir in "${REPO_THEMES_DIR}" "${INSTALLED_THEMES_DIR}"; do
    if [[ -d "${dir}" ]]; then
      find "${dir}" -maxdepth 1 -type f -name '*.toml' -printf '  %f\n' \
        | sed 's/\.toml$//' | sort -u >&2
      return
    fi
  done
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

THEME_SRC=""
if [[ -f "${REPO_THEMES_DIR}/${THEME_NAME}.toml" ]]; then
  THEME_SRC="$(cd "${REPO_THEMES_DIR}" && pwd)/${THEME_NAME}.toml"
elif [[ -f "${INSTALLED_THEMES_DIR}/${THEME_NAME}.toml" ]]; then
  THEME_SRC="$(cd "${INSTALLED_THEMES_DIR}" && pwd)/${THEME_NAME}.toml"
else
  echo "error: no Wayle theme named '${THEME_NAME}'" >&2
  usage
fi

mkdir -p "${INSTALLED_THEMES_DIR}"
if [[ "${THEME_SRC}" != "${INSTALLED_THEMES_DIR}/${THEME_NAME}.toml" ]]; then
  cp "${THEME_SRC}" "${INSTALLED_THEMES_DIR}/${THEME_NAME}.toml"
fi

if [[ ! -f "${LIVE_CONFIG}" ]]; then
  if [[ -f "${REPO_CONFIG}" ]]; then
    cp "${REPO_CONFIG}" "${LIVE_CONFIG}"
  else
    printf '%s\n' "[styling.palette]" >"${LIVE_CONFIG}"
  fi
fi

echo "loading theme from ${THEME_SRC}"

python3 - "${THEME_SRC}" "${LIVE_CONFIG}" "${LIVE_RUNTIME}" <<'PY'
import re
import sys
import tomllib
from pathlib import Path

PALETTE_KEYS = [
    "bg",
    "surface",
    "elevated",
    "fg",
    "fg-muted",
    "primary",
    "red",
    "yellow",
    "green",
    "blue",
]

theme_path = Path(sys.argv[1])
config_path = Path(sys.argv[2])
runtime_path = Path(sys.argv[3])

raw = tomllib.loads(theme_path.read_text())
palette = {}
for key, value in raw.items():
    normalized = key.replace("_", "-")
    if normalized in PALETTE_KEYS:
        palette[normalized] = value

missing = [key for key in PALETTE_KEYS if key not in palette]
if missing:
    raise SystemExit(f"theme missing keys: {', '.join(missing)}")

bg = palette["bg"]
primary = palette["primary"]
occupied = palette["fg"]


def replace_table(text: str, header: str, body: str) -> str:
    if not text.endswith("\n"):
        text += "\n"
    pattern = re.compile(
        rf"^\[{re.escape(header)}\]\n(?:^(?!\[).*\n)*",
        re.MULTILINE,
    )
    block = f"[{header}]\n{body}"
    if not block.endswith("\n"):
        block += "\n"
    if pattern.search(text):
        return pattern.sub(lambda _: block, text, count=1)
    return text + "\n" + block


def set_key_in_table(text: str, table: str, key: str, value: str) -> str:
    if not text.endswith("\n"):
        text += "\n"
    pattern = re.compile(
        rf"(^\[{re.escape(table)}\]\n)((?:^(?!\[).*\n)*)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        return text
    header, body = match.group(1), match.group(2)
    line = f'{key} = "{value}"'
    key_pat = re.compile(rf"^{re.escape(key)} = .*$", re.MULTILINE)
    if key_pat.search(body):
        body = key_pat.sub(line, body, count=1)
    else:
        if body and not body.endswith("\n"):
            body += "\n"
        body += line + "\n"
    return text[: match.start()] + header + body + text[match.end() :]


def remove_table(text: str, header: str) -> str:
    pattern = re.compile(
        rf"^\[{re.escape(header)}\]\n(?:^(?!\[).*\n)*",
        re.MULTILINE,
    )
    return pattern.sub("", text, count=1)


def remove_key_in_table(text: str, table: str, key: str) -> str:
    pattern = re.compile(
        rf"(^\[{re.escape(table)}\]\n)((?:^(?!\[).*\n)*)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        return text
    header, body = match.group(1), match.group(2)
    body = re.sub(rf"^{re.escape(key)} = .*\n?", "", body, count=1, flags=re.MULTILINE)
    return text[: match.start()] + header + body + text[match.end() :]


palette_body = "".join(f'{key} = "{palette[key]}"\n' for key in PALETTE_KEYS)
config = config_path.read_text()
config = replace_table(config, "styling.palette", palette_body)
config = set_key_in_table(config, "bar", "bg", bg)
config = set_key_in_table(config, "modules.hyprland-workspaces", "active-color", primary)
config = set_key_in_table(config, "modules.hyprland-workspaces", "occupied-color", occupied)
config = set_key_in_table(config, "modules.hyprland-workspaces", "container-bg-color", bg)
config_path.write_text(config)

if runtime_path.exists():
    runtime = runtime_path.read_text()
    runtime = remove_table(runtime, "styling.palette")
    runtime = remove_key_in_table(runtime, "bar", "bg")
    for key in ("active-color", "occupied-color", "container-bg-color"):
        runtime = remove_key_in_table(runtime, "modules.hyprland-workspaces", key)
    runtime_path.write_text(runtime)

print(f"applied palette bg={bg} primary={primary}")
PY

if command -v wayle >/dev/null 2>&1; then
  for path in \
    styling.palette.bg \
    styling.palette.surface \
    styling.palette.elevated \
    styling.palette.fg \
    styling.palette.fg-muted \
    styling.palette.primary \
    styling.palette.red \
    styling.palette.yellow \
    styling.palette.green \
    styling.palette.blue \
    bar.bg \
    modules.hyprland-workspaces.active-color \
    modules.hyprland-workspaces.occupied-color \
    modules.hyprland-workspaces.container-bg-color
  do
    wayle config reset "${path}" >/dev/null 2>&1 || true
  done
fi

echo "loaded ${THEME_NAME}"
