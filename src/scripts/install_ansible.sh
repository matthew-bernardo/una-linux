#!/usr/bin/env bash
# Install ansible-core so later milestones can run ansible-playbook.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook already installed: $(command -v ansible-playbook)"
  exit 0
fi

command -v dnf >/dev/null 2>&1 || {
  echo "error: dnf is required to install ansible-core" >&2
  exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
  dnf install -y ansible-core
else
  sudo dnf install -y ansible-core
fi
command -v ansible-playbook >/dev/null 2>&1
