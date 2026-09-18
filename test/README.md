# Test environment

This directory is a **Fedora aarch64 container** that stands in for a Fedora
Asahi Remix machine so you can run `./apply_config.sh` without Apple Silicon.

It is not Asahi. Asahi will not boot in QEMU or Docker on this PC. The guest
is Fedora 44 `aarch64` (current stable, same userspace generation as Asahi)
with `/etc/os-release` replaced by a fixture that looks like Fedora Asahi
Remix, which is enough for `validate_environment`.

On an x86_64 host the guest runs under QEMU user emulation (`linux/arm64`).
That is slower than native, but `dnf` resolves the same aarch64 packages a
Mac would.

## What this is for

- Exercising the installer: milestones, skip logic, spinner, Ansible tags
- Installing Hyprland / zsh / ClamAV / user packages from Fedora aarch64 + COPRs

The LUKS disk-encryption check **warns** here (exit 3) instead of failing: the guest has no real encrypted disk. On a Mac it is a hard requirement.

Success here means the **setup tool** ran and packages installed for
`aarch64`. It does not mean Hyprland would start on a Mac.

## What this is not for

- Apple GPU, DRM, or a real Hyprland session
- Native aarch64 performance (this host emulates it)

## Usage

From the repo root (Docker or Podman):

```bash
./test/run.sh
```

That registers QEMU binfmt if needed, builds the image, and opens a shell
with this checkout mounted at `/una-setup`. Then:

```bash
./apply_config.sh
```

To run apply in one shot:

```bash
./test/run.sh ./apply_config.sh
```

The apply run log is `/tmp/una_asahi_setup.json` inside the container, so it
does not write root-owned files into the repo. Each new container starts
clean (`--rm`). If a container named `una-setup-test` is already running, the
script execs into it instead.

## Image

`test/Dockerfile` is Fedora 44 aarch64 plus git, python3, ncurses (`tput`),
and `ansible-core`. First build is slow on x86_64 because `dnf` runs under
emulation; later builds are cached.
