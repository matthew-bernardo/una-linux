#!/usr/bin/env bash
# Install theme fonts from src/themes/fonts into ~/.local/share/fonts/una.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags fonts
