#!/usr/bin/env bash
# Build and start the una-setup Fedora aarch64 test container.
# Extra arguments are the command to run inside (default: interactive bash).
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${TEST_DIR}/.." && pwd)"
IMAGE_NAME="${UNA_TEST_IMAGE:-una-setup-test}"
CONTAINER_NAME="${UNA_TEST_CONTAINER:-una-setup-test}"
PLATFORM="${UNA_TEST_PLATFORM:-linux/arm64}"

if command -v docker >/dev/null 2>&1; then
  ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
  ENGINE=podman
else
  echo "test/run.sh: need docker or podman in PATH" >&2
  exit 1
fi

ensure_aarch64_emulation() {
  if [[ "${PLATFORM}" != "linux/arm64" ]]; then
    return 0
  fi
  if [[ "$(uname -m)" == "aarch64" ]]; then
    return 0
  fi
  if "${ENGINE}" run --rm --platform linux/arm64 fedora:44 uname -m >/dev/null 2>&1; then
    return 0
  fi

  echo "una-setup: registering QEMU binfmt for linux/arm64..."
  if ! "${ENGINE}" run --privileged --rm tonistiigi/binfmt --install arm64; then
    echo "test/run.sh: could not register aarch64 emulation (need privileged Docker/Podman)." >&2
    exit 1
  fi
}

run_flags=(-i)
if [[ -t 0 && -t 1 ]]; then
  run_flags=(-it)
fi

ensure_aarch64_emulation

"${ENGINE}" build --platform "${PLATFORM}" -t "${IMAGE_NAME}" -f "${TEST_DIR}/Dockerfile" "${TEST_DIR}"

if [[ -n "$("${ENGINE}" ps -q -f "name=${CONTAINER_NAME}")" ]]; then
  echo "una-setup: reusing running container ${CONTAINER_NAME}"
  if [[ $# -eq 0 ]]; then
    set -- bash
  fi
  exec "${ENGINE}" exec "${run_flags[@]}" "${CONTAINER_NAME}" "$@"
fi

if [[ -n "$("${ENGINE}" ps -aq -f "name=${CONTAINER_NAME}")" ]]; then
  "${ENGINE}" rm "${CONTAINER_NAME}" >/dev/null
fi

exec "${ENGINE}" run "${run_flags[@]}" --rm \
  --name "${CONTAINER_NAME}" \
  --hostname "${CONTAINER_NAME}" \
  --platform "${PLATFORM}" \
  -v "${ROOT}:/una-setup" \
  -v "${TEST_DIR}/os-release.fedora-asahi-remix:/etc/os-release:ro" \
  -e TERM="${TERM:-xterm-256color}" \
  -e RUN_LOG_FILE=/tmp/una_asahi_setup.json \
  -w /una-setup \
  "${IMAGE_NAME}" \
  "$@"
