#!/usr/bin/env bash
# If the Hyprland stack is installed from anywhere other than lionheartp/Hyprland,
# or another Hyprland COPR is enabled, ask before replacing that install.
# Called from apply_config.sh outside run_step so the question has a TTY.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TTY="/dev/tty"
STEP="ensure_hyprland_source"
EXPECTED_COPR="lionheartp/Hyprland"
EXPECTED_REPO="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"
STACK=(
  hyprland
  hyprland-guiutils
  xdg-desktop-portal-hyprland
  hyprlock
  hypridle
  hyprpaper
)

declare -A remove_set=()
declare -A foreign_repo_set=()
foreign_repo_ids=()
remove_names=()
package_notes=()
install_names=()
WORK=""

cleanup() {
  if [[ -n "${WORK}" && -d "${WORK}" ]]; then
    rm -rf "${WORK}"
  fi
}

say() {
  printf '%s\n' "$*" >"${TTY}"
}

ask() {
  local reply
  printf '%s' "$1" >"${TTY}"
  IFS= read -r reply <"${TTY}" || reply=""
  printf '%s\n' "${reply}"
}

require_tty() {
  [[ -r "${TTY}" && -w "${TTY}" ]] || {
    echo "error: ${STEP}.sh needs a terminal to ask before replacing Hyprland" >&2
    exit 1
  }
}

dnf_query() {
  local err rc
  err="${WORK}/dnf-err"
  set +e
  dnf "$@" 2>"${err}"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    cat "${err}" >&2
    return "${rc}"
  fi
}

is_stack_package() {
  local name="$1" pkg
  for pkg in "${STACK[@]}"; do
    [[ "${pkg}" == "${name}" ]] && return 0
  done
  return 1
}

is_foreign_hyprland_repo() {
  local id="$1" project
  [[ "${id}" != "${EXPECTED_REPO}" ]] || return 1
  [[ "${id}" == copr:copr.fedorainfracloud.org:* ]] || return 1
  project="${id##*:}"
  [[ "${project,,}" == *hyprland* ]]
}

copr_spec_from_repo_id() {
  local id="$1" rest owner project
  rest="${id#copr:copr.fedorainfracloud.org:}"
  owner="${rest%%:*}"
  project="${rest#*:}"
  printf '%s/%s\n' "${owner}" "${project}"
}

reset_findings() {
  foreign_repo_ids=()
  remove_names=()
  package_notes=()
  remove_set=()
  foreign_repo_set=()
}

consider_installed_line() {
  local name="$1" evr="$2" arch="$3" from_repo="$4"
  local replace=0
  if is_foreign_hyprland_repo "${from_repo}"; then
    replace=1
  elif is_stack_package "${name}" && [[ "${from_repo}" != "${EXPECTED_REPO}" ]]; then
    replace=1
  fi
  [[ "${replace}" -eq 1 ]] || return 0
  package_notes+=("$(printf '%s-%s.%s\t%s' "${name}" "${evr}" "${arch}" "${from_repo}")")
  if [[ -z "${remove_set[${name}]:-}" ]]; then
    remove_set["${name}"]=1
    remove_names+=("${name}")
  fi
}

consider_enabled_repo() {
  local id="$1"
  is_foreign_hyprland_repo "${id}" || return 0
  if [[ -z "${foreign_repo_set[${id}]:-}" ]]; then
    foreign_repo_set["${id}"]=1
    foreign_repo_ids+=("${id}")
  fi
}

findings_present() {
  [[ "${#remove_names[@]}" -gt 0 || "${#foreign_repo_ids[@]}" -gt 0 ]]
}

list_enabled_repo_ids() {
  dnf_query repolist --json | python3 -c 'import json, sys
for repo in json.load(sys.stdin):
    if repo.get("is_enabled", True):
        print(repo["id"])
'
}

sort_lines_into() {
  local array_name="$1"
  shift
  local line
  local -n target="${array_name}"
  target=()
  [[ "$#" -gt 0 ]] || return 0
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    target+=("${line}")
  done < <(printf '%s\n' "$@" | sort)
}

sort_findings() {
  if [[ "${#package_notes[@]}" -gt 0 ]]; then
    sort_lines_into package_notes "${package_notes[@]}"
  fi
  if [[ "${#foreign_repo_ids[@]}" -gt 0 ]]; then
    sort_lines_into foreign_repo_ids "${foreign_repo_ids[@]}"
  fi
}

