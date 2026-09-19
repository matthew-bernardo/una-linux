#!/usr/bin/env bash
# Clone Wayle, install Fedora deps via Ansible, install Rust if needed,
# then cargo-install the panel and settings GUI.
# Checkout lives under ~/.una/ so it stays out of ~/.config/una.
# https://github.com/wayle-rs/wayle
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "${_ASAHI_SETUP_SCRIPTS_DIR}/_panel.sh"

WAYLE_REPO="https://github.com/wayle-rs/wayle.git"
WAYLE_SRC="${HOME}/.una/wayle"

export PATH="${HOME}/.cargo/bin:${PATH}"
if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags wayle

clone_if_missing() {
  local repo="$1"
  local dest="$2"
  mkdir -p "$(dirname "${dest}")"
  if [[ ! -d "${dest}/.git" ]]; then
    git clone "${repo}" "${dest}"
  fi
}

ensure_rust() {
  if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
    return 0
  fi
  if command -v rustup-init >/dev/null 2>&1; then
    rustup-init -y --no-modify-path --default-toolchain stable
  elif command -v rustup >/dev/null 2>&1; then
    rustup default stable
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
}

clone_if_missing "${WAYLE_REPO}" "${WAYLE_SRC}"
ensure_rust

if [[ ! -d "${WAYLE_SRC}/wayle" ]]; then
  echo "error: ${WAYLE_SRC}/wayle is missing; clone looks incomplete" >&2
  exit 1
fi

cd "${WAYLE_SRC}"
if [[ -f Cargo.lock ]]; then
  cargo install --locked --path wayle
  cargo install --locked --path crates/wayle-settings
else
  cargo install --path wayle
  cargo install --path crates/wayle-settings
fi

(
  cd "${WAYLE_SRC}"
  wayle icons setup
)

install_start_panel
activate_panel

mkdir -p "${HOME}/.config/wayle/themes"
python3 "${_ASAHI_SETUP_SCRIPTS_DIR}/_wayle_theme.py" extract-all \
  "${ASAHI_SETUP_ROOT}/themes/wayle" \
  "${HOME}/.config/wayle/themes"

wayle_theme="$(python3 "${RUN_LOG_PY}" get-theme "${RUN_LOG_FILE}")"
if [[ -z "${wayle_theme}" ]]; then
  wayle_theme="cmyk-dark"
fi
if [[ ! -f "${HOME}/.config/wayle/config.toml" ]]; then
  "${_ASAHI_SETUP_SCRIPTS_DIR}/load_theme.sh" "${wayle_theme}"
elif [[ -z "$(python3 "${RUN_LOG_PY}" get-theme "${RUN_LOG_FILE}")" ]]; then
  python3 "${RUN_LOG_PY}" set-theme "${RUN_LOG_FILE}" "${wayle_theme}"
fi
