#!/usr/bin/env bash
# Record STEP as permanently skipped in .una_asahi_setup.json.
# Survives HEAD reflog changes; delete the JSON file to undo.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 STEP" >&2
  exit 2
fi

python3 "${RUN_LOG_PY}" mark-skip "${RUN_LOG_FILE}" "$1"
