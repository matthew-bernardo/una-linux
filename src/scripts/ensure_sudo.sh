#!/usr/bin/env bash
# Cache sudo on the real TTY and make the ticket visible to Ansible become
# (which runs `sudo -n` with no tty). Safe to re-run.
set -euo pipefail

TTY="/dev/tty"
DROPIN="/etc/sudoers.d/una-setup"
CONTENT="Defaults timestamp_type=global"

if [[ "${EUID}" -eq 0 ]]; then
  exit 0
fi

command -v sudo >/dev/null 2>&1 || {
  echo "error: sudo is required for privileged steps" >&2
  exit 1
}

if [[ ! -r "${TTY}" || ! -w "${TTY}" ]]; then
  echo "error: sudo prompt needs a real terminal" >&2
  exit 1
fi

sudo_on_tty() {
  sudo "$@" <"${TTY}" >"${TTY}" 2>&1
}

if ! sudo -n true >/dev/null 2>&1; then
  printf 'una: sudo password (cached for the rest of this apply)\n' >"${TTY}"
  sudo_on_tty -v
fi

if ! sudo -n grep -qxF "${CONTENT}" "${DROPIN}" 2>/dev/null; then
  printf '%s\n' "${CONTENT}" | sudo tee "${DROPIN}" >/dev/null
  sudo chmod 0440 "${DROPIN}"
  if ! sudo visudo -c >/dev/null; then
    sudo rm -f "${DROPIN}"
    echo "error: refused to install ${DROPIN} (visudo -c failed)" >&2
    exit 1
  fi
  sudo_on_tty -v
fi
