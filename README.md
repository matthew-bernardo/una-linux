# Una Asahi Setup

This repo contains some convenience scripts for setting up an Asahi Linux
installation according to my personal preferences. Its goal is to make Linux
setups as portable and configurable as possible.

Run everything from a single entry point:

```bash
./apply_config.sh
```

That script currently has these install milestones:

1. Confirm this is Fedora Asahi Remix
2. Require LUKS on `/` and `/home` (see [Disk encryption](#disk-encryption))
3. Install `ansible-core` if `ansible-playbook` is missing
4. Install Hyprland and copy `configs/hypr` to `~/.config/hypr` (`hyprland.lua`; hyprlock/hypridle still use `.conf`). Copy `configs/kitty` to `~/.config/kitty` (tokyo-night / tokyo-light themes).
5. Install theme fonts (`FatPixelFont`, `VCR OSD Mono`) into `~/.local/share/fonts/una`
6. Install HyprPanel from [source](https://github.com/Jas-SinghFSU/HyprPanel) into `~/.una/HyprPanel` and copy themes to `~/.config/hyprpanel/themes`
7. Install zsh / oh-my-zsh, set `~/.zshrc`, copy `aliases.sh`/`functions.sh` to `~/.una`, and install `run_aliases.sh`
8. Install and enable ClamAV (daemon + signature updater)
9. Install user packages listed in `ansible/vars/packages.yml` (`vim`, `nvim`, …)

Hyprland, HyprPanel, the shell, ClamAV, and user packages are implemented in Ansible (`ansible/playbook.yml`).

Privileged milestones prompt for sudo on the terminal *before* the spinner starts, then keep a cached ticket so Ansible `become` can run `sudo -n`. That also writes `Defaults timestamp_type=global` to `/etc/sudoers.d/una-setup` so the ticket works without a tty.

## Disk encryption

The current NixOS install uses **LUKS** on the root partition (`cryptroot`), with `/` and `/home` on that unlocked volume. New Asahi machines should match that. If `/` (and a separate `/home`) is not LUKS-backed, `check_disk_encryption` asks whether to **quit** or **continue** without encryption (Sprinto disk-encryption checks will fail if you continue).

The Fedora Asahi installer still does not offer encryption. After a normal
install, encrypt the Asahi root partition in place with LUKS2 from a USB
rescue system. Then `setup_disk_encryption.sh` opens that volume as a device
mapper and writes `/etc/crypttab` with `discard` so Fedora’s `fstrim.timer`
can TRIM. `/boot` stays unencrypted, same as now.

Do not run `cryptsetup reencrypt` from the live Asahi root. Use a USB rescue
boot. Initramfs/GRUB (`rd.luks.uuid`) is not handled yet. Current walkthroughs:

- https://blog.fluxcoil.net/2026/05/fedora-asahi-remix-with-LUKS-encryption-in-2026/
- https://davidalger.com/posts/fedora-asahi-remix-on-apple-silicon-with-luks-encryption/

In the test container there is no real disk, so that check warns and continues.

## Re-runs

Each apply writes `.una_asahi_setup.json` (gitignored) with:

- the latest HEAD reflog id the script last ran against
- which milestones completed successfully

The reflog id looks like `abc123@HEAD@{1726566411}` (commit SHA plus the
timestamped reflog selector). `HEAD@{0}` is not used because it always means
"current HEAD", not a specific event.

On the same reflog entry, already-completed milestones are skipped. After HEAD
moves (commit, amend, checkout, reset, …) every milestone runs again. Editing
files without moving HEAD does not create a reflog entry, so those changes will
not retrigger steps. Delete the JSON file to force a full rerun.

If this checkout has no HEAD reflog yet, the recorded id is `NO_REFLOG`.

## Layout

```
apply_config.sh                 # entry point
scripts/
  check_if_should_run_step.sh
  is_rerunning_for_revision.sh
  is_step_complete_in_previous_run.sh
  mark_step_complete.sh
  run_step.sh
  install_ansible.sh
  install_window_manager.sh
  install_fonts.sh
  install_hyprpanel.sh
  install_shell.sh
  install_clamav.sh
  check_disk_encryption.sh
  setup_disk_encryption.sh
  install_packages.sh
ansible/                        # Hyprland, zsh, and user packages
configs/hypr/                   # Hyprland config to copy
configs/kitty/                  # kitty.conf + themes copied to ~/.config/kitty
configs/zsh/zshrc               # zshrc to copy
configs/zsh/aliases.sh          # copied to ~/.una/aliases.sh
configs/zsh/functions.sh        # copied to ~/.una/functions.sh
themes/fonts/                   # copied to ~/.local/share/fonts/una
```
