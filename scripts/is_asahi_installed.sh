#!/usr/bin/env bash
# Exit 0 if this system is Fedora Asahi Remix. Exit 1 otherwise.
set -euo pipefail

os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
if [[ ! -r "${os_release_file}" && -r /usr/lib/os-release && -z "${OS_RELEASE_FILE:-}" ]]; then
  os_release_file="/usr/lib/os-release"
fi

if [[ ! -r "${os_release_file}" ]]; then
  echo "Could not read ${os_release_file}; Fedora Asahi Remix is required." >&2
  exit 1
fi

# os-release is designed to be sourced: KEY=value assignments only.
set +u
# shellcheck disable=SC1090
source "${os_release_file}"
set -u

id="${ID:-}"
id_like="${ID_LIKE:-}"
name="${NAME:-}"
pretty_name="${PRETTY_NAME:-}"
variant="${VARIANT:-}"
variant_id="${VARIANT_ID:-}"
detected="${pretty_name:-${name:-unknown OS}}"

is_fedora=0
case "${id}" in
  fedora | fedora-asahi-remix) is_fedora=1 ;;
esac
if [[ " ${id_like} " == *" fedora "* ]]; then
  is_fedora=1
fi

is_asahi=0
if [[ "${id}" == "fedora-asahi-remix" || "${variant_id}" == "asahi" ]]; then
  is_asahi=1
elif [[ "${name}" == *[Aa]sahi* || "${pretty_name}" == *[Aa]sahi* || "${variant}" == *[Aa]sahi* ]]; then
  is_asahi=1
fi

if [[ "${is_fedora}" -eq 1 && "${is_asahi}" -eq 1 ]]; then
  echo "Detected ${detected}"
  exit 0
fi

echo "This setup expects Fedora Asahi Remix, but this system is ${detected}." >&2
exit 1
