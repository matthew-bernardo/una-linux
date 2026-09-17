#!/usr/bin/env bash
# Exit 0 if MILESTONE should run. Exit 1 if it can be skipped for this reflog id.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 MILESTONE" >&2
  exit 2
fi

milestone="$1"

if "${_ASAHI_SETUP_SCRIPTS_DIR}/is_rerunning_for_revision.sh"; then
  exit 0
fi

if "${_ASAHI_SETUP_SCRIPTS_DIR}/is_step_complete_in_previous_run.sh" "${milestone}"; then
  exit 1
fi

exit 0
