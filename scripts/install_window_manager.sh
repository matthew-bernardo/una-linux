#!/usr/bin/env bash
# Install Hyprland and copy this repo's Hyprland config into ~/.config/hypr.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

echo "this is where we'd install Hyprland"
echo "this is where we'd copy ${ASAHI_SETUP_ROOT}/configs/hypr to ${HOME}/.config/hypr"
echo "this is where we'd run: ansible-playbook ${ASAHI_SETUP_ROOT}/ansible/playbook.yml --tags hyprland"
