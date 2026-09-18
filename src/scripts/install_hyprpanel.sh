#!/usr/bin/env bash
# Clone HyprPanel, install Fedora deps via Ansible, build Astal/AGS from
# source (lionheartp has no aylurs-gtk-shell), copy themes, then build HyprPanel.
# Checkouts live under ~/.una/ so they stay out of ~/setup and ~/.config/una.
# https://github.com/Jas-SinghFSU/HyprPanel
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

HYPRPANEL_REPO="https://github.com/Jas-SinghFSU/HyprPanel.git"
HYPRPANEL_SRC="${HOME}/.una/HyprPanel"
ASTAL_SRC="${HOME}/.una/astal"
AGS_SRC="${HOME}/.una/ags"
APPMENU_SRC="${HOME}/.una/vala-panel-appmenu"
MESON_PREFIX="/usr"

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags hyprpanel

clone_if_missing() {
  local repo="$1"
  local dest="$2"
  mkdir -p "$(dirname "${dest}")"
  if [[ ! -d "${dest}/.git" ]]; then
    git clone --recursive "${repo}" "${dest}"
  fi
}

meson_install() {
  local src="$1"
  local build="${src}/build"
  if [[ -f "${build}/build.ninja" ]]; then
    return 0
  fi
  meson setup --prefix="${MESON_PREFIX}" "${build}" "${src}"
  meson compile -C "${build}"
  sudo meson install -C "${build}"
}

if ! command -v sass >/dev/null 2>&1; then
  sudo npm install -g sass
fi

# AGS / Astal are not in lionheartp/Hyprland. HyprPanel needs their typelibs
# (including AstalCava) even if `ags` is already on PATH from a previous run.
clone_if_missing "https://github.com/aylur/astal.git" "${ASTAL_SRC}"
clone_if_missing "https://github.com/rilian-la-te/vala-panel-appmenu.git" "${APPMENU_SRC}"
meson_install "${ASTAL_SRC}/lib/astal/io"
meson_install "${ASTAL_SRC}/lib/astal/gtk3"
meson_install "${ASTAL_SRC}/lib/astal/gtk4"
meson_install "${ASTAL_SRC}/lang/gjs"
# notifd/mpris CLIs need libquarrel; tray needs appmenu-glib-translator.
meson_install "${ASTAL_SRC}/lib/quarrel"
meson_install "${APPMENU_SRC}/subprojects/appmenu-glib-translator"
# cava pulls libcava via meson wrap (LukashonakV/cava).
for lib in hyprland battery network bluetooth notifd tray mpris apps wireplumber powerprofiles cava; do
  meson_install "${ASTAL_SRC}/lib/${lib}"
done

if ! command -v ags >/dev/null 2>&1; then
  clone_if_missing "https://github.com/aylur/ags.git" "${AGS_SRC}"
  if [[ ! -d "${AGS_SRC}/node_modules" ]]; then
    npm install --prefix "${AGS_SRC}"
  fi
  meson_install "${AGS_SRC}"
fi

clone_if_missing "${HYPRPANEL_REPO}" "${HYPRPANEL_SRC}"

if [[ ! -d "${HYPRPANEL_SRC}/node_modules" ]]; then
  npm install --prefix "${HYPRPANEL_SRC}"
fi

if [[ ! -f "${HYPRPANEL_SRC}/build/build.ninja" ]]; then
  meson setup --prefix="${MESON_PREFIX}" "${HYPRPANEL_SRC}/build" "${HYPRPANEL_SRC}"
fi
meson compile -C "${HYPRPANEL_SRC}/build"
sudo meson install -C "${HYPRPANEL_SRC}/build"

if [[ -x "${HYPRPANEL_SRC}/scripts/install_fonts.sh" ]]; then
  (
    cd "${HYPRPANEL_SRC}"
    ./scripts/install_fonts.sh
  )
fi