load_system() {
  local installed enabled name evr arch from_repo id
  reset_findings
  installed="${WORK}/installed"
  enabled="${WORK}/enabled"
  dnf_query repoquery --installed --qf '%{name}|%{evr}|%{arch}|%{from_repo}\n' >"${installed}"
  list_enabled_repo_ids >"${enabled}"
  while IFS='|' read -r name evr arch from_repo; do
    [[ -n "${name}" ]] || continue
    [[ "${arch}" == "src" ]] && continue
    consider_installed_line "${name}" "${evr}" "${arch}" "${from_repo}"
  done <"${installed}"
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    consider_enabled_repo "${id}"
  done <"${enabled}"
  sort_findings
}

show_findings() {
  say ""
  if [[ "${#package_notes[@]}" -gt 0 ]]; then
    say "This Hyprland install is not from ${EXPECTED_COPR}."
  else
    say "Another Hyprland COPR is enabled, so later installs can come from there instead of ${EXPECTED_COPR}."
  fi
  say ""
  if [[ "${#foreign_repo_ids[@]}" -gt 0 ]]; then
    say "Other Hyprland COPRs enabled:"
    local id
    for id in "${foreign_repo_ids[@]}"; do
      say "  $(copr_spec_from_repo_id "${id}")"
      say "    ${id}"
    done
    say ""
  fi
  if [[ "${#package_notes[@]}" -gt 0 ]]; then
    local note nevra repo
    say "Packages that will be removed:"
    for note in "${package_notes[@]}"; do
      nevra="${note%%$'\t'*}"
      repo="${note#*$'\t'}"
      say "  ${nevra}"
      say "    from ${repo}"
    done
    say ""
    say "These will be installed from ${EXPECTED_COPR}:"
    say "  ${STACK[*]}"
    say "Other removed packages are reinstalled when that COPR ships them."
    say "Restart Hyprland afterwards if a session is running."
    say ""
  fi
}

prompt_choice() {
  local reply
  while true; do
    if [[ "${#package_notes[@]}" -gt 0 ]]; then
      say "  y — remove and reinstall from ${EXPECTED_COPR}"
    else
      say "  y — disable the other Hyprland COPRs"
    fi
    say "  s — skip this run"
    say "  n — don't ask again"
    reply="$(ask "Choice [s]: ")"
    case "${reply}" in
      y | Y | yes | YES) printf 'y\n'; return 0 ;;
      "" | s | S | skip | Skip) printf 's\n'; return 0 ;;
      n | never) printf 'n\n'; return 0 ;;
      *) say "Enter y, s, or n." ;;
    esac
  done
}

ensure_copr_plugin() {
  if dnf copr --help >/dev/null 2>&1; then
    return 0
  fi
  sudo -n dnf -y install dnf5-plugins
}

fedora_chroot() {
  local version_id arch
  version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID%%.*}")"
  arch="$(uname -m)"
  [[ -n "${version_id}" ]] || {
    echo "error: could not read Fedora version from /etc/os-release" >&2
    return 1
  }
  printf 'fedora-%s-%s\n' "${version_id}" "${arch}"
}

enable_expected_copr() {
  sudo -n dnf copr enable -y "${EXPECTED_COPR}" "$(fedora_chroot)"
}

packages_in_expected_repo() {
  local arch="$1"
  shift
  dnf_query repoquery --repo="${EXPECTED_REPO}" --qf '%{name} %{arch}\n' "$@" |
    awk -v want="${arch}" '$2 == want || $2 == "noarch" { print $1 }' |
    sort -u
}

build_install_names() {
  local arch name avail_file
  local -A available_set=()
  local -A seen=()
  local -a missing=()
  install_names=()
  arch="$(uname -m)"
  avail_file="${WORK}/available"
  packages_in_expected_repo "${arch}" "${STACK[@]}" "${remove_names[@]}" >"${avail_file}"
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    available_set["${name}"]=1
  done <"${avail_file}"
  for name in "${STACK[@]}"; do
    if [[ -z "${available_set[${name}]:-}" ]]; then
      missing+=("${name}")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    printf 'error: %s does not ship: %s\n' "${EXPECTED_COPR}" "${missing[*]}" >&2
    return 1
  fi
  for name in "${STACK[@]}"; do
    install_names+=("${name}")
    seen["${name}"]=1
  done
  for name in "${remove_names[@]}"; do
    if [[ -n "${available_set[${name}]:-}" && -z "${seen[${name}]:-}" ]]; then
      install_names+=("${name}")
    fi
  done
}

