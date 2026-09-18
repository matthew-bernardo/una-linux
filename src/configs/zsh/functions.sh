scrot() {
  grim -g "$(slurp)" - | wl-copy
  notify "📸 Screenshot!" "Selection copied to clipboard"
}

dscrot() {
  selection="$(slurp)" || return 1
  sleep 2
  grim -g "$selection" - | wl-copy
  notify "📸 Screenshot!" "Selection copied to clipboard"
}

gpo() {
    git push --set-upstream origin $(git branch --show-current)
}

install_cursor() {
  curl -L \
  "$(curl -s 'https://api2.cursor.sh/updates/api/download/stable/linux-arm64/cursor' | jq -r '.downloadUrl')" \
  -o ~/.local/bin/cursor

  chmod +x ~/.local/bin/cursor
}

# Uses Wofi to prompt the user to pick a repo
ide() {
  set -o pipefail

  # Folders to search
  local roots=("$HOME/personal_code" "$HOME/stacksync")

  # Parallel arrays: names[] for display, paths[] for full paths
  local -a names=()
  local -a paths=()

  # Build the arrays
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    # Find top-level git repos under each root (adjust depths if needed)
    while IFS= read -r -d '' gitdir; do
      local repo name
      repo="${gitdir%/.git}"          # strip trailing /.git
      name="${repo#$root/}"           # relative label
      names+=("$name")
      paths+=("$repo")
    done < <(find "$root" -mindepth 2 -maxdepth 4 -type d -name .git -print0)
  done

  # No repos found
  ((${#names[@]})) || { echo "No repos found under ${roots[*]}"; return 1; }

  # Let Wofi pick from names[]
  local choice
  choice="$(printf '%s\n' "${names[@]}" \
           | wofi --dmenu --prompt 'Open repo' --matching fuzzy --allow-markup)" || return 1

  # Cancelled
  [[ -n "$choice" ]] || return 0

  # Find index of the chosen name
  local idx=-1
  for i in "${!names[@]}"; do
    if [[ "${names[i]}" == "$choice" ]]; then
      idx="$i"
      break
    fi
  done
  (( idx >= 0 )) || { echo "Selection not found."; return 1; }

  # Map to path via index
  local path="${paths[idx]}"
  [[ -d "$path" ]] || { echo "Selected path not found: $path"; return 1; }

  local opener="~/AppImages/cursor"

  # Open in background
  ~/AppImages/cursor --classic $path
}

notify() {
  # Usage: notify "Title" "Message" [timeout_ms]
  local title="${1:-Notification}"
  local body="${2:-}"
  local timeout="${3:-5000}"  # default: 5s

  gdbus call --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify \
    "bash" 0 "" "$title" "$body" [] {} "$timeout" >/dev/null 2>&1
}


nix_clean() {
  # Defaults
  local keep=3
  local auto=false

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        auto=true
        ;;
      -k|--keep)
        keep="$2"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        echo "Usage: nix_clean [-y|--yes] [-k|--keep N]"
        return 1
        ;;
    esac
    shift
  done

  # Interactive prompt if not auto
  if [[ "$auto" != true ]]; then
    echo -e "\033[1;33mThis will delete all but the most recent system generations and perform a full garbage collection.\033[0m"
    echo "Current default: keep last $keep generations."

    read -rp "How many generations would you like to keep? [$keep]: " input_keep
    if [[ -n "$input_keep" ]]; then
      if [[ "$input_keep" =~ ^[0-9]+$ && "$input_keep" -ge 2 ]]; then
        keep="$input_keep"
      else
        echo "⚠️  Invalid number (must be >= 2). Keeping $keep."
      fi
    fi

    echo -e "\nThis will run:"
    echo "  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --keep $keep"
    echo "  sudo nix-collect-garbage -d"
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }
  fi

  # Run commands
  echo -e "\033[1;34m→ Keeping $keep generations and cleaning...\033[0m"
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --keep "$keep"
  sudo nix-collect-garbage -d
  echo -e "\033[1;32m✔ Done!\033[0m"
}

# Add to your ~/.bashrc or ~/.zshrc
set_cursor() {
  # Usage: set_cursor [THEME] [SIZE]
  # If THEME is omitted, shows a picker (wofi -> fzf -> tty prompt).
  # SIZE defaults to 24.

  local theme="$1"
  local size="${2:-24}"

  # Directories to search for cursor themes
  local -a icon_dirs=(
    "$HOME/.icons"
    "$HOME/.local/share/icons"
    "$HOME/.nix-profile/share/icons"
    "/nix/var/nix/profiles/per-user/$USER/profile/share/icons"
    "/run/current-system/sw/share/icons"
    "/usr/share/icons"
  )

  _list_cursor_themes() {
    for d in "${icon_dirs[@]}"; do
      [[ -d "$d" ]] || continue
      # -L follows symlinks; we then test for a 'cursors' subdir
      while IFS= read -r p; do
        [[ -d "$p/cursors" ]] && basename "$p"
      done < <(find -L "$d" -mindepth 1 -maxdepth 1 -print 2>/dev/null)
    done | sort -u
  }

  _apply_theme() {
    local t="$1" s="$2"
    if [[ -z "$t" ]]; then
      echo "No theme selected."; return 1
    fi
    # Export for current shell/session
    export HYPRCURSOR_THEME="$t"
    export HYPRCURSOR_SIZE="$s"
    export XCURSOR_THEME="$t"
    export XCURSOR_SIZE="$s"

    # Apply live in Hyprland if available
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl setcursor "$t" "$s" >/dev/null 2>&1 || true
    fi

    # Friendly message
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Cursor theme set" "$t ($s)"
    else
      echo "→ Cursor theme set to '$t' ($s)"
    fi
  }

  # If THEME provided, just apply
  if [[ -n "$theme" ]]; then
    _apply_theme "$theme" "$size"
    return
  fi

  # Otherwise, build list and present a picker
  local themes
  if ! themes="$(_list_cursor_themes)"; then
    echo "Failed to enumerate cursor themes."; return 1
  fi
  if [[ -z "$themes" ]]; then
    echo "No cursor themes found in:"
    printf '  - %s\n' "${icon_dirs[@]}"
    return 1
  fi

  # Try wofi (Wayland), then fzf, then minimal TTY picker
  if command -v wofi >/dev/null 2>&1; then
    # Use user's style if defined
    local selection
    if [[ -n "$WOFI_STYLE" ]]; then
      selection="$(printf '%s\n' "$themes" | wofi --show dmenu --gtk-dark --style "$WOFI_STYLE")"
    else
      selection="$(printf '%s\n' "$themes" | wofi --show dmenu --gtk-dark)"
    fi
    theme="$selection"
  elif command -v fzf >/dev/null 2>&1; then
    theme="$(printf '%s\n' "$themes" | fzf --prompt='Cursor theme > ' --height=40%)"
  else
    echo "Select a cursor theme:"
    nl -w2 -s'. ' <(printf '%s\n' "$themes")
    read -rp "Enter number: " idx
    theme="$(printf '%s\n' "$themes" | sed -n "${idx}p")"
  fi

  _apply_theme "$theme" "$size"
}

toggleTerminalTheme() {
    local config="$HOME/.config/kitty/current-theme.conf"

    if grep -q 'themes/tokyo-night.conf' "$config"; then
        echo 'include themes/tokyo-light.conf' > "$config"
    else
        echo 'include themes/tokyo-night.conf' > "$config"
    fi

    pkill -USR1 kitty
}
