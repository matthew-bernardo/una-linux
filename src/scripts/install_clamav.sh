#!/usr/bin/env bash
# Install ClamAV, enable the daemon and signature updater.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ansible-playbook \
  --inventory "${ASAHI_SETUP_ROOT}/ansible/inventory.ini" \
  "${ASAHI_SETUP_ROOT}/ansible/playbook.yml" \
  --tags clamav
