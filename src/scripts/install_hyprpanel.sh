#!/usr/bin/env bash
# Clone HyprPanel into ~.unaHyprPanel, install Fedora deps via Ansible,
# copy themes into ~/.config/hyprpanel/themes, then build from source.
# https://github.com/Jas-SinghFSU/HyprPanel
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

HYPRPANEL_REPO="https://github.com/Jas-SinghFSU/HyprPanel.git"
HYPRPANEL_SRC="${HOME}.unaHyprPanel"

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags hyprpanel

mkdir -p "${HOME}/setup"
if [[ ! -d "${HYPRPANEL_SRC}/.git" ]]; then
  git clone --recursive "${HYPRPANEL_REPO}" "${HYPRPANEL_SRC}"
fi

if ! command -v sass >/dev/null 2>&1; then
  sudo npm install -g sass
fi

if [[ ! -d "${HYPRPANEL_SRC}/node_modules" ]]; then
  npm install --prefix "${HYPRPANEL_SRC}"
fi

if [[ ! -f "${HYPRPANEL_SRC}/build/build.ninja" ]]; then
  meson setup "${HYPRPANEL_SRC}/build" "${HYPRPANEL_SRC}"
fi
meson compile -C "${HYPRPANEL_SRC}/build"
sudo meson install -C "${HYPRPANEL_SRC}/build"

if [[ -x "${HYPRPANEL_SRC}/scripts/install_fonts.sh" ]]; then
  (
    cd "${HYPRPANEL_SRC}"
    ./scripts/install_fonts.sh
  )
fi
