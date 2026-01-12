#!/usr/bin/env bash

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
        -s|--screen)
        MODE="screen"
        shift
        ;;
        -a|--area)
        MODE="area"
        shift
        ;;
        -fa|-af|--fullarea)
        MODE="fullarea"
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
FILENAME="${DAY}d;${HOUR}h;${MINUTE}m;${SECOND}s;${MILLISECONDS}ms"
FULL_PATH="${DIR}/${FILENAME}.png"
FULL_PATH_NO_ANNOTATIONS="${DIR}/${FILENAME}_no_annotations.png"

# Detect session type
if [[ -n $WAYLAND_DISPLAY ]]; then
    SESSION="wayland"
elif [[ -n $DISPLAY ]]; then
    SESSION="x11"
else
    echo "Could not detect session type"
    exit 1
fi

# Check if we're in KDE
if [[ $XDG_CURRENT_DESKTOP == *"KDE"* ]] || [[ $XDG_SESSION_DESKTOP == "plasma" ]]; then
    KDE=true
else
    KDE=false
fi

SPECTACLEFLAG=f
if [[ "$MODE" == "area" ]] || [[ "$MODE" == "screen" ]]; then
	SPECTACLEFLAG=m
fi

# Take screenshot - ALWAYS capture full screen
if [[ $SESSION == "x11" ]]; then
    flameshot screen --raw > "$FULL_PATH_NO_ANNOTATIONS"
else
    # Wayland
    if [[ $KDE == true ]]; then
        # KDE Wayland - full screen capture
        spectacle -b -$SPECTACLEFLAG -n -o "$FULL_PATH_NO_ANNOTATIONS"
    else
        # Non-KDE Wayland (wlroots), not tested
        grim "$FULL_PATH_NO_ANNOTATIONS"
    fi
fi

# Then process based on mode
if [[ -f "$FULL_PATH_NO_ANNOTATIONS" ]]; then
    case "$MODE" in
        "fullscreen"|"screen")
            # Just copy/rename the file
            mv "$FULL_PATH_NO_ANNOTATIONS" "$FULL_PATH"
            ;;
        "area"|"fullarea")
            # Open in satty for cropping
            satty -f "$FULL_PATH_NO_ANNOTATIONS" -o "$FULL_PATH" --fullscreen \
                --save-after-copy \
                --actions-on-enter "save-to-file,exit" \
                --actions-on-right-click "exit" \
                --actions-on-escape "exit" \
                --no-window-decoration \
                --initial-tool "crop"
            ;;
    esac
    
    # Clean up temp file if final screenshot is empty
    if [[ ! -s "$FULL_PATH" ]]; then
        rm "$FULL_PATH_NO_ANNOTATIONS"
    fi
fi

# Check if screenshot was captured
if [[ ! -s "$FULL_PATH" ]]; then
    exit 0
fi

# Optimize with oxipng
oxipng "$FULL_PATH"
if [[ -s "$FULL_PATH_NO_ANNOTATIONS" ]]; then
	oxipng "$FULL_PATH_NO_ANNOTATIONS"
fi

if $UPLOAD; then
    # Upload to copyparty and get URL
    UPLOAD_URL="$COPYPARTY_URL/$FILENAME"
    UPLOADED_URL=$(curl -s -T "$FULL_PATH" -H "pw: $COPYPARTY_PW" -w "%{url_effective}\n" -o /dev/null "$UPLOAD_URL")
    UPLOADED_URL=${UPLOADED_URL//http:\/\/ip.petar.cc:3939/https:\/\/fb.petar.cc}

    # Copy URL to clipboard
    if [[ $SESSION == "wayland" ]] && command -v wl-copy &>/dev/null; then
        echo -n "$UPLOADED_URL" | wl-copy
    elif [[ $SESSION == "x11" ]] && command -v xclip &>/dev/null; then
        echo -n "$UPLOADED_URL" | xclip -selection clipboard
    else
    	notify-send "Error" "Failed to copy to clipboard"
    	exit 0
    fi

    # Send notification with URL
    notify-send "Screenshot uploaded" "URL copied to clipboard: ${UPLOADED_URL}" -i "$FULL_PATH"
else
    # Copy image to clipboard
    if [[ $SESSION == "wayland" ]] && command -v wl-copy &>/dev/null; then
        wl-copy < "$FULL_PATH"
    elif [[ $SESSION == "x11" ]] && command -v xclip &>/dev/null; then
        xclip -selection clipboard -t image/png "$FULL_PATH"
    else
    	notify-send "Error" "Failed to copy to clipboard"
      	exit 0
    fi
    
    # Send notification
    notify-send "Screenshot captured" "Image copied to clipboard" -i "$FULL_PATH"
fi
