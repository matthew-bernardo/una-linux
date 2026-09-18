#!/usr/bin/env bash
# Install Hyprland and the tools its config uses, then copy configs/hypr into ~/.config/hypr.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags hyprland