replace_packages() {
  local id
  local -a cmd=()
  build_install_names
  echo "Replacing Hyprland packages from ${EXPECTED_COPR}…"
  cmd=(sudo -n dnf -y)
  for id in "${foreign_repo_ids[@]}"; do
    cmd+=(--disable-repo="${id}")
  done
  cmd+=(do --allowerasing --allow-downgrade --action=remove)
  cmd+=("${remove_names[@]}")
  cmd+=(--action=install --from-repo="${EXPECTED_REPO}")
  cmd+=("${install_names[@]}")
  "${cmd[@]}"
}

disable_foreign_coprs() {
  local id spec
  for id in "${foreign_repo_ids[@]}"; do
    spec="$(copr_spec_from_repo_id "${id}")"
    echo "Disabling ${spec}…"
    sudo -n dnf copr disable -y "${spec}"
  done
}

verify_stack_source() {
  local name from pkg found_file
  local -A found=()
  found_file="${WORK}/verify-stack"
  dnf_query repoquery --installed --qf '%{name}|%{from_repo}\n' "${STACK[@]}" >"${found_file}"
  while IFS='|' read -r name from; do
    [[ -n "${name}" ]] || continue
    if [[ "${from}" != "${EXPECTED_REPO}" ]]; then
      echo "error: ${name} is still installed from ${from}" >&2
      return 1
    fi
    found["${name}"]=1
  done <"${found_file}"
  for pkg in "${STACK[@]}"; do
    if [[ -z "${found[${pkg}]:-}" ]]; then
      echo "error: ${pkg} is not installed from ${EXPECTED_COPR}" >&2
      return 1
    fi
  done
}

verify_foreign_coprs_disabled() {
  [[ "${#foreign_repo_ids[@]}" -gt 0 ]] || return 0
  local id enabled left=0
  local -A still=()
  enabled="${WORK}/verify-repos"
  list_enabled_repo_ids >"${enabled}"
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    still["${id}"]=1
  done <"${enabled}"
  for id in "${foreign_repo_ids[@]}"; do
    if [[ -n "${still[${id}]:-}" ]]; then
      echo "error: ${id} is still enabled" >&2
      left=1
    fi
  done
  [[ "${left}" -eq 0 ]]
}

apply_fix() {
  "${_ASAHI_SETUP_SCRIPTS_DIR}/ensure_sudo.sh"
  ensure_copr_plugin
  enable_expected_copr
  if [[ "${#remove_names[@]}" -gt 0 ]]; then
    replace_packages
    verify_stack_source
  fi
  disable_foreign_coprs
  verify_foreign_coprs_disabled
  if [[ "${#remove_names[@]}" -gt 0 ]]; then
    echo "Reinstalled Hyprland from ${EXPECTED_COPR}."
  else
    echo "Disabled other Hyprland COPRs. Further Hyprland installs come from ${EXPECTED_COPR}."
  fi
}

main() {
  command -v dnf >/dev/null 2>&1 || {
    echo "error: dnf is required to check the Hyprland install" >&2
    exit 1
  }
  command -v python3 >/dev/null 2>&1 || {
    echo "error: python3 is required to check the Hyprland install" >&2
    exit 1
  }

  WORK="$(mktemp -d)"
  trap cleanup EXIT

  load_system
  if ! findings_present; then
    exit 0
  fi
  if "${_ASAHI_SETUP_SCRIPTS_DIR}/is_step_permanently_skipped.sh" "${STEP}"; then
    echo "note: leaving the current Hyprland install (${STEP} is permanently skipped)"
    exit 0
  fi

  require_tty
  show_findings
  case "$(prompt_choice)" in
    y) apply_fix ;;
    n)
      "${_ASAHI_SETUP_SCRIPTS_DIR}/mark_step_permanently_skipped.sh" "${STEP}"
      say "Leaving the current Hyprland install. Won't ask again (recorded in ${RUN_LOG_FILE})."
      ;;
    s) say "Leaving the current Hyprland install for this run." ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
