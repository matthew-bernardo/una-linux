#!/usr/bin/env bash
# Install zsh + oh-my-zsh and install this repo's zshrc as ~/.zshrc.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

echo "this is where we'd install zsh"
echo "this is where we'd install oh-my-zsh"
echo "this is where we'd copy ${ASAHI_SETUP_ROOT}/configs/zsh/zshrc to ${HOME}/.zshrc"
echo "this is where we'd run: ansible-playbook ${ASAHI_SETUP_ROOT}/ansible/playbook.yml --tags shell"
