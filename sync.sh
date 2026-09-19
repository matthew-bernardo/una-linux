#!/usr/bin/env bash
# Compare live config files with this checkout and prompt which version to keep.
# Live → repo keeps your edits. Repo → live reverts the installed copy.
# Themes are not synced (src/themes, kitty theme files).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT}/src/scripts/_common.sh"

CONFIGS="${ASAHI_SETUP_ROOT}/configs"
TTY="/dev/tty"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--check]

Compare non-theme config files in this repo with the live copies on disk.
For each difference you pick a version:

  l  keep live  (copy live → repo)
  r  keep repo  (copy repo → live)
  s  skip this file
  L  keep live for this file and the rest
  R  keep repo for this file and the rest
  q  quit

--check  list diffs and exit (1 if anything differs, 0 if in sync)
EOF
}

CHECK_ONLY=0
case "${1:-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  --check)
    CHECK_ONLY=1
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  CYAN=$'\033[36m'
  MAGENTA=$'\033[35m'
  RESET=$'\033[0m'
  DIFF_COLOR=(--color=always)
else
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  CYAN=""
  MAGENTA=""
  RESET=""
  DIFF_COLOR=()
fi

say() {
  printf '%s\n' "$*"
}

hr() {
  local width="${1:-58}"
  local line
  printf -v line '%*s' "${width}" ''
  say "${DIM}${line// /─}${RESET}"
}

print_banner() {
  "${ROOT}/src/scripts/print_una_header.sh"
  say "${BOLD}${MAGENTA}una${RESET} ${CYAN}sync${RESET}  ${DIM}·${RESET}  live configs vs this checkout"
  say ""
}

# repo-relative path under configs/ → live path
declare -A FILE_MAP=(
  [zsh/zshrc]="${HOME}/.zshrc"
  [zsh/aliases.sh]="${HOME}/.una/aliases.sh"
  [zsh/functions.sh]="${HOME}/.una/functions.sh"
  [zsh/run_aliases.sh]="${HOME}/.config/una/bin/run_aliases.sh"
  [una/una]="${HOME}/.config/una/bin/una"
  [wayle/config.toml]="${HOME}/.config/wayle/config.toml"
)

# configs/<name>/ → live directory (contents, not themes)
declare -A DIR_MAP=(
  [hypr]="${HOME}/.config/hypr"
  [kitty]="${HOME}/.config/kitty"
)

should_skip() {
  local rel="$1"
  local base="${rel##*/}"
  case "${rel}" in
    themes | themes/* | */themes | */themes/*) return 0 ;;
  esac
  case "${base}" in
    current-theme.conf | hyprland.conf | .DS_Store | *.bak | *~ | *.swp | *.swo) return 0 ;;
  esac
  return 1
}

pretty() {
  local p="$1"
  if [[ "${p}" == "${ROOT}/"* ]]; then
    printf '%s' "${p#"${ROOT}/"}"
  elif [[ "${p}" == "${HOME}"/* ]]; then
    printf '%s' "~${p#"${HOME}"}"
  else
    printf '%s' "${p}"
  fi
}

list_rel_files() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 0
  find "${dir}" -type f -printf '%P\n' | LC_ALL=C sort
}

declare -a PAIR_REPO=()
declare -a PAIR_LIVE=()
declare -A PAIR_SEEN=()

add_pair() {
  local repo="$1"
  local live="$2"
  local key="${repo}"$'\t'"${live}"
  [[ -z "${PAIR_SEEN["${key}"]:-}" ]] || return 0
  PAIR_SEEN["${key}"]=1
  PAIR_REPO+=("${repo}")
  PAIR_LIVE+=("${live}")
}

collect_dir_pairs() {
  local name="$1"
  local repo_dir="${CONFIGS}/${name}"
  local live_dir="${DIR_MAP[${name}]}"
  local rel

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    should_skip "${rel}" && continue
    add_pair "${repo_dir}/${rel}" "${live_dir}/${rel}"
  done < <(list_rel_files "${repo_dir}")

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    should_skip "${rel}" && continue
    add_pair "${repo_dir}/${rel}" "${live_dir}/${rel}"
  done < <(list_rel_files "${live_dir}")
}

warn_unmapped() {
  local dir name rel key
  for dir in "${CONFIGS}"/*; do
    [[ -d "${dir}" ]] || continue
    name="${dir##*/}"
    if [[ -n "${DIR_MAP[${name}]:-}" ]]; then
      continue
    fi
    while IFS= read -r rel; do
      [[ -n "${rel}" ]] || continue
      key="${name}/${rel}"
      if [[ -z "${FILE_MAP[${key}]:-}" ]]; then
        say "  ${YELLOW}⚠️${RESET}  no live path for ${DIM}configs/${key}${RESET}"
      fi
    done < <(list_rel_files "${dir}")
  done
}

