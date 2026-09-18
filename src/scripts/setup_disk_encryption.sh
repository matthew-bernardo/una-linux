#!/usr/bin/env bash
# Open an existing LUKS volume as a device mapper and persist it in
# /etc/crypttab with discard (so Fedora's fstrim.timer can TRIM).
# Does not format or re-encrypt a live root — that stays a rescue-USB step.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TTY="/dev/tty"
DEFAULT_MAPPER="fedora-root"
CRYPTTAB="/etc/crypttab"

in_container() {
  [[ -f /.dockerenv || -f /run/.containerenv ]] && return 0
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet --container && return 0
  fi
  return 1
}

say() {
  printf '%s\n' "$*" >"${TTY}"
}

ask() {
  local reply
  printf '%s' "$1" >"${TTY}"
  read -r reply <"${TTY}"
  printf '%s\n' "${reply}"
}

confirm() {
  local reply
  reply="$(ask "$1 [y/N] ")"
  [[ "${reply}" == [yY] || "${reply}" == yes || "${reply}" == YES ]]
}

die() {
  printf 'error: %s\n' "$*" >"${TTY}"
  exit 1
}

require_tty() {
  [[ -r "${TTY}" && -w "${TTY}" ]] || {
    echo "error: setup_disk_encryption.sh needs a real terminal for prompts" >&2
    exit 1
  }
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    say "Re-running as root…"
    exec sudo -- "$0" "$@"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

luks_uuid() {
  cryptsetup luksUUID "$1" 2>/dev/null
}

is_luks_partition() {
  local fstype
  fstype="$(lsblk -nro FSTYPE "$1" 2>/dev/null || true)"
  [[ "${fstype}" == crypto_LUKS ]]
}

backing_luks_partition() {
  local dev="$1" name fstype
  while read -r name fstype; do
    if [[ "${fstype}" == crypto_LUKS ]]; then
      printf '%s\n' "${name}"
      return 0
    fi
  done < <(lsblk -s -nrp -o NAME,FSTYPE "${dev}" 2>/dev/null)
  return 1
}

existing_mapper_for() {
  local luks_dev="$1" name type
  while read -r name type; do
    if [[ "${type}" == crypt ]]; then
      printf '%s\n' "${name##*/}"
      return 0
    fi
  done < <(lsblk -nrp -o NAME,TYPE "${luks_dev}" 2>/dev/null)
  return 1
}

crypttab_matches() {
  local name="$1" uuid="$2"
  [[ -f "${CRYPTTAB}" ]] || return 1
  grep -E "^${name}[[:space:]]+UUID=${uuid}[[:space:]]+none[[:space:]].*discard" "${CRYPTTAB}" >/dev/null
}

write_crypttab_entry() {
  local name="$1" uuid="$2"
  local desired="${name} UUID=${uuid} none discard"
  local tmp found=0 line

  if [[ -f "${CRYPTTAB}" ]]; then
    cp -a "${CRYPTTAB}" "${CRYPTTAB}.una.bak"
  else
    umask 077
    : >"${CRYPTTAB}"
  fi
  chmod 0600 "${CRYPTTAB}"

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^${name}[[:space:]] ]] || [[ "${line}" == *"UUID=${uuid}"* ]]; then
      printf '%s\n' "${desired}" >>"${tmp}"
      found=1
    else
      printf '%s\n' "${line}" >>"${tmp}"
    fi
  done <"${CRYPTTAB}"
  if [[ "${found}" -eq 0 ]]; then
    printf '%s\n' "${desired}" >>"${tmp}"
  fi
  mv "${tmp}" "${CRYPTTAB}"
  chmod 0600 "${CRYPTTAB}"
}

