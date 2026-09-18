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
# Interactive: needs a TTY (not wrapped in run_step).
"${SCRIPTS}/setup_disk_encryption.sh"
"${SCRIPTS}/run_step.sh" check_disk_encryption "${SCRIPTS}/check_disk_encryption.sh"

"${SCRIPTS}/run_step.sh" --sudo install_ansible "${SCRIPTS}/install_ansible.sh"
"${SCRIPTS}/run_step.sh" --sudo install_window_manager "${SCRIPTS}/install_window_manager.sh"
"${SCRIPTS}/run_step.sh" install_fonts "${SCRIPTS}/install_fonts.sh"
"${SCRIPTS}/run_step.sh" --sudo install_hyprpanel "${SCRIPTS}/install_hyprpanel.sh"
"${SCRIPTS}/run_step.sh" --sudo install_shell "${SCRIPTS}/install_shell.sh"
"${SCRIPTS}/run_step.sh" --sudo install_clamav "${SCRIPTS}/install_clamav.sh"
"${SCRIPTS}/run_step.sh" --sudo install_packages "${SCRIPTS}/install_packages.sh"

echo "una: done"
