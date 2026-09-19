#!/usr/bin/env bash
# Persist Apple keyboard Fn ↔ Left Ctrl swap via hid_apple.
# Writes /etc/modprobe.d/hid_apple.conf and rebuilds the initramfs when needed.
# Also applies the setting live when the module is already loaded.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

CONF="/etc/modprobe.d/hid_apple.conf"
CONTENT="options hid_apple swap_fn_leftctrl=1"
PARAM="/sys/module/hid_apple/parameters/swap_fn_leftctrl"

if [[ "${EUID}" -ne 0 ]] && ! sudo -n true >/dev/null 2>&1; then
  echo "error: configure_hid_apple.sh needs sudo" >&2
  exit 1
fi

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

write_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "$1" >"$2"
  else
    printf '%s\n' "$1" | sudo tee "$2" >/dev/null
  fi
}

needs_dracut=0
current="$(run_root cat "${CONF}" 2>/dev/null || true)"
if [[ "${current}" != "${CONTENT}" && "${current}" != "${CONTENT}"$'\n' ]]; then
  write_root "${CONTENT}" "${CONF}"
  run_root chmod 644 "${CONF}"
  needs_dracut=1
  echo "wrote ${CONF}"
else
  echo "${CONF} already configured"
fi

if [[ -e "${PARAM}" ]]; then
  write_root "1" "${PARAM}"
  echo "applied swap_fn_leftctrl=1 live"
else
  echo "hid_apple not loaded yet; swap will apply on next boot"
fi

if [[ "${needs_dracut}" -eq 1 ]]; then
  if ! command -v dracut >/dev/null 2>&1; then
    echo "error: dracut is required to persist hid_apple options in the initramfs" >&2
    exit 1
  fi
  echo "rebuilding initramfs with dracut -f"
  run_root dracut -f
fi

echo "hid_apple Fn/Ctrl swap configured"
