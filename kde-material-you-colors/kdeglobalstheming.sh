#!/usr/bin/env bash

config="$HOME/.config/kdeglobals"
output="$HOME/.config/equibop/themes/kdeglobals.css"
millennium_config="$HOME/.config/millennium/config.json"

# Function to extract color from a given section and key
get_color() {
    section="$1"
    key="$2"
    awk -v section="$section" -v key="$key" '
        $0 == "[" section "]" { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $1 ~ key "=" {
            split($0, a, "=")
            gsub(" ", "", a[2])
            print a[2]
            exit
        }
    ' "$config"
}

# Function to convert RGB to hex
rgb_to_hex() {
    r=$1
    g=$2
    b=$3
    printf "#%02x%02x%02x\n" "$r" "$g" "$b"
}

# Function to generate the CSS for equibop and update Millennium config
generate_css() {
    highlight=$(get_color "Colors:Selection" "BackgroundNormal")
    accent_rgb="${highlight:-255,77,77}"  # Fallback to red

    # Extract RGB components
    IFS=',' read -r r g b <<< "$accent_rgb"

    # Normalize to [0,1]
    rf=$(awk "BEGIN {print $r / 255}")
    gf=$(awk "BEGIN {print $g / 255}")
    bf=$(awk "BEGIN {print $b / 255}")

    # Calculate hue
    read -r h <<< "$(awk -v r=$rf -v g=$gf -v b=$bf '
        function max(a,b){ return (a>b)?a:b }
        function min(a,b){ return (a<b)?a:b }

        BEGIN {
            maxc = max(r, max(g, b));
            minc = min(r, min(g, b));
            delta = maxc - minc;

            if (delta == 0) {
                hue = 0;
            } else if (maxc == r) {
                hue = 60 * (((g - b) / delta) % 6);
            } else if (maxc == g) {
                hue = 60 * (((b - r) / delta) + 2);
            } else {
                hue = 60 * (((r - g) / delta) + 4);
            }

            if (hue < 0) hue += 360;
            printf "%.0f\n", hue;
        }')"

    cat > "$output" <<EOF
:root {
  --accent-hue: ${h} !important;
}
EOF

    echo "[equibop] Accent hue set to ${h} from rgb(${r},${g},${b})"

    # Update Millennium config
    if [ -f "$millennium_config" ]; then
        # Convert RGB to hex
        hex_color=$(rgb_to_hex "$r" "$g" "$b")
        
        # Use jq to update the accentColor in the general section
        if command -v jq >/dev/null 2>&1; then
            jq --arg color "$hex_color" '.general.accentColor = $color' "$millennium_config" > "${millennium_config}.tmp" && \
            mv "${millennium_config}.tmp" "$millennium_config"
            echo "[millennium] Updated general.accentColor to ${hex_color}"
        else
            echo "[millennium] Error: jq is not installed. Please install jq to update config.json"
        fi
    else
        echo "[millennium] Config file not found: $millennium_config"
    fi
}

generate_css
