#!/usr/bin/env bash
# Install DisplayLink (USB docks/adapters with vendor id 17e9) on Fedora Asahi.
#
# DisplayLink only ships Ubuntu packages. This unpacks the arm64 ones from
# Synaptics' APT repository (pinned versions + SHA256 below) and installs:
#   evdi kernel module    DKMS, rebuilt automatically for each new kernel
#   DisplayLinkManager    /usr/libexec/displaylink-driver (bin_t for SELinux)
#   systemd service       started by a udev rule when a dock is plugged in
#   kernel-install hook   if evdi fails to build for a new kernel, asks
#                         whether to keep booting the old one
#   system-sleep hook     suspend/resume DisplayLinkManager
#
# To update DisplayLink, change the versions and hashes below (from
# ${REPO}/dists/stable/{main,non-free}/binary-arm64/Packages) and run una apply.
# Downloading the driver means accepting DisplayLink's software licence.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

REPO="https://www.synaptics.com/sites/default/files/Ubuntu"
DRIVER_VERSION="6.4.0-22"
DRIVER_SHA256="e181271bfad81e74241d6d0a2a886656afeb068ae3b6126343e716656f29a9ef"
EVDI_VERSION="1.15.1-197"
EVDI_SHA256="d5f8fc5b563381ec35cf41d6728db6d137b580d5c645568fa75e14fbfe23247e"

CONFIGS="${ASAHI_SETUP_ROOT}/configs/displaylink"
LIBEXEC="/usr/libexec/displaylink-driver"
VERSION_STAMP="${LIBEXEC}/.una-version"
EVDI_SRC_VERSION="${EVDI_VERSION%-*}"
KVER="$(uname -r)"

if [[ "${EUID}" -ne 0 ]] && ! sudo -n true >/dev/null 2>&1; then
  echo "error: install_displaylink.sh needs sudo" >&2
  exit 1
fi

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "error: this installs the arm64 DisplayLink driver; machine is $(uname -m)" >&2
  exit 1
fi

# The test container runs on the host's (non-Asahi) kernel: no headers to
# build evdi against, and no USB to drive. Warn instead of failing.
if [[ "${KVER}" != *asahi* ]]; then
  echo "warning: kernel ${KVER} is not an Asahi kernel; skipping DisplayLink"
  exit 3
fi

case "${KVER}" in
  *+16k) devel_pkg="kernel-16k-devel-matched" ;;
  *) devel_pkg="kernel-devel-matched" ;;
esac

# --- packages -----------------------------------------------------------
# kernel-*-devel-matched is a normal (not install-only) package, so it is
# upgraded together with the kernel and DKMS always has headers to build
# evdi against. dkms only pulls this in by itself for the 4K kernel.
echo "installing dkms, ${devel_pkg}, libusb1"
run_root dnf install -y -q dkms "${devel_pkg}" libusb1 binutils curl
if [[ ! -e "/lib/modules/${KVER}/build/Makefile" ]]; then
  echo "error: headers for the running kernel ${KVER} are not installed." >&2
  echo "       ${devel_pkg} installed headers for a newer kernel; reboot into it and rerun una apply." >&2
  exit 1
fi

# --- download + unpack --------------------------------------------------
want_stamp="driver=${DRIVER_VERSION} evdi=${EVDI_VERSION}"
have_stamp="$(cat "${VERSION_STAMP}" 2>/dev/null || true)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fetch_deb() {
  local path="$1" sha="$2" name dest
  name="${path##*/}"
  dest="${WORK}/${name%%_*}"
  curl -fsSL --retry 3 -o "${WORK}/${name}" "${REPO}/${path}"
  if ! printf '%s  %s\n' "${sha}" "${WORK}/${name}" | sha256sum -c --quiet -; then
    echo "error: SHA256 mismatch for ${name}" >&2
    exit 1
  fi
  mkdir -p "${dest}"
  (cd "${dest}" && ar x "${WORK}/${name}" && tar -xf data.tar.*)
  printf '%s\n' "${dest}"
}

