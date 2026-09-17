# Shared paths for asahi_setup helper scripts.
# Source this file; do not execute it.

_ASAHI_SETUP_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASAHI_SETUP_ROOT="$(cd "${_ASAHI_SETUP_SCRIPTS_DIR}/.." && pwd)"
RUN_LOG_FILE="${RUN_LOG_FILE:-${ASAHI_SETUP_ROOT}/.una_asahi_setup.json}"
RUN_LOG_PY="${_ASAHI_SETUP_SCRIPTS_DIR}/_run_log.py"