same_file() {
  local a b
  a="$(realpath "$1" 2>/dev/null || true)"
  b="$(realpath "$2" 2>/dev/null || true)"
  [[ -n "${a}" && "${a}" == "${b}" ]]
}

is_text() {
  grep -qI '' "$1" 2>/dev/null
}

files_match() {
  local repo="$1"
  local live="$2"
  if same_file "${repo}" "${live}"; then
    return 0
  fi
  [[ -e "${repo}" && -e "${live}" ]] || return 1
  cmp -s "${repo}" "${live}"
}

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "${dest}")"
  cp --preserve=mode -- "${src}" "${dest}"
}

keep_live() {
  local repo="$1"
  local live="$2"
  if copy_file "${live}" "${repo}"; then
    copied_to_repo+=("$(pretty "${repo}")")
    return 0
  fi
  say "  ${RED}❌${RESET}  could not write ${BOLD}$(pretty "${repo}")${RESET}" >&2
  skipped+=("$(pretty "${repo}")")
  return 1
}

keep_repo() {
  local repo="$1"
  local live="$2"
  if copy_file "${repo}" "${live}"; then
    copied_to_live+=("$(pretty "${live}")")
    return 0
  fi
  say "  ${RED}❌${RESET}  could not write ${BOLD}$(pretty "${live}")${RESET}" >&2
  skipped+=("$(pretty "${live}")")
  return 1
}

show_file_card() {
  local repo="$1"
  local live="$2"
  local index="$3"
  local total="$4"
  local title
  title="$(basename "${repo}")"

  say ""
  hr
  say "  ${BOLD}${MAGENTA}${index}/${total}${RESET}  ${BOLD}${title}${RESET}"
  hr
  say "  ${CYAN}📦  repo${RESET}  $(pretty "${repo}")"
  say "  ${GREEN}💻  live${RESET}  $(pretty "${live}")"
  say ""
}

indent_diff() {
  sed 's/^/  /'
}

show_diff() {
  local repo="$1"
  local live="$2"
  local repo_label live_label
  repo_label="repo: $(pretty "${repo}")"
  live_label="live: $(pretty "${live}")"

  if [[ ! -e "${repo}" ]]; then
    say "  ${YELLOW}🐣${RESET}  ${DIM}new live file — not in the repo yet${RESET}"
    if [[ -e "${live}" ]] && is_text "${live}"; then
      diff "${DIFF_COLOR[@]}" -u --label "${repo_label}" --label "${live_label}" /dev/null "${live}" | indent_diff || true
    fi
    return
  fi
  if [[ ! -e "${live}" ]]; then
    say "  ${YELLOW}👻${RESET}  ${DIM}live copy is missing${RESET}"
    if is_text "${repo}"; then
      diff "${DIFF_COLOR[@]}" -u --label "${repo_label}" --label "${live_label}" "${repo}" /dev/null | indent_diff || true
    fi
    return
  fi
  if ! is_text "${repo}" || ! is_text "${live}"; then
    say "  ${YELLOW}🪨${RESET}  ${DIM}binary files differ${RESET}"
    return
  fi
  diff "${DIFF_COLOR[@]}" -u --label "${repo_label}" --label "${live_label}" "${repo}" "${live}" | indent_diff || true
}

have_tty() {
  [[ -r "${TTY}" && -w "${TTY}" ]]
}

