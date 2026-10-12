#!/usr/bin/env bash
# xdg-desktop-portal-hyprland can wedge after a screencast: the picker still
# opens, but the stream never starts and CloseSession times out until both
# user portal services are restarted. That is runtime state, so this runs on
# every apply instead of as a skipped milestone.
set -euo pipefail

units=(
  xdg-desktop-portal-hyprland.service
  xdg-desktop-portal.service
)

if ! command -v systemctl >/dev/null 2>&1; then
  echo "note: systemctl is not available; not restarting desktop portals"
  exit 0
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "note: no systemd user session; not restarting desktop portals"
  exit 0
fi

for unit in "${units[@]}"; do
  if ! systemctl --user cat "${unit}" >/dev/null 2>&1; then
    echo "note: ${unit} is not installed; not restarting desktop portals"
    exit 0
  fi
done

echo "Restarting desktop portals…"
systemctl --user restart xdg-desktop-portal-hyprland.service
systemctl --user restart xdg-desktop-portal.service
