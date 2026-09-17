#!/usr/bin/env bash
# Apply this checkout's Asahi Linux config. Safe to re-run: milestones that
# already succeeded for the current HEAD reflog entry are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${ROOT}/src/scripts"

"${SCRIPTS}/print_una_header.sh"
echo "una: applying config from ${ROOT}"
echo "una: revision $("${SCRIPTS}/get_current_revision.sh")"

"${SCRIPTS}/run_step.sh" validate_environment "${SCRIPTS}/validate_environment.sh"

# Dummy steps to exercise spinner statuses (success / warning / fail).
"${SCRIPTS}/run_step.sh" dummy_success "${SCRIPTS}/dummy_step.sh" success
"${SCRIPTS}/run_step.sh" dummy_warning "${SCRIPTS}/dummy_step.sh" warning
# Expected to fail; continue so later milestones still run.
"${SCRIPTS}/run_step.sh" dummy_fail "${SCRIPTS}/dummy_step.sh" fail || \
  "${SCRIPTS}/mark_step_complete.sh" dummy_fail

"${SCRIPTS}/run_step.sh" install_window_manager "${SCRIPTS}/install_window_manager.sh"
"${SCRIPTS}/run_step.sh" install_shell "${SCRIPTS}/install_shell.sh"
"${SCRIPTS}/run_step.sh" install_packages "${SCRIPTS}/install_packages.sh"

echo "una: done"
