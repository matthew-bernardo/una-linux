#!/usr/bin/env bash
# Confirm this machine is a supported environment before applying config.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

"${_ASAHI_SETUP_SCRIPTS_DIR}/is_asahi_installed.sh"
