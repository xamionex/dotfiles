#!/bin/bash

file="$HOME/.config/fastfetch/lines.json"
range=$(jq -r 'length' "$file")
RANDOM=$PPID
n=$((RANDOM % range + 1))

# Fast gradient function using pure bash arithmetic
colorize_gradient() {
    local text="$1"
    local gradient_type="${2:-random}"  # Default to random
    local gradient_style="${3:-radial}"  # Default to radial
    local length=${#text}
    local result=""
    
    # Define gradient types array for random selection
    local gradient_types=("fire" "water" "grass" "ice" "sunset" "rainbow")
    
    # If gradient_type is random, pick one randomly
    if [ "$gradient_type" = "random" ]; then
        gradient_type=${gradient_types[$((RANDOM % ${#gradient_types[@]}))]}
    fi
    
    # Define different gradient color sets with stops
    case $gradient_type in
        fire)
            # Fire: black -> dark red -> red -> orange -> yellow -> white
            colors=(
                "0 0 0 0"         # Black - 0%
                "128 0 0 20"      # Dark Red - 20%
                "255 0 0 40"      # Red - 40%
                "255 69 0 50"     # Red-Orange - 50%
                "255 140 0 60"    # Orange - 60%
                "255 165 0 65"    # Dark Orange - 65%
                "255 215 0 75"    # Gold - 75%
                "255 255 0 85"    # Yellow - 85%
                "255 255 128 90"  # Light Yellow - 90%
                "255 255 255 100" # White - 100%
            )
            ;;
        water)
            # Water: deep blue -> blue -> cyan -> light blue -> white
            colors=(
                "0 0 64 0"        # Deep Blue - 0%
                "0 0 128 25"      # Navy - 25%
                "0 0 255 40"      # Blue - 40%
                "0 100 255 55"    # Medium Blue - 55%
                "0 191 255 70"    # Deep Sky Blue - 70%
                "64 224 208 80"   # Turquoise - 80%
                "135 206 250 90"  # Light Sky Blue - 90%
                "224 255 255 100" # Light Cyan - 100%
            )
            ;;
        grass)
            # Grass: dark green -> green -> light green -> yellow-green
            colors=(
                "0 32 0 0"        # Dark Green - 0%
                "0 64 0 20"       # Deep Green - 20%
                "0 100 0 35"      # Forest Green - 35%
                "0 128 0 50"      # Green - 50%
                "50 205 50 65"    # Lime Green - 65%
                "124 252 0 75"    # Lawn Green - 75%
                "144 238 144 85"  # Light Green - 85%
                "173 255 47 100"  # Green Yellow - 100%
            )
            ;;
        ice)
            # Ice: dark blue -> blue -> light blue -> cyan -> white
            colors=(
                "0 0 80 0"        # Dark Blue - 0%
                "0 50 128 20"     # Medium Blue - 20%
                "0 100 200 40"    # Steel Blue - 40%
                "100 150 255 60"  # Light Steel Blue - 60%
                "150 200 255 75"  # Very Light Blue - 75%
                "175 220 255 85"  # Ice Blue - 85%
                "220 240 255 95"  # Pale Blue - 95%
                "255 255 255 100" # White - 100%
            )
            ;;
        sunset)
            # Sunset: purple -> red -> orange -> yellow -> pink
            colors=(
                "75 0 130 0"      # Indigo - 0%
                "148 0 211 25"    # Dark Violet - 25%
                "199 21 133 40"   # Medium Violet Red - 40%
                "255 0 0 55"      # Red - 55%
                "255 69 0 65"     # Red Orange - 65%
                "255 140 0 75"    # Dark Orange - 75%
                "255 165 0 80"    # Orange - 80%
                "255 215 0 90"    # Gold - 90%
                "255 182 193 100" # Light Pink - 100%
            )
            ;;
        rainbow|*)
            # Default rainbow - no percentages specified, will be distributed evenly
            colors=(
                "255 0 0"       # Red
                "255 127 0"     # Orange
                "255 255 0"     # Yellow
                "0 255 0"       # Green
                "0 0 255"       # Blue
                "75 0 130"      # Indigo
                "139 0 255"     # Violet
            )
            ;;
    esac
    
    local color_count=${#colors[@]}
    
    # Handle very short text
    if [ $length -lt 2 ]; then
        # Extract first color (handle both 3 and 4 value formats)
        local first_color="${colors[0]}"
        read -r r g b pos <<< "$first_color"
        result+="\033[38;2;${r};${g};${b}m${text}\033[0m"
        echo -e "$result"
        return
    fi
    
    # Create arrays for colors and their positions
    local color_values=()
    local color_positions=()
    
    # Check if we need to distribute colors evenly (no 4th number provided)
    local needs_even_distribution=1
    for (( i=0; i<color_count; i++ )); do
        read -r r g b pos <<< "${colors[$i]}"
        if [ -n "$pos" ]; then
            needs_even_distribution=0
            break
        fi
    done
    
    # If no percentages specified, distribute colors evenly
    if [ $needs_even_distribution -eq 1 ]; then
        for (( i=0; i<color_count; i++ )); do
            read -r r g b <<< "${colors[$i]}"
            color_values[$i]="$r $g $b"
            color_positions[$i]=$(( (i * 100) / (color_count - 1) ))
        done
    else
        # Use the provided percentages
        for (( i=0; i<color_count; i++ )); do
            read -r r g b pos <<< "${colors[$i]}"
            color_values[$i]="$r $g $b"
            color_positions[$i]=$pos
        done
    fi
    
    for (( i=0; i<length; i++ )); do
        local char="${text:$i:1}"
        
        # Calculate position based on gradient style
        local pos_percent=0
        case $gradient_style in
            radial)
                # Radial: center is 0%, edges are 100%
                local distance_from_center=$(( 2 * i - length + 1 ))  # -length to +length
                local abs_distance=${distance_from_center#-}  # Absolute value
                pos_percent=$(( (abs_distance * 100) / length ))
                # Invert so center is 0% and edges are 100%
                pos_percent=$(( 100 - pos_percent ))
                ;;
            normal|linear|*)
                # Normal linear: start is 0%, end is 100%
                pos_percent=$(( (i * 100) / (length - 1) ))
                ;;
        esac
        
        # Ensure pos_percent is within bounds
        pos_percent=$(( pos_percent < 0 ? 0 : (pos_percent > 100 ? 100 : pos_percent) ))
        
        # Find which color segment we're in
        local segment_start=0
        local segment_end=0
        local start_color=""
        local end_color=""
        local start_pos=0
        local end_pos=0
        
        for (( j=0; j<color_count-1; j++ )); do
            if [ $pos_percent -ge ${color_positions[$j]} ] && [ $pos_percent -le ${color_positions[$((j+1))]} ]; then
                segment_start=$j
                segment_end=$((j+1))
                start_color="${color_values[$j]}"
                end_color="${color_values[$((j+1))]}"
                start_pos=${color_positions[$j]}
                end_pos=${color_positions[$((j+1))]}
                break
            fi
        done
        
        # If we're at or beyond the last color, use the last color
        if [ -z "$start_color" ] || [ $pos_percent -ge ${color_positions[$((color_count-1))]} ]; then
            read -r r g b <<< "${color_values[$((color_count-1))]}"
        else
            # Blend between two colors
            read -r r1 g1 b1 <<< "$start_color"
            read -r r2 g2 b2 <<< "$end_color"
            
            # Calculate blend factor (0-256 for better precision)
            local segment_range=$((end_pos - start_pos))
            if [ $segment_range -eq 0 ]; then
                local factor=0
            else
                local factor=$(( ((pos_percent - start_pos) * 256) / segment_range ))
            fi
            local inv_factor=$(( 256 - factor ))
            
            # Blend colors using integer math
            local r=$(( (r1 * inv_factor + r2 * factor) / 256 ))
            local g=$(( (g1 * inv_factor + g2 * factor) / 256 ))
            local b=$(( (b1 * inv_factor + b2 * factor) / 256 ))
        fi
        
        # Ensure values are within bounds
        r=$(( r < 0 ? 0 : (r > 255 ? 255 : r) ))
        g=$(( g < 0 ? 0 : (g > 255 ? 255 : g) ))
        b=$(( b < 0 ? 0 : (b > 255 ? 255 : b) ))
        
        result+="\033[38;2;${r};${g};${b}m${char}"
    done
    
    result+="\033[0m"
    echo -e "$result"
}

case $1 in
  header) 
      line=$(jq -r --arg n "$n" 'to_entries | .[$n|tonumber-1].key' "$file")
      colorize_gradient "$line" "random" "radial"
      ;;
  footer) 
      line=$(jq -r --arg n "$n" 'to_entries | .[$n|tonumber-1] | if .value != "" then .value else .key end' "$file")
      colorize_gradient "$line" "random" "radial"
      ;;
esac
