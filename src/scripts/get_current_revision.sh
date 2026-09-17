#!/usr/bin/env bash
# Print an id for the latest HEAD reflog entry, or NO_REFLOG if none exists.
#
# HEAD@{0} is always "whatever HEAD is now", so it is not stored as the id.
# The timestamped selector (HEAD@{unix-time}) plus the SHA identifies that
# reflog event, including checkout/reset back to a commit we already applied.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if git -C "${ASAHI_SETUP_ROOT}" reflog exists HEAD; then
  git -C "${ASAHI_SETUP_ROOT}" reflog show HEAD -1 --date=unix --format='%H@%gd'
else
  echo "NO_REFLOG"
fi