if [[ "${have_stamp}" != "${want_stamp}" || ! -d "/usr/src/evdi-${EVDI_SRC_VERSION}" ]]; then
  echo "downloading DisplayLink ${DRIVER_VERSION} and evdi ${EVDI_VERSION}"
  driver_dir="$(fetch_deb "pool/stable/non-free/arm64/displaylink-driver-${DRIVER_VERSION}_arm64.deb" "${DRIVER_SHA256}")"
  evdi_dir="$(fetch_deb "pool/stable/main/arm64/evdi-${EVDI_VERSION}_arm64.deb" "${EVDI_SHA256}")"

  run_root systemctl stop displaylink-driver.service 2>/dev/null || true

  # DisplayLinkManager, its firmware, and libevdi (kept private to it).
  run_root rm -rf "${LIBEXEC}"
  run_root install -d -m 755 "${LIBEXEC}"
  run_root install -m 755 "${driver_dir}/usr/lib/displaylink-driver/DisplayLinkManager" "${LIBEXEC}/"
  run_root install -m 644 "${driver_dir}"/usr/lib/displaylink-driver/*.spkg "${LIBEXEC}/"
  lib="$(cd "${evdi_dir}/usr/lib" && ls libevdi.so.*.*)"
  run_root install -m 755 "${evdi_dir}/usr/lib/${lib}" "${LIBEXEC}/"
  run_root ln -sfn "${lib}" "${LIBEXEC}/libevdi.so.1"

  # evdi source for DKMS.
  run_root rm -rf "/usr/src/evdi-${EVDI_SRC_VERSION}"
  run_root cp -r "${evdi_dir}/usr/src/evdi-${EVDI_SRC_VERSION}" /usr/src/
  printf '%s\n' "${want_stamp}" | run_root tee "${VERSION_STAMP}" >/dev/null
else
  echo "DisplayLink ${DRIVER_VERSION} / evdi ${EVDI_VERSION} already unpacked"
fi

# --- evdi via DKMS ------------------------------------------------------
# Drop other evdi versions so dkms autoinstall only ever builds this one.
while IFS= read -r old; do
  [[ -n "${old}" && "${old}" != "${EVDI_SRC_VERSION}" ]] || continue
  echo "removing evdi ${old} from dkms"
  run_root dkms remove -m evdi -v "${old}" --all || true
  run_root rm -rf "/usr/src/evdi-${old}"
done < <(run_root dkms status -m evdi 2>/dev/null | sed -n 's|^evdi/\([^,:]*\).*|\1|p' | sort -u)

if [[ -z "$(run_root dkms status -m evdi -v "${EVDI_SRC_VERSION}")" ]]; then
  run_root dkms add -m evdi -v "${EVDI_SRC_VERSION}"
fi
if [[ "$(run_root dkms status -m evdi -v "${EVDI_SRC_VERSION}" -k "${KVER}")" == *installed* ]]; then
  echo "evdi ${EVDI_SRC_VERSION} already built for ${KVER}"
else
  echo "building evdi ${EVDI_SRC_VERSION} for ${KVER}"
  if ! run_root dkms install -m evdi -v "${EVDI_SRC_VERSION}" -k "${KVER}"; then
    echo "error: evdi ${EVDI_SRC_VERSION} does not build for ${KVER}." >&2
    echo "       See /var/lib/dkms/evdi/${EVDI_SRC_VERSION}/build/make.log" >&2
    exit 1
  fi
fi

# --- service, udev, hooks -----------------------------------------------
run_root install -m 644 "${CONFIGS}/displaylink-driver.service" /etc/systemd/system/displaylink-driver.service
run_root install -m 644 "${CONFIGS}/99-displaylink.rules" /etc/udev/rules.d/99-displaylink.rules
run_root install -m 755 "${CONFIGS}/una-evdi-kernel" /usr/local/sbin/una-evdi-kernel
run_root install -d -m 755 /etc/kernel/install.d
run_root install -m 755 "${CONFIGS}/99-una-evdi.install" /etc/kernel/install.d/99-una-evdi.install
run_root install -m 755 "${CONFIGS}/una-displaylink.sleep" /usr/lib/systemd/system-sleep/una-displaylink
run_root install -d -m 755 /var/log/displaylink /var/lib/una/displaylink/failed /var/lib/una/displaylink/decided

if command -v restorecon >/dev/null 2>&1; then
  run_root restorecon -R "${LIBEXEC}" /usr/src/evdi-"${EVDI_SRC_VERSION}" \
    /etc/systemd/system/displaylink-driver.service /etc/udev/rules.d/99-displaylink.rules \
    /usr/local/sbin/una-evdi-kernel /etc/kernel/install.d/99-una-evdi.install \
    /usr/lib/systemd/system-sleep/una-displaylink /var/log/displaylink /var/lib/una
fi

# Record the running kernel as good (clears any stale failure records).
run_root /usr/local/sbin/una-evdi-kernel check "${KVER}"

run_root systemctl daemon-reload
run_root udevadm control --reload

# evdi loaded while the service is not running did not come from the service
# (e.g. an insmod while testing, or a previous evdi version). Unload it so the
# service's modprobe loads the DKMS build.
if [[ -d /sys/module/evdi ]] && ! systemctl is-active --quiet displaylink-driver.service; then
  run_root modprobe -r evdi 2>/dev/null || run_root rmmod evdi 2>/dev/null \
    || echo "note: could not unload the old evdi; reboot to use the new one"
fi

# Re-run the udev rule for docks that are already plugged in; it creates the
# /dev/displaylink link and starts the service.
run_root udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor=17e9
if lsusb -d 17e9: >/dev/null 2>&1; then
  run_root udevadm settle --timeout=10 || true
  run_root systemctl restart displaylink-driver.service
  echo "DisplayLink device connected; service restarted"
else
  echo "no DisplayLink device connected; the service starts when one is plugged in"
fi

echo "DisplayLink ${DRIVER_VERSION} installed (evdi ${EVDI_SRC_VERSION} via DKMS)"
