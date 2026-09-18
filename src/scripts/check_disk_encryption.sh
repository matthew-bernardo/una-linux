#!/usr/bin/env bash
# Require the same disk encryption as the current NixOS machine: LUKS on the
# devices that back / and /home. The Fedora Asahi installer does not offer
# this yet; encrypt the root partition in place after install (see README).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

in_container() {
  [[ -f /.dockerenv || -f /run/.containerenv ]] && return 0
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet --container && return 0
  fi
  return 1
}

normalize_source() {
  local src="${1%%\[*}"
  printf '%s\n' "${src}"
}

is_luks_backed() {
  local src
  src="$(normalize_source "$1")"
  [[ -n "${src}" && "${src}" != none && "${src}" != overlay && "${src}" != overlayfs ]] || return 1
  [[ -e "${src}" ]] || return 1

  local type fstype
  while read -r type fstype; do
    if [[ "${type}" == crypt || "${fstype}" == crypto_LUKS ]]; then
      return 0
    fi
  done < <(lsblk -s -nro TYPE,FSTYPE "${src}" 2>/dev/null)
  return 1
}

describe_mount() {
  local mountpoint="$1"
  findmnt -nro SOURCE,FSTYPE "${mountpoint}" 2>/dev/null || echo "(unmounted)"
}

encryption_help() {
  cat >&2 <<'EOF'
This setup expects LUKS on the partitions that back / and /home, matching
the current NixOS cryptroot layout.

The Fedora Asahi installer still does not enable encryption. After a normal
install, encrypt the Asahi root partition in place with LUKS2 from a USB
rescue system, then add rd.luks.uuid= to GRUB and rebuild the initramfs.

See the "Disk encryption" section in README.md, and:
  https://blog.fluxcoil.net/2026/05/fedora-asahi-remix-with-LUKS-encryption-in-2026/
EOF
}

check_mount() {
  local mountpoint="$1"
  local src
  src="$(findmnt -nro SOURCE "${mountpoint}" 2>/dev/null || true)"
  if [[ -z "${src}" ]]; then
    echo "error: could not find a device for ${mountpoint}" >&2
    return 1
  fi
  if is_luks_backed "${src}"; then
    echo "${mountpoint} is LUKS-backed ($(describe_mount "${mountpoint}"))"
    return 0
  fi
  echo "error: ${mountpoint} is not LUKS-backed ($(describe_mount "${mountpoint}"))" >&2
  return 1
}

is_virtual_fs() {
  case "$1" in
    tmpfs | overlay | overlayfs | rootfs | none | "") return 0 ;;
  esac
  return 1
}

targets=()
root_fstype="$(findmnt -nro FSTYPE / 2>/dev/null || true)"
if is_virtual_fs "${root_fstype}"; then
  echo "note: / is ${root_fstype:-unknown}; checking /home for LUKS instead"
  targets+=("/home")
else
  targets+=("/")
  root_src="$(normalize_source "$(findmnt -nro SOURCE / 2>/dev/null || true)")"
  home_src="$(normalize_source "$(findmnt -nro SOURCE /home 2>/dev/null || true)")"
  if [[ -n "${home_src}" && "${home_src}" != "${root_src}" ]]; then
    targets+=("/home")
  fi
fi

failed=0
for mountpoint in "${targets[@]}"; do
  check_mount "${mountpoint}" || failed=1
done

if [[ "${failed}" -eq 0 ]]; then
  exit 0
fi

encryption_help

if in_container; then
  echo "warning: skipping LUKS requirement in this container (no real disk)" >&2
  exit 3
fi

exit 1
