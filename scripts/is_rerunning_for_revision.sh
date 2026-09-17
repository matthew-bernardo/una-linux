#!/usr/bin/env bash
# Exit 0 if a previous run was recorded against a different HEAD reflog entry.
# Exit 1 if there is no log, or the log already matches the current reflog id.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [[ ! -f "${RUN_LOG_FILE}" ]]; then
  exit 1
fi

current_revision="$("${_ASAHI_SETUP_SCRIPTS_DIR}/get_current_revision.sh")"
logged_revision="$(python3 "${RUN_LOG_PY}" get-revision "${RUN_LOG_FILE}")"

if [[ -z "${logged_revision}" || "${logged_revision}" != "${current_revision}" ]]; then
  exit 0
fi

exit 1
