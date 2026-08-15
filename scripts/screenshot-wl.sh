#!/usr/bin/env bash
set -euo pipefail

# ---------- timing helper (optional) ----------
if [[ "${DEBUG:-0}" == "1" ]]; then
    debug_start() { date +%s%N; }
    debug_end() {
        local start_ns=$1 desc="$2"
        local end_ns end_ms
        end_ns=$(date +%s%N)
        end_ms=$(( (end_ns - start_ns) / 1000000 ))
        echo "[DEBUG] ${desc}: ${end_ms} ms" >&2
    }
    OVERALL_START=$(debug_start)
    T_STEP_START=$OVERALL_START
else
    debug_start() { :; }
    debug_end() { :; }
fi

# ---------- argument parsing ----------
MODE="area"
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fullscreen) MODE="fullscreen" ;;
        -s|--screen)     MODE="screen" ;;
        -a|--area)       MODE="area" ;;
        -fa|-af|--fullarea) MODE="fullarea" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ---------- window class (background, non‑blocking) ----------
CLASS_NAME="unknown"
(
    ACTIVE_WIN=$(kdotool getactivewindow 2>/dev/null) || true
    if [[ -n $ACTIVE_WIN ]]; then
        NAME=$(kdotool getwindowclassname "$ACTIVE_WIN" 2>/dev/null || true)
        echo "$NAME" | tr '[:upper:]' '[:lower:]'
    fi
) > "/tmp/screenshot_class_$$" &
CLASS_PID=$!

# ---------- timestamp (single date call) ----------
read -r DAY HOUR MINUTE SECOND NANOSEC <<< "$(date +'%d %H %M %S %N')"
MS="${NANOSEC:0:3}"
FILENAME="${DAY}d;${HOUR}h;${MINUTE}m;${SECOND}s;${MS}ms"

# ---------- CAPTURE (instant if Spectacle is preloaded) ----------
T_STEP_START=$(debug_start)

TMP_FULL="/tmp/screenshot_$$_full.png"
case "$MODE" in
    fullscreen|screen) spectacle -bm -n -o "$TMP_FULL" || exit 0 ;;
    fullarea)          spectacle -bf -n -o "$TMP_FULL" || exit 0 ;;
    area)              spectacle -bm -n -o "$TMP_FULL" || exit 0 ;;
esac
debug_end "$T_STEP_START" "capture"

# ---------- wait for window class (max 0.3 s) ----------
wait "$CLASS_PID" 2>/dev/null || true
CLASS_FILE="/tmp/screenshot_class_$$"
if [[ -f $CLASS_FILE ]]; then
    CLASS_NAME=$(cat "$CLASS_FILE")
    rm -f "$CLASS_FILE"
fi

# ---------- final paths ----------
DIR="$HOME/Pictures/Screenshots/${CLASS_NAME}/$(date +%Y/%m)"
mkdir -p "$DIR"
FULL_PATH="${DIR}/${FILENAME}.png"

# ---------- POST‑PROCESSING ----------
T_STEP_START=$(debug_start)

case "$MODE" in
    fullscreen|screen)
        # Direct save – no editor
        mv "$TMP_FULL" "$FULL_PATH"
        ;;
    area|fullarea)
        # Open Satty for cropping/annotation
        satty -f "$TMP_FULL" -o "$FULL_PATH" --fullscreen \
            --save-after-copy \
            --actions-on-enter "save-to-file,exit" \
            --actions-on-right-click "exit" \
            --actions-on-escape "exit" \
            --no-window-decoration \
            --initial-tool "crop"
        ;;
esac
debug_end "$T_STEP_START" "post-processing (includes Satty if area)"

# ---------- clipboard & notification ----------
T_STEP_START=$(debug_start)
if command -v wl-copy >/dev/null; then
    wl-copy < "$FULL_PATH"
    notify-send "Screenshot captured" "Image copied to clipboard" -i "$FULL_PATH"
fi
debug_end "$T_STEP_START" "clipboard+notify"

# ---------- background optimisation ----------
if command -v oxipng >/dev/null; then
    oxipng -o max "$FULL_PATH" &
fi

# ---------- overall timing ----------
if [[ "${DEBUG:-0}" == "1" ]]; then
    debug_end "$OVERALL_START" "TOTAL"
fi