prompt() {
  local msg="$1"
  local reply
  printf '%s' "${msg}" >"${TTY}"
  read -r reply <"${TTY}"
  printf '%s' "${reply}"
}

print_banner

# Collect mappings
for name in "${!DIR_MAP[@]}"; do
  collect_dir_pairs "${name}"
done
for rel in "${!FILE_MAP[@]}"; do
  add_pair "${CONFIGS}/${rel}" "${FILE_MAP[${rel}]}"
done
warn_unmapped

if ((${#PAIR_REPO[@]} > 0)); then
  sorted="$(
    for i in "${!PAIR_REPO[@]}"; do
      printf '%s\t%s\n' "${PAIR_REPO[i]}" "${PAIR_LIVE[i]}"
    done | LC_ALL=C sort
  )"
  PAIR_REPO=()
  PAIR_LIVE=()
  while IFS=$'\t' read -r repo live; do
    [[ -n "${repo}" ]] || continue
    PAIR_REPO+=("${repo}")
    PAIR_LIVE+=("${live}")
  done <<<"${sorted}"
fi

declare -a DIFF_REPO=()
declare -a DIFF_LIVE=()
in_sync=0
for i in "${!PAIR_REPO[@]}"; do
  repo="${PAIR_REPO[i]}"
  live="${PAIR_LIVE[i]}"
  if files_match "${repo}" "${live}"; then
    in_sync=$((in_sync + 1))
    continue
  fi
  DIFF_REPO+=("${repo}")
  DIFF_LIVE+=("${live}")
done

if ((${#DIFF_REPO[@]} == 0)); then
  say "${GREEN}✅${RESET}  all ${BOLD}${in_sync}${RESET} configs match — nothing to chase"
  say ""
  exit 0
fi

say "${GREEN}✅${RESET}  ${BOLD}${in_sync}${RESET} already match"
say "${YELLOW}⚠️${RESET}   ${BOLD}${#DIFF_REPO[@]}${RESET} drifted"

if ((CHECK_ONLY)) || ! have_tty; then
  total=${#DIFF_REPO[@]}
  for i in "${!DIFF_REPO[@]}"; do
    show_file_card "${DIFF_REPO[i]}" "${DIFF_LIVE[i]}" "$((i + 1))" "${total}"
    show_diff "${DIFF_REPO[i]}" "${DIFF_LIVE[i]}"
    say ""
  done
  if ((CHECK_ONLY)); then
    say "${DIM}re-run without --check to pick a version${RESET}"
    say ""
    exit 1
  fi
  say "${RED}❌${RESET}  no TTY to pick a version — re-run from a terminal" >&2
  exit 1
fi

declare -a copied_to_repo=()
declare -a copied_to_live=()
declare -a skipped=()
apply_remaining=""
total=${#DIFF_REPO[@]}

for i in "${!DIFF_REPO[@]}"; do
  repo="${DIFF_REPO[i]}"
  live="${DIFF_LIVE[i]}"
  remaining=$((total - i - 1))

  if [[ -n "${apply_remaining}" ]]; then
    if [[ "${apply_remaining}" == live ]]; then
      if [[ ! -e "${live}" ]]; then
        skipped+=("$(pretty "${repo}")")
        say "  ${DIM}⏭️${RESET}   $(pretty "${repo}") ${DIM}(no live file)${RESET}"
      elif keep_live "${repo}" "${live}"; then
        say "  ${GREEN}💻 → 📦${RESET}  $(pretty "${repo}")"
      fi
    else
      if [[ ! -e "${repo}" ]]; then
        skipped+=("$(pretty "${live}")")
        say "  ${DIM}⏭️${RESET}   $(pretty "${live}") ${DIM}(no repo file)${RESET}"
      elif keep_repo "${repo}" "${live}"; then
        say "  ${CYAN}📦 → 💻${RESET}  $(pretty "${live}")"
      fi
    fi
    continue
  fi

  show_file_card "${repo}" "${live}" "$((i + 1))" "${total}"
  show_diff "${repo}" "${live}"
  say ""

  can_live=0
  can_repo=0
  [[ -e "${live}" ]] && can_live=1
  [[ -e "${repo}" ]] && can_repo=1

  say "  ${BOLD}which version should una keep?${RESET}"
  say ""
  if ((can_live)); then
    say "    ${GREEN}${BOLD}l${RESET}  💻  live   ${DIM}copy into the repo${RESET}"
  fi
  if ((can_repo)); then
    say "    ${CYAN}${BOLD}r${RESET}  📦  repo   ${DIM}restore the live file${RESET}"
  fi
  say "    ${DIM}s${RESET}  ⏭️   skip"
  if ((remaining > 0)); then
    if ((can_live)); then
      say "    ${GREEN}${BOLD}L${RESET}  💻  live for this + ${remaining} more"
    fi
    if ((can_repo)); then
      say "    ${CYAN}${BOLD}R${RESET}  📦  repo for this + ${remaining} more"
    fi
  fi
  say "    ${RED}${BOLD}q${RESET}  👋  quit"
  say ""

  while true; do
    reply="$(prompt "  ${MAGENTA}❯${RESET} ")"
    case "${reply}" in
      l | live)
        if ! ((can_live)); then
          printf '%s\n' "  ${YELLOW}hmm,${RESET} live file is missing — pick another option." >"${TTY}"
          continue
        fi
        if keep_live "${repo}" "${live}"; then
          say "  ${GREEN}✅${RESET}  kept live ${DIM}→${RESET} $(pretty "${repo}")"
        fi
        break
        ;;
      r | repo)
        if ! ((can_repo)); then
          printf '%s\n' "  ${YELLOW}hmm,${RESET} repo file is missing — pick another option." >"${TTY}"
          continue
        fi
        if keep_repo "${repo}" "${live}"; then
          say "  ${GREEN}✅${RESET}  kept repo ${DIM}→${RESET} $(pretty "${live}")"
        fi
        break
        ;;
      L)
        if ! ((can_live)); then
          printf '%s\n' "  ${YELLOW}hmm,${RESET} live file is missing — pick another option." >"${TTY}"
          continue
        fi
        if keep_live "${repo}" "${live}"; then
          apply_remaining=live
          say "  ${GREEN}✅${RESET}  kept live ${DIM}→${RESET} $(pretty "${repo}")  ${DIM}(and the rest)${RESET}"
        fi
        break
        ;;
      R)
        if ! ((can_repo)); then
          printf '%s\n' "  ${YELLOW}hmm,${RESET} repo file is missing — pick another option." >"${TTY}"
          continue
        fi
        if keep_repo "${repo}" "${live}"; then
          apply_remaining=repo
          say "  ${GREEN}✅${RESET}  kept repo ${DIM}→${RESET} $(pretty "${live}")  ${DIM}(and the rest)${RESET}"
        fi
        break
        ;;
      s | skip)
        skipped+=("$(pretty "${repo}")")
        say "  ${DIM}⏭️${RESET}   skipped"
        break
        ;;
      q | quit)
        skipped+=("$(pretty "${repo}")")
        for ((j = i + 1; j < total; j++)); do
          skipped+=("$(pretty "${DIFF_REPO[j]}")")
        done
        say "  ${MAGENTA}👋${RESET}  una stepped out"
        apply_remaining=quit
        break
        ;;
      *)
        printf '%s\n' "  ${YELLOW}hmm,${RESET} try l, r, s, or q." >"${TTY}"
        ;;
    esac
  done
  if [[ "${apply_remaining}" == quit ]]; then
    break
  fi
done

say ""
hr
say "  ${BOLD}${MAGENTA}✨  all set${RESET}"
hr
if ((${#copied_to_repo[@]} > 0)); then
  say "  ${GREEN}💻 → 📦${RESET}  copied to repo"
  for f in "${copied_to_repo[@]}"; do
    say "           ${f}"
  done
fi
if ((${#copied_to_live[@]} > 0)); then
  say "  ${CYAN}📦 → 💻${RESET}  copied to live"
  for f in "${copied_to_live[@]}"; do
    say "           ${f}"
  done
fi
if ((${#skipped[@]} > 0)); then
  say "  ${DIM}⏭️${RESET}         skipped"
  for f in "${skipped[@]}"; do
    say "           ${f}"
  done
fi
say ""
