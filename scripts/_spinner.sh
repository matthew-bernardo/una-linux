# Animated pending indicator. Source this file; do not execute it.
# start_spinner MSG  — draw frames on the current line until stop_spinner
# stop_spinner STATUS — kill the animation and replace the line with an emoji
#   STATUS: success | warning | fail  (also accepts ok/warn/error)

_SPINNER_PID=""
_SPINNER_MSG=""

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

start_spinner() {
  _SPINNER_MSG="${1:-loading}"
  _spinner_kill
  _spinner_hide_cursor

  (
    i=0
    while true; do
      printf "\r\033[K%s [%s]..." "${_SPINNER_FRAMES[i]}" "${_SPINNER_MSG}"
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

  printf "\r\033[K%s [%s]\n" "${emoji}" "${_SPINNER_MSG}"
}
