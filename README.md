# Una Asahi Setup

This repo contains some convenience scripts for setting up an Asahi Linux
installation according to my personal preferences. Its goal is to make Linux
setups as portable and configurable as possible.

Run everything from a single entry point:

```bash
./apply_config.sh
```

That script currently has three install milestones:

1. Install Hyprland and copy `configs/hypr` to `~/.config/hypr`
2. Install zsh / oh-my-zsh and set `~/.zshrc`
3. Install user packages listed in `ansible/vars/packages.yml`

All three will live in Ansible (`ansible/playbook.yml`). The installer scripts are stubs for now.

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
  install_window_manager.sh
  install_shell.sh
  install_packages.sh
ansible/                        # Hyprland, zsh, and user packages
configs/hypr/                   # Hyprland config to copy
configs/zsh/zshrc               # zshrc to copy
```
