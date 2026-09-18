#!/usr/bin/env bash

ALIASES_FILE=~.unaaliases.sh
FUNCTIONS_FILE=~.unafunctions.sh

# Source the files so aliases and functions are available
source "$ALIASES_FILE"
source "$FUNCTIONS_FILE"

shopt -s expand_aliases

# Extract alias names
alias_list=$(grep '^alias ' "$ALIASES_FILE" | sed 's/^alias \([^=]*\)=.*/\1/')

# Extract function names
function_list=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "$FUNCTIONS_FILE" | sed 's/().*//')

# Combine for the menu
menu_list=$(printf "%s\n%s\n" "$alias_list" "$function_list")

# Show wofi selector
selected=$(printf "%s\n" "$menu_list" | wofi --show dmenu --gtk-dark --columns=2 \
    --style /home/matthew/.config/wofi/style.css)

# If nothing selected, exit gracefully
[[ -z "$selected" ]] && echo "No selection." && exit 0

# Run the selected alias or function
echo "Running: $selected"
eval "$selected"

