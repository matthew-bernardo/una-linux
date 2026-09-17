#!/usr/bin/env bash
# Run a milestone script unless it already succeeded for the current reflog id.
# While the script is running, a spinner occupies the current line and the
# latest 10 lines of the script's output sit underneath it (indented, dimmed,
# redrawn only when that snapshot changes). When it finishes:
#   ✅  exit 0
#   ⚠️  exit 3 (warning; still marked complete)
#   ❌  any other non-zero exit
# then the last 10 lines of output (omitted when the script printed nothing).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "${_ASAHI_SETUP_SCRIPTS_DIR}/_spinner.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 MILESTONE SCRIPT [ARGS...]" >&2
  exit 2
fi

milestone="$1"
step_script="$2"
shift 2

if ! "${_ASAHI_SETUP_SCRIPTS_DIR}/check_if_should_run_step.sh" "${milestone}"; then
  echo "Skipping ${milestone} (already completed for current reflog id)"
  exit 0
fi

step_log=""
cleanup_run_step() {
  if [[ -n "${_SPINNER_PID}" ]]; then
    stop_spinner fail
  else
    _spinner_show_cursor
  fi
  if [[ -n "${step_log}" ]]; then
    rm -f "${step_log}"
  fi
}
trap cleanup_run_step EXIT

display_name="${milestone//_/ }"
step_log="$(mktemp)"
start_spinner "${display_name}" "${step_log}"

set +e
"${step_script}" "$@" >"${step_log}" 2>&1
step_status=$?
set -e

if [[ "${step_status}" -eq 0 ]]; then
  stop_spinner success
elif [[ "${step_status}" -eq 3 ]]; then
  stop_spinner warning
else
  stop_spinner fail
fi

rm -f "${step_log}"
step_log=""

if [[ "${step_status}" -eq 0 || "${step_status}" -eq 3 ]]; then
  "${_ASAHI_SETUP_SCRIPTS_DIR}/mark_step_complete.sh" "${milestone}"
  exit 0
fi

exit "${step_status}"
