#!/usr/bin/env bash

set -euo pipefail

CACHE_FILE="$HOME/.cache/steam_game_map.txt"
CACHE_MAX_AGE_SECONDS=$((6 * 3600))   # 6 hours

# Find the main Steam installation directory
get_steam_install_dir() {
    local steam_dir
    if [[ -d "$HOME/.steam/steam" ]]; then
        steam_dir="$HOME/.steam/steam"
    elif [[ -d "$HOME/.local/share/Steam" ]]; then
        steam_dir="$HOME/.local/share/Steam"
    else
        echo "Error: Steam installation not found." >&2
        exit 1
    fi
    echo "$steam_dir"
}

# Parse libraryfolders.vdf to get all steamapps paths
get_all_steamapps_dirs() {
    local steam_dir="$1"
    local steamapps_dirs=()

    # Default steamapps
    steamapps_dirs+=("$steam_dir/steamapps")

    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    [[ -f "$vdf" ]] || {
        printf "%s\n" "${steamapps_dirs[@]}"
        return
    }

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]*\"([^\"]+)\" ]]; then
            lib_path="${BASH_REMATCH[1]}"
            lib_path="${lib_path//\\//}"
            steamapps_dirs+=("$lib_path/steamapps")
        fi
    done < "$vdf"

    printf "%s\n" "${steamapps_dirs[@]}" | sort -u
}

# Rebuild cache by scanning all appmanifest_*.acf files
rebuild_cache() {
    local steam_dir
    steam_dir=$(get_steam_install_dir)

    local steamapps_dirs
    mapfile -t steamapps_dirs < <(get_all_steamapps_dirs "$steam_dir")

    local tmp_cache
    tmp_cache=$(mktemp)

    for steamapps_dir in "${steamapps_dirs[@]}"; do
        [[ -d "$steamapps_dir" ]] || continue

        for acf in "$steamapps_dir"/appmanifest_*.acf; do
            [[ -f "$acf" ]] || continue

            local appid
            appid=$(basename "$acf" | sed -n 's/appmanifest_\([0-9]*\)\.acf/\1/p')
            [[ -z "$appid" ]] && continue

            local name
            name=$(grep -Po '"name"\s*"\K[^"]+' "$acf" | head -1)
            [[ -z "$name" ]] && continue

            local installdir
            installdir=$(grep -Po '"installdir"\s*"\K[^"]+' "$acf" | head -1)
            [[ -z "$installdir" ]] && continue

            local game_path="$steamapps_dir/common/$installdir"

            if [[ -d "$game_path" ]]; then
                echo "$appid|$name|$game_path" >> "$tmp_cache"
            fi
        done
    done

    mv "$tmp_cache" "$CACHE_FILE"
    echo "Cache rebuilt." >&2
}

# Load cache into associative arrays
load_cache() {
    declare -gA APPID_TO_NAME
    declare -gA APPID_TO_GAMEPATH
    declare -gA NAME_TO_APPIDS

    if [[ -f "$CACHE_FILE" ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
        if [[ $age -gt $CACHE_MAX_AGE_SECONDS ]]; then
            rebuild_cache >&2
        fi
    else
        rebuild_cache >&2
    fi

    while IFS='|' read -r appid name gamepath; do
        APPID_TO_NAME["$appid"]="$name"
        APPID_TO_GAMEPATH["$appid"]="$gamepath"

        local key="${name,,}"
        if [[ -n "${NAME_TO_APPIDS[$key]:-}" ]]; then
            NAME_TO_APPIDS[$key]="${NAME_TO_APPIDS[$key]}|$appid"
        else
            NAME_TO_APPIDS[$key]="$appid"
        fi
    done < "$CACHE_FILE"
}

# Interactive selection when multiple games match
select_game() {
    local -n matches_ref=$1
    local -n names_ref=$2

    echo "Multiple games match. Please select one:" >&2

    local i=1
    for appid in "${matches_ref[@]}"; do
        printf "  %d) %s (%s)\n" "$i" "${names_ref[$appid]}" "$appid" >&2
        ((i++))
    done

    local choice
    while true; do
        read -p "Enter number (1-${#matches_ref[@]}): " choice >&2

        if [[ "$choice" =~ ^[0-9]+$ ]] &&
           (( choice >= 1 && choice <= ${#matches_ref[@]} )); then
            echo "${matches_ref[$((choice - 1))]}"
            return 0
        fi

        echo "Invalid selection. Please try again." >&2
    done
}

usage() {
    cat <<EOF
Usage: $0 <game-name-or-appid>

Locates the installation directory for a Steam game.
Argument can be numeric appid or partial game name (case-insensitive substring).

If multiple games match, you will be prompted to choose one.

On success, the game's installation folder is opened in Dolphin (detached).
EOF
    exit 1
}

main() {
    if [[ $# -ne 1 ]]; then
        usage
    fi

    local query="$1"

    load_cache

    if [[ ${#APPID_TO_NAME[@]} -eq 0 ]]; then
        echo "Error: No Steam games found." >&2
        exit 1
    fi

    local matches=()

    if [[ "$query" =~ ^[0-9]+$ ]]; then
        if [[ -n "${APPID_TO_NAME[$query]:-}" ]]; then
            matches=("$query")
        fi
    else
        local query_lower="${query,,}"

        for appid in "${!APPID_TO_NAME[@]}"; do
            local name="${APPID_TO_NAME[$appid]}"

            if [[ "${name,,}" == *"$query_lower"* ]]; then
                matches+=("$appid")
            fi
        done
    fi

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "Error: No game found matching '$query'." >&2
        exit 1
    elif [[ ${#matches[@]} -gt 1 ]]; then
        appid=$(select_game matches APPID_TO_NAME)
    else
        appid="${matches[0]}"
    fi

    local game_path="${APPID_TO_GAMEPATH[$appid]}"

    if [[ ! -d "$game_path" ]]; then
        echo "Error: Game directory not found: $game_path" >&2
        exit 1
    fi

	echo "$game_path"
	exit 0
    if command -v dolphin &>/dev/null; then
        nohup dolphin "$game_path" >/dev/null 2>&1 &
        disown
        echo "Opened game folder of ${APPID_TO_NAME[$appid]} ($appid) in Dolphin."
    else
        echo "Error: 'dolphin' not found. Path would be: $game_path" >&2
        exit 1
    fi
}

main "$@"
