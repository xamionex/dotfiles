#!/bin/bash

CONFIG_DIR="$HOME/.config/fastfetch"
LOGOS_DIR="$CONFIG_DIR/logos"
[[ -d "$LOGOS_DIR" ]] || exit 0

# Extract distro identifiers
DISTRO_INFO=$(grep -E '^(ID|ID_LIKE|NAME)=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
DISTROS=($(echo "$DISTRO_INFO" | tr ' ' '\n' | awk '!seen[$0]++'))

# Try each distro name for matches
for distro in "${DISTROS[@]}"; do
    LOGO=$(find "$LOGOS_DIR" -type f -iname "*${distro}*.png" | shuf -n1)
    [[ -n "$LOGO" ]] && echo "$LOGO" && exit 0
done

# Fallbacks: default logo or any random one
[[ -f "$LOGOS_DIR/default.png" ]] && echo "$LOGOS_DIR/default.png" && exit 0
find "$LOGOS_DIR" -type f -iname "*.png" | shuf -n1 2>/dev/null || echo ""
