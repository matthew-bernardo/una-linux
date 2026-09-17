# Animated pending indicator. Source this file; do not execute it.
# start_spinner MSG [LOG_FILE]
#   Draw frames on the first line until stop_spinner. If LOG_FILE is set,
#   show its latest 10 lines under the spinner. The spinner line always
#   animates; log lines are rewritten only when that snapshot changes.
# stop_spinner STATUS — kill the animation, replace the spinner line with an
#   emoji, then print the last 10 log lines (if any) as the persistent record.
#   STATUS: success | warning | fail  (also accepts ok/warn/error)

_SPINNER_PID=""
_SPINNER_MSG=""
_SPINNER_LOG=""
_SPINNER_LOG_WINDOW=10
_SPINNER_LOG_INDENT="    "

_SPINNER_FRAMES=(
  "🥚      "
  "🥚🥚    "
  "🥚🥚🥚  "
  "🥚🥚🥚🥚"
  "🐣🥚🥚🥚"
  "🐣🐣🥚🥚"
  "🐣🐣🐣🥚"
  "🐣🐣🐣🐣"
  "🐥🐣🐣🐣"
  "🐥🐥🐣🐣"
  "🐥🐥🐥🐣"
  "🐥🐥🐥🐥"
  "🐔🐥🐥🐥"
  "🐔🐔🐥🐥"
  "🐔🐔🐔🐥"
  "🐔🐔🐔🐔"
)

_spinner_hide_cursor() {
  if [[ -t 1 ]]; then
    tput civis 2>/dev/null || true
  fi
}

_spinner_show_cursor() {
  if [[ -t 1 ]]; then
    tput cnorm 2>/dev/null || true
  fi
}

_spinner_kill() {
  if [[ -z "${_SPINNER_PID}" ]]; then
    return 0
  fi
  kill "${_SPINNER_PID}" 2>/dev/null || true
  wait "${_SPINNER_PID}" 2>/dev/null || true
  _SPINNER_PID=""
}

_spinner_color_enabled() {
  [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]
}

_spinner_log_style_on() {
  if _spinner_color_enabled; then
    printf '\033[2m\033[38;2;178;178;178m'
  fi
}

_spinner_log_style_off() {
  if _spinner_color_enabled; then
    printf '\033[0m'
  fi
}

_spinner_term_cols() {
  local cols="${COLUMNS:-}"
  if [[ -z "${cols}" ]] && [[ -t 1 ]]; then
    cols="$(tput cols 2>/dev/null || true)"
  fi
  if [[ -z "${cols}" || "${cols}" -lt 20 ]]; then
    cols=80
  fi
  printf '%s' "${cols}"
}

_spinner_fit_line() {
  local line="${1//$'\r'/ }"
  local cols="$2"
  if (( ${#line} > cols )); then
    printf '%s' "${line:0:cols}"
  else
    printf '%s' "${line}"
  fi
}

_spinner_format_log_line() {
  local raw="$1"
  local cols="$2"
  local indent="${_SPINNER_LOG_INDENT}"
  local usable=$((cols - ${#indent}))
  if (( usable < 1 )); then
    usable=1
  fi
  printf '%s%s%s%s' \
    "$(_spinner_log_style_on)" \
    "${indent}" \
    "$(_spinner_fit_line "${raw}" "${usable}")" \
    "$(_spinner_log_style_off)"
}

_spinner_read_last_lines() {
  local file="${1:-}"
  local -n _spinner_lines_out=$2
  _spinner_lines_out=()
  if [[ -z "${file}" || ! -s "${file}" ]]; then
    return 0
  fi
  mapfile -t _spinner_lines_out < <(tail -n "${_SPINNER_LOG_WINDOW}" "${file}")
}

_spinner_same_snapshot() {
  local -n _spinner_snap_a=$1
  local -n _spinner_snap_b=$2
  local i
  if (( ${#_spinner_snap_a[@]} != ${#_spinner_snap_b[@]} )); then
    return 1
  fi
  for i in "${!_spinner_snap_a[@]}"; do
    if [[ "${_spinner_snap_a[i]}" != "${_spinner_snap_b[i]}" ]]; then
      return 1
    fi
  done
  return 0
}

_spinner_print_log_tail() {
  local lines=()
  local line cols
  _spinner_read_last_lines "${_SPINNER_LOG}" lines
  if (( ${#lines[@]} == 0 )); then
    return 0
  fi
  cols="$(_spinner_term_cols)"
  for line in "${lines[@]}"; do
    if [[ -t 1 ]]; then
      printf '\r\033[K%s\n' "$(_spinner_format_log_line "${line}" "${cols}")"
    else
      printf '%s\n' "$(_spinner_format_log_line "${line}" "${cols}")"
    fi
  done
}

start_spinner() {
  _SPINNER_MSG="${1:-loading}"
  _SPINNER_LOG="${2:-}"
  _spinner_kill
  _spinner_hide_cursor

  (
    extra=0
    in_log=0
    i=0
    tty=0
    prev=()
    if [[ -t 1 ]]; then
      tty=1
    fi
    trap 'if (( in_log && extra > 0 && tty )); then printf "\033[%dA\r" "${extra}"; fi; exit 0' TERM

    while true; do
      printf '\r\033[K%s [%s]...' "${_SPINNER_FRAMES[i]}" "${_SPINNER_MSG}"

      if (( tty )) && [[ -n "${_SPINNER_LOG}" ]]; then
        lines=()
        _spinner_read_last_lines "${_SPINNER_LOG}" lines
        if ! _spinner_same_snapshot lines prev; then
          old_extra=${#prev[@]}
          extra=${#lines[@]}
          draw_count=${extra}
          if (( old_extra > draw_count )); then
            draw_count=${old_extra}
          fi
          if (( draw_count > 0 )); then
            cols="$(_spinner_term_cols)"
            in_log=1
            idx=0
            while (( idx < extra )); do
              printf '\n'
              if (( idx >= old_extra )) || [[ "${lines[idx]}" != "${prev[idx]}" ]]; then
                printf '\r\033[K%s' "$(_spinner_format_log_line "${lines[idx]}" "${cols}")"
              fi
              idx=$((idx + 1))
            done
            while (( idx < old_extra )); do
              printf '\n\r\033[K'
              idx=$((idx + 1))
            done
            printf '\033[%dA\r' "${idx}"
            in_log=0
          fi
          if (( ${#lines[@]} > 0 )); then
            prev=("${lines[@]}")
          else
            prev=()
          fi
          extra=${#lines[@]}
        fi
      fi

      sleep 0.2
      i=$(((i + 1) % ${#_SPINNER_FRAMES[@]}))
    done
  ) &
  _SPINNER_PID=$!
}

stop_spinner() {
  local status="${1:-success}"
  local emoji

  _spinner_kill
  _spinner_show_cursor

  case "${status}" in
    success | ok | 0) emoji="✅" ;;
    warning | warn) emoji="⚠️" ;;
    fail | error | *) emoji="❌" ;;
  esac

  printf '\r\033[K%s [%s]\n' "${emoji}" "${_SPINNER_MSG}"
  _spinner_print_log_tail
}
