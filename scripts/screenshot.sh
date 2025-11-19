#!/usr/bin/env bash

# Only use Flameshot as requested
SCREENSHOT_TOOL="flameshot"
MODE="area"  # Default to area selection
UPLOAD=false  # Default to not uploading

# Copyparty configuration
COPYPARTY_URL="https://upload.petar.cc/Upload/petar"
COPYPARTY_PW="petargaming"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fullscreen)
        MODE="fullscreen"
        shift
        ;;
        -a|--area)
        MODE="area"
        shift
        ;;
        -u|--upload)
        UPLOAD=true
        shift
        ;;
        *)
        echo "Unknown option: $1"
        echo "Usage: $0 [-f|--fullscreen] [-a|--area] [-u|--upload]"
        exit 1
        ;;
    esac
done

# Create directory path
CLASS_NAME=$(/home/petar/scripts/get_active_window.sh 2>/dev/null)
DIR="$HOME/Pictures/Screenshots/${CLASS_NAME}/$(date +"%Y")/$(date +"%m")"
mkdir -p "$DIR"

# Generate filename components
TIMESTAMP=$(date +"%d %H %M %S %N")
DAY=$(echo "$TIMESTAMP" | awk '{print $1}')
HOUR=$(echo "$TIMESTAMP" | awk '{print $2}')
MINUTE=$(echo "$TIMESTAMP" | awk '{print $3}')
SECOND=$(echo "$TIMESTAMP" | awk '{print $4}')
MILLISECONDS=$(echo "$TIMESTAMP" | awk '{print $5}' | cut -b1-3)

# Create filename and path
FILENAME="${DAY}d;${HOUR}h;${MINUTE}m;${SECOND}s;${MILLISECONDS}ms.png"
FULL_PATH="${DIR}/${FILENAME}"

# Take screenshot with Flameshot
case "$MODE" in
    "fullscreen")
        flameshot full --raw > "$FULL_PATH"
        ;;
    "area")
        flameshot gui --raw > "$FULL_PATH"
        ;;
esac

# Check if screenshot was captured
if [[ ! -s "$FULL_PATH" ]]; then
    exit 0
fi

if $UPLOAD; then
    # Upload to copyparty and get URL
    UPLOAD_URL="$COPYPARTY_URL/$FILENAME"
    UPLOADED_URL=$(curl -s -T "$FULL_PATH" -H "pw: $COPYPARTY_PW" -w "%{url_effective}\n" -o /dev/null "$UPLOAD_URL")
    UPLOADED_URL=${UPLOADED_URL//http:\/\/ip.petar.cc:3939/https:\/\/fb.petar.cc}

    # Copy URL to clipboard
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
        echo -n "$UPLOADED_URL" | wl-copy
    elif [ -n "$DISPLAY" ] && command -v xclip &>/dev/null; then
        echo -n "$UPLOADED_URL" | xclip -selection clipboard
    fi

    # Send notification with URL
    notify-send "Screenshot uploaded" "URL copied to clipboard: ${UPLOADED_URL}" -i "$FULL_PATH"
else
    # Copy image to clipboard
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
        wl-copy < "$FULL_PATH"
    elif [ -n "$DISPLAY" ] && command -v xclip &>/dev/null; then
        xclip -selection clipboard -t image/png "$FULL_PATH"
    fi
    
    # Send notification
    notify-send "Screenshot captured" "Image copied to clipboard" -i "$FULL_PATH"
fi
