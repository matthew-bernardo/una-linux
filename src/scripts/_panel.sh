# Shared helpers for installing and launching Wayle.
# Source this file after _common.sh.

START_PANEL_DEST="${HOME}/.config/una/bin/start_panel"
START_PANEL_SRC="${ASAHI_SETUP_ROOT}/configs/una/start_panel"
WAYLE_REC_DEST="${HOME}/.config/una/bin/wayle_rec"
WAYLE_REC_SRC="${ASAHI_SETUP_ROOT}/configs/una/wayle_rec"

install_start_panel() {
  mkdir -p "$(dirname "${START_PANEL_DEST}")"
  install -m 0755 "${START_PANEL_SRC}" "${START_PANEL_DEST}"
  install -m 0755 "${WAYLE_REC_SRC}" "${WAYLE_REC_DEST}"
}

patch_hyprland_panel_launcher() {
  local live="${HOME}/.config/hypr/hyprland.lua"
  [[ -f "${live}" ]] || return 0
  python3 - "${live}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start = 'os.getenv("HOME") .. "/.config/una/bin/start_panel"'
replacements = (
    ('hl.exec_cmd("hyprpanel")', f"hl.exec_cmd({start})"),
    (
        'hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpanel -q; hyprpanel"))',
        f'hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd({start} .. " restart"))',
    ),
)
updated = text
for old, new in replacements:
    updated = updated.replace(old, new)
if updated != text:
    path.write_text(updated)
PY
}

activate_panel() {
  install_start_panel
  patch_hyprland_panel_launcher
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && PATH="${HOME}/.cargo/bin:${PATH}" command -v wayle >/dev/null 2>&1; then
    "${START_PANEL_DEST}" restart
  fi
}
