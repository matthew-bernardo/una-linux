#!/usr/bin/env bash
# una displaylink [status|kernel|restart|logs]
#   status   (default) is DisplayLink working, and if not, why
#   kernel   choose which kernel to boot after evdi failed to build
#   restart  restart the DisplayLink service
#   logs     recent DisplayLinkManager and kernel messages
set -euo pipefail

HELPER=/usr/local/sbin/una-evdi-kernel
STAMP=/usr/libexec/displaylink-driver/.una-version
SERVICE=displaylink-driver.service

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  OK=$'\033[32m✔\033[0m' BAD=$'\033[31m✘\033[0m' WARN=$'\033[33m!\033[0m' DIM=$'\033[2m' RESET=$'\033[0m'
else
  OK="ok" BAD="FAIL" WARN="warn" DIM="" RESET=""
fi

line() { printf '  %s  %-10s %s\n' "$1" "$2" "$3"; }

dock_sysfs() {
  local d
  for d in /sys/bus/usb/devices/*; do
    [[ -r "${d}/idVendor" && "$(cat "${d}/idVendor")" == "17e9" ]] && { printf '%s\n' "${d}"; return 0; }
  done
  return 1
}

status() {
  local kver problems=0
  kver="$(uname -r)"
  echo "DisplayLink"

  if [[ ! -x "${HELPER}" || ! -e "${STAMP}" ]]; then
    line "${BAD}" "installed" "no — run: una apply"
    return 1
  fi
  line "${OK}" "installed" "$(cat "${STAMP}")"

  if "${HELPER}" has-evdi "${kver}"; then
    line "${OK}" "evdi" "built for ${kver}"
  else
    line "${BAD}" "evdi" "not built for the running kernel ${kver}"
    problems=1
  fi

  local dock speed
  if dock="$(dock_sysfs)"; then
    speed="$(cat "${dock}/speed" 2>/dev/null || echo "?")"
    if [[ "${speed}" == "480" ]]; then
      line "${WARN}" "dock" "$(cat "${dock}/product" 2>/dev/null) at USB 2.0 (480M) — flip the USB-C plug for USB 3"
    else
      line "${OK}" "dock" "$(cat "${dock}/product" 2>/dev/null) at ${speed}M"
    fi
  else
    line "${DIM}-${RESET}" "dock" "not connected"
  fi

  local state
  state="$(systemctl is-active "${SERVICE}" 2>/dev/null || true)"
  if [[ "${state}" == "active" ]]; then
    line "${OK}" "service" "running"
  elif [[ -n "${dock:-}" ]]; then
    line "${BAD}" "service" "${state:-inactive} (dock is connected) — una displaylink restart / logs"
    problems=1
  else
    line "${DIM}-${RESET}" "service" "${state:-inactive} (starts when a dock is plugged in)"
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    local mons
    # `monitors all`: plain `monitors` leaves out screens that are mirrors.
    mons="$(hyprctl monitors all 2>/dev/null | awk '
      /^Monitor /{if(n) print out; n=($2 ~ /^DVI-I-/); out=$2; next}
      n && /description:/{sub(/^[ \t]*description: /,""); out=out" ("$0")"}
      n && /disabled: true/{out=out" disabled"}
      n && /mirrorOf:/ && $2!="none"{out=out" mirroring"}
      END{if(n) print out}' | paste -sd ',' - | sed 's/,/, /g')"
    if [[ -n "${mons}" ]]; then
      line "${OK}" "monitors" "${mons}"
    elif [[ "${state}" == "active" && -n "${dock:-}" ]]; then
      line "${WARN}" "monitors" "none in Hyprland yet (is a monitor plugged into the dock?)"
    fi
  fi

  # Asahi USB-C PHY errors drop the dock. Only a warning while the dock is
  # missing; otherwise just say when it last happened.
  local phy count last
  phy="$(journalctl -k -b -q --no-pager -o short-iso 2>/dev/null | grep 'phy-apple-atc.*Failed to lock pipehandler' || true)"
  if [[ -n "${phy}" ]]; then
    count="$(grep -c . <<<"${phy}")"
    last="$(tail -1 <<<"${phy}" | awk '{print $1}' | sed -E 's/^[0-9-]+T([0-9:]+).*/\1/')"
    if [[ -z "${dock:-}" ]]; then
      line "${WARN}" "usb-c" "${count}× 'Failed to lock pipehandler' this boot, last at ${last} (Asahi USB-C PHY); replug the dock"
    else
      line "${DIM}-${RESET}" "usb-c" "${DIM}${count}× USB-C PHY error this boot, last at ${last}${RESET}"
    fi
  fi

  local pending
  pending="$("${HELPER}" pending 2>/dev/null || true)"
  if [[ -n "${pending}" ]]; then
    echo
    echo "evdi did not build for: ${pending//$'\n'/, }"
    if [[ -t 0 ]]; then
      local reply
      read -r -p "Choose which kernel to boot now? [Y/n] " reply || reply="n"
      if [[ "${reply}" != [nN]* ]]; then
        sudo "${HELPER}" choose
      fi
    else
      echo "Run: una displaylink kernel"
    fi
  elif ! "${HELPER}" has-evdi "${kver}"; then
    local fb
    fb="$("${HELPER}" fallback "${kver}" 2>/dev/null || true)"
    echo
    if [[ -n "${fb}" ]]; then
      echo "Kernel ${fb} has evdi. To boot it by default:  sudo grubby --set-default /boot/vmlinuz-${fb}"
    fi
    echo "To retry the build for this kernel:  sudo ${HELPER} check ${kver}"
  fi
  return "${problems}"
}

case "${1:-status}" in
  status) status ;;
  kernel) exec sudo "${HELPER}" choose "${2:-}" ;;
  restart)
    sudo systemctl reset-failed "${SERVICE}" 2>/dev/null || true
    exec sudo systemctl restart "${SERVICE}"
    ;;
  logs)
    echo "== journal (${SERVICE})"
    journalctl -b -u "${SERVICE}" -n 30 --no-pager 2>/dev/null || true
    echo "== kernel (evdi, DisplayLink USB, Asahi USB-C PHY)"
    journalctl -k -b -q --no-pager 2>/dev/null | grep -iE 'evdi|DisplayLink|phy-apple-atc' | grep -v mode_valid | tail -30 || true
    echo "${DIM}(/var/log/displaylink/*.log is encrypted; it is only useful to DisplayLink support)${RESET}"
    ;;
  -h | --help | help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)
    echo "usage: una displaylink [status|kernel|restart|logs]" >&2
    exit 2
    ;;
esac
