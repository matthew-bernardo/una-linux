#!/usr/bin/env bash
# Enable the MacBook display notch on Asahi via appledrm.show_notch=1.
# Persists with grubby for all installed kernels. Takes effect after reboot
# (live sysfs write is attempted when the module param is writable).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ARG="appledrm.show_notch=1"
LEGACY_ARG="apple_dcp.show_notch=1"
PARAM="/sys/module/appledrm/parameters/show_notch"

if [[ "${EUID}" -ne 0 ]] && ! sudo -n true >/dev/null 2>&1; then
  echo "error: configure_notch.sh needs sudo" >&2
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

if ! command -v grubby >/dev/null 2>&1; then
  echo "error: grubby is required to set kernel boot args" >&2
  exit 1
fi

# Drop the pre-consolidation module name if present.
if run_root grubby --info=ALL 2>/dev/null | grep -q "${LEGACY_ARG}"; then
  run_root grubby --update-kernel=ALL --remove-args="${LEGACY_ARG}"
  echo "removed legacy ${LEGACY_ARG}"
fi

if run_root grubby --info=ALL 2>/dev/null | grep -q "${ARG}"; then
  echo "kernel arg ${ARG} already set"
else
  run_root grubby --update-kernel=ALL --args="${ARG}"
  echo "added kernel arg ${ARG}"
fi

if [[ -e "${PARAM}" ]]; then
  write_root "1" "${PARAM}" || true
  current="$(run_root cat "${PARAM}" 2>/dev/null || true)"
  if [[ "${current}" == "Y" || "${current}" == "1" ]]; then
    echo "applied show_notch live (${current})"
  else
    echo "show_notch sysfs is ${current:-unset}; reboot required for full effect"
  fi
else
  echo "appledrm not loaded yet; notch will apply on next boot"
fi

echo "notch enable configured (reboot if the cutout is not visible yet)"
