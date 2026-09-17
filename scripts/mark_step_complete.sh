#!/usr/bin/env bash
# Record MILESTONE as successful for the current HEAD reflog entry.
# If the log belongs to a different reflog id, it is reset first.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 MILESTONE" >&2
  exit 2
fi

milestone="$1"
current_revision="$("${_ASAHI_SETUP_SCRIPTS_DIR}/get_current_revision.sh")"

python3 "${RUN_LOG_PY}" mark-complete "${RUN_LOG_FILE}" "${current_revision}" "${milestone}"
