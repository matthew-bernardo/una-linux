#!/usr/bin/env bash
# Print a short reminder, then exec the container command (default: bash).
set -euo pipefail

if [[ -t 1 ]]; then
  cat <<'EOF'
una-setup test container — ordinary Fedora, fake Asahi /etc/os-release.

  ./apply_config.sh

EOF
fi

exec "$@"