list_luks_devices() {
  local name fstype type size label
  while read -r name fstype type size label; do
    if [[ "${fstype}" == crypto_LUKS || "${type}" == crypt ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${name}" "${fstype:-}" "${type}" "${size}" "${label:-}"
    fi
  done < <(lsblk -nrp -o NAME,FSTYPE,TYPE,SIZE,LABEL)
}

if in_container; then
  echo "note: skipping LUKS mapper setup in this container (no real disk)"
  exit 0
fi

require_tty
require_root "$@"
require_cmd cryptsetup
require_cmd lsblk
require_cmd mktemp

say "LUKS mapper setup"
say "This opens an existing LUKS partition and adds it to ${CRYPTTAB} with discard."
say "It will not format or re-encrypt a disk."
say ""

mapfile -t luks_rows < <(list_luks_devices)
if [[ "${#luks_rows[@]}" -eq 0 ]]; then
  die "no LUKS volumes found. Encrypt the Asahi root partition from a USB rescue system first (see README)."
fi

say "LUKS devices:"
i=1
for row in "${luks_rows[@]}"; do
  IFS=$'\t' read -r name fstype type size label <<<"${row}"
  say "  ${i}) ${name}  fstype=${fstype:-?}  type=${type}  size=${size}  label=${label:-}"
  i=$((i + 1))
done
say ""

choice="$(ask "Select a device [1]: ")"
[[ -z "${choice}" ]] && choice=1
[[ "${choice}" =~ ^[0-9]+$ ]] || die "not a number"
[[ "${choice}" -ge 1 && "${choice}" -le "${#luks_rows[@]}" ]] || die "selection out of range"

IFS=$'\t' read -r selected_dev _selected_fstype _selected_type _ _ <<<"${luks_rows[$((choice - 1))]}"

typed="$(ask "Type ${selected_dev} to confirm: ")"
[[ "${typed}" == "${selected_dev}" ]] || die "confirmation did not match"

luks_dev="${selected_dev}"
if ! is_luks_partition "${luks_dev}"; then
  luks_dev="$(backing_luks_partition "${selected_dev}")" \
    || die "${selected_dev} is not a LUKS partition and has no LUKS parent"
fi

uuid="$(luks_uuid "${luks_dev}")" || die "could not read LUKS UUID from ${luks_dev}"
say "LUKS UUID: ${uuid}"

current_mapper="$(existing_mapper_for "${luks_dev}" || true)"
if [[ -n "${current_mapper}" ]]; then
  say "Already mapped as /dev/mapper/${current_mapper}"
  mapper_name="${current_mapper}"
else
  mapper_name="$(ask "Mapper name [${DEFAULT_MAPPER}]: ")"
  [[ -z "${mapper_name}" ]] && mapper_name="${DEFAULT_MAPPER}"
  [[ "${mapper_name}" =~ ^[A-Za-z0-9_-]+$ ]] || die "mapper name must be alphanumeric, underscore, or dash"
fi

say ""
say "Will use:"
say "  partition: ${luks_dev}"
say "  mapper:    /dev/mapper/${mapper_name}"
say "  crypttab:  ${mapper_name} UUID=${uuid} none discard"
say ""
confirm "Write this mapper into ${CRYPTTAB}?" || die "aborted"

if [[ -e "/dev/mapper/${mapper_name}" ]]; then
  say "Mapper /dev/mapper/${mapper_name} is already active."
else
  say "Opening LUKS volume (cryptsetup will ask for the passphrase)…"
  cryptsetup open "${luks_dev}" "${mapper_name}" <"${TTY}" >"${TTY}" 2>&1
  [[ -e "/dev/mapper/${mapper_name}" ]] || die "cryptsetup open did not create /dev/mapper/${mapper_name}"
  say "Opened /dev/mapper/${mapper_name}"
fi

if crypttab_matches "${mapper_name}" "${uuid}"; then
  say "${CRYPTTAB} already has ${mapper_name} with discard."
else
  write_crypttab_entry "${mapper_name}" "${uuid}"
  say "Updated ${CRYPTTAB} (backup at ${CRYPTTAB}.una.bak if a file already existed)."
fi

say ""
say "Mapper is ready. Initramfs/GRUB (rd.luks.uuid) is not handled yet."
say "Fedora's fstrim.timer will TRIM once discard is active on the opened volume."
say ""
say "crypttab:"
cat "${CRYPTTAB}" >"${TTY}"
