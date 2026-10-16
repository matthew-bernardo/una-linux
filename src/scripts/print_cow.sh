#!/usr/bin/env bash
# Print a random ASCII cow for the hyprlock label. hyprlock polls this
# (cmd[update:250]); the cow only changes after a random 1-2 s, and never
# to the same pose twice in a row. Output is pango-escaped.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/una_cow_state"

# Every cow is 6 lines so the label does not jump when it changes.
COWS=(
'        (__)
        (oo)
  /------\/
 / |    ||
*  /\---/\
   ~~   ~~'
'        (__)
        (--)  z
  /------\/  z
 / |    ||
*  /\---/\
   ~~   ~~'
'        (__)
        (OO)  !
  /------\/
 / |    ||
*  /\---/\
   ~~   ~~'
'        (__)
        (o-)
  /------\/
 / |    ||
*  /\---/\
   ~~   ~~'
'        (__)   moo!
        (oo)  /
  /------\/
 / |    ||
*  /\---/\
   ~~   ~~'
'        (__)
        (oo)
  /------\/
 / |    ||
*  /\---/\
,,,~~,,,~~,,,'
'        (__)
        (^^)
  /------\/  ~
 / |    ||
*  /\---/\
   ~~   ~~'
)

now_ms="$(date +%s%3N)"
idx=-1
next_ms=0
if [[ -r "${STATE}" ]]; then
  read -r idx next_ms <"${STATE}" || true
fi

if (( idx < 0 || idx >= ${#COWS[@]} || now_ms >= next_ms )); then
  new=$((RANDOM % ${#COWS[@]}))
  if (( ${#COWS[@]} > 1 )); then
    while (( new == idx )); do
      new=$((RANDOM % ${#COWS[@]}))
    done
  fi
  idx=${new}
  next_ms=$((now_ms + 1000 + RANDOM % 1001))
  printf '%s %s\n' "${idx}" "${next_ms}" >"${STATE}"
fi

cow="${COWS[idx]}"
cow="${cow//&/&amp;}"
cow="${cow//</&lt;}"
cow="${cow//>/&gt;}"
printf '%s\n' "${cow}"
