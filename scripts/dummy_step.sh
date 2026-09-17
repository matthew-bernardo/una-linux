#!/usr/bin/env bash
# Temporary step that sleeps, then exits with a spinner status.
# Usage: dummy_step.sh success|warning|fail
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 success|warning|fail" >&2
  exit 2
fi

status="$1"

sleep 5

case "${status}" in
  success)
    exit 0
    ;;
  warning)
    # Distinct from 1 (fail) and 2 (usage); run_step.sh maps this to ⚠️
    exit 3
    ;;
  fail)
    exit 1
    ;;
  *)
    echo "usage: $0 success|warning|fail" >&2
    exit 2
    ;;
esac
