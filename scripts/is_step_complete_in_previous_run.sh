#!/usr/bin/env bash
# Exit 0 if MILESTONE is listed as completed in .una_asahi_setup.json.
# Exit 1 otherwise (missing log, or the step has not succeeded yet).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 MILESTONE" >&2
  exit 2
fi

milestone="$1"

if [[ ! -f "${RUN_LOG_FILE}" ]]; then
  exit 1
fi

python3 "${RUN_LOG_PY}" has-milestone "${RUN_LOG_FILE}" "${milestone}"
