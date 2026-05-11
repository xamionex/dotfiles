#!/usr/bin/env bash
set -euo pipefail

MODE="area"
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fullscreen) MODE="fullscreen"; shift ;;
        -s|--screen)     MODE="screen"; shift ;;
        -a|--area)       MODE="area"; shift ;;
        -fa|-af|--fullarea) MODE="fullarea"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---- Inline window class detection (X11) ----
ACTIVE_WIN=$(xdotool getactivewindow 2>/dev/null) || ACTIVE_WIN=""
CLASS_NAME=""
if [[ -n $ACTIVE_WIN ]]; then
    CLASS_NAME=$(xdotool getwindowclassname "$ACTIVE_WIN" 2>/dev/null || true)
    # Lowercase
    CLASS_NAME=$(echo "$CLASS_NAME" | tr '[:upper:]' '[:lower:]')
fi
# ---- end class detection ----
DIR="$HOME/Pictures/Screenshots/${CLASS_NAME}/$(date +%Y/%m)"
mkdir -p "$DIR"

read -r DAY HOUR MINUTE SECOND NANOSEC <<< "$(date +'%d %H %M %S %N')"
MS="${NANOSEC:0:3}"

FILENAME="${DAY}d;${HOUR}h;${MINUTE}m;${SECOND}s;${MS}ms"
FULL_PATH="${DIR}/${FILENAME}.png"
FULL_PATH_TMP="${DIR}/${FILENAME}_no_annotations.png"

# ---- Capture full screen (X11) ----
flameshot screen --raw > "$FULL_PATH_TMP"

# ---- Mode‑based processing ----
if [[ -f "$FULL_PATH_TMP" ]]; then
    case "$MODE" in
        fullscreen|screen)
            mv "$FULL_PATH_TMP" "$FULL_PATH"
            ;;
        area|fullarea)
            satty -f "$FULL_PATH_TMP" -o "$FULL_PATH" --fullscreen \
                --save-after-copy \
                --actions-on-enter "save-to-file,exit" \
                --actions-on-right-click "exit" \
                --actions-on-escape "exit" \
                --no-window-decoration \
                --initial-tool "crop"
            ;;
    esac

    if [[ ! -s "$FULL_PATH" ]]; then
        rm -f "$FULL_PATH_TMP"
    fi
fi

[[ -s "$FULL_PATH" ]] || exit 0

# ---- Clipboard (X11) ----
if command -v xclip &>/dev/null; then
    xclip -selection clipboard -t image/png "$FULL_PATH"
else
    notify-send "Error" "xclip not found"
    exit 0
fi

notify-send "Screenshot captured" "Image copied to clipboard" -i "$FULL_PATH"

# ---- Background optimisation ----
if command -v oxipng &>/dev/null; then
    oxipng -o max "$FULL_PATH" &
    [[ -s "$FULL_PATH_TMP" ]] && oxipng -o max "$FULL_PATH_TMP" &
fi
