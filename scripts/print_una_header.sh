#!/usr/bin/env bash
# Print una's cat + wordmark. Side-by-side when the terminal is wide enough.
set -euo pipefail

GAP="  | "

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  CYAN=$'\033[36m'
  MAGENTA=$'\033[35m'
  RESET=$'\033[0m'
else
  CYAN=""
  MAGENTA=""
  RESET=""
fi

mapfile -t CAT_ART <<'EOF'

 _._     _,-'""`-._
(,-.`._,'(       |\`-/|
    `-.-' \ )-`( , o o)
          `-    \`_`"'-
EOF

mapfile -t UNA_ART <<'EOF'
  _   _ _   _    _    
 | | | | \ | |  / \   
 | | | |  \| | / _ \  
 | |_| | |\  |/ ___ \ 
  \___/|_| \_/_/   \_\                   
EOF

rtrim() {
  local s="$1"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

max_visible_width() {
  local max=0 trimmed
  local line
  for line in "$@"; do
    trimmed="$(rtrim "${line}")"
    if (( ${#trimmed} > max )); then
      max=${#trimmed}
    fi
  done
  printf '%s' "${max}"
}

terminal_cols() {
  local cols
  if [[ -n "${COLUMNS:-}" ]]; then
    printf '%s' "${COLUMNS}"
    return
  fi
  if cols="$(tput cols 2>/dev/null)" && [[ "${cols}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${cols}"
    return
  fi
  if cols="$(stty size 2>/dev/null | awk '{print $2}')" && [[ "${cols}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${cols}"
    return
  fi
  printf '%s' "80"
}

print_block() {
  local color="$1"
  shift
  local line
  for line in "$@"; do
    printf '%s%s%s\n' "${color}" "${line}" "${RESET}"
  done
}

print_side_by_side() {
  local -n left_lines="$1"
  local -n right_lines="$2"
  local left_width="$3"
  local gap="$4"
  local max_lines="${#left_lines[@]}"
  if (( ${#right_lines[@]} > max_lines )); then
    max_lines=${#right_lines[@]}
  fi

  local i left_line right_line
  for ((i = 0; i < max_lines; i++)); do
    left_line="${left_lines[i]:-}"
    right_line="${right_lines[i]:-}"
    printf '%s%-*s%s%s%s%s%s\n' \
      "${CYAN}" "${left_width}" "${left_line}" "${RESET}" \
      "${gap}" \
      "${MAGENTA}" "${right_line}" "${RESET}"
  done
}

cat_width="$(max_visible_width "${CAT_ART[@]}")"
una_width="$(max_visible_width "${UNA_ART[@]}")"
cols="$(terminal_cols)"
needed=$((cat_width + ${#GAP} + una_width))

printf '\n'
if (( cols >= needed )); then
  print_side_by_side CAT_ART UNA_ART "${cat_width}" "${GAP}"
else
  print_block "${CYAN}" "${CAT_ART[@]}"
  printf '\n'
  print_block "${MAGENTA}" "${UNA_ART[@]}"
fi
printf '\n'
