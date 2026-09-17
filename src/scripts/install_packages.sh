#!/usr/bin/env bash
# Install user packages listed for Fedora (dnf) via Ansible.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

echo "this is where we'd install packages listed in ${ASAHI_SETUP_ROOT}/ansible/vars/packages.yml"
echo "this is where we'd run: ansible-playbook ${ASAHI_SETUP_ROOT}/ansible/playbook.yml --tags packages"
