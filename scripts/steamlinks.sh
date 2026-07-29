#!/usr/bin/env bash

set -euo pipefail

# Unify Windows special folders (Documents / AppData / Saved Games) for Steam
# Proton prefixes so saves live in one place instead of per-prefix.
#
# Two modes:
#   default       iterate every existing compatdata dir and link its folders
#   --provision    iterate every INSTALLED game (manifests + non-zero VDF sizes
#                  + non-Steam shortcuts) and pre-create the pfx skeleton with
#                  symlinks for any that have no compatdata yet, so the first
#                  launch writes saves straight into the unified targets.
#
# The migrate path (when a real dir already holds saves) rsyncs its contents
# into the unified target before replacing it with a symlink, so existing
# saves are never lost.

readonly SCRIPT_NAME="${0##*/}"

# Main configuration (could be moved to config file)
readonly SEARCH_OTHER_DRIVES=true
readonly TARGET_DOCS="$HOME/Documents"
readonly TARGET_APPDATA="$HOME/AppData"
readonly TARGET_SAVES="$HOME/Saved Games"
readonly FOLDERS=("Documents" "AppData" "Saved Games")

PROVISION=false
VERBOSE=false

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Unify Steam Proton save folders (Documents / AppData / Saved Games) into
~/{Documents,AppData,Saved Games} via symlinks, across the main Steam library
and every Steam library found under /mnt.

Options:
  -p, --provision  Also pre-create the pfx skeleton + symlinks for installed
                   games that have no compatdata yet (first launch writes saves
                   straight into the unified targets)
  -v, --verbose    Log every folder, including already-valid ones
  -h, --help       Show this help message and exit
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--provision) PROVISION=true; shift ;;
            -v|--verbose)   VERBOSE=true; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done
}

# Find the main Steam installation directory (mirrors opensaysmegame.sh).
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

# Collect installed-app appids from every appmanifest_*.acf across all
# steamapps libraries declared in libraryfolders.vdf. Emits "appid|steamapps".
get_installed_games() {
    local steam_dir="$1"
    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    local dirs=()

    dirs+=("$steam_dir/steamapps")

    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}"
                lib_path="${lib_path//\\//}"
                dirs+=("$lib_path/steamapps")
            fi
        done < "$vdf"
    fi

    printf '%s\n' "${dirs[@]}" | sort -u | while IFS= read -r sa; do
        [[ -d "$sa" ]] || continue
        for acf in "$sa"/appmanifest_*.acf; do
            [[ -f "$acf" ]] || continue
            local appid
            appid=$(basename "$acf" | sed -n 's/appmanifest_\([0-9]*\)\.acf/\1/p')
            [[ -n "$appid" ]] && printf '%s|%s\n' "$appid" "$sa"
        done
    done
}

# Parse libraryfolders.vdf and emit "appid|size" for every listed app.
get_vdf_app_sizes() {
    local steam_dir="$1"
    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    [[ -f "$vdf" ]] || return

    awk '
        /^[[:space:]]*"apps"[[:space:]]*$/ { in_apps=1; next }
        in_apps && /^[[:space:]]*}[[:space:]]*$/ { in_apps=0; next }
        in_apps {
            if (match($0, /^[[:space:]]*"([0-9]+)"[[:space:]]+"([0-9]+)"[[:space:]]*$/, m)) {
                print m[1] "|" m[2]
            }
        }
    ' "$vdf"
}

# Parse a binary shortcuts.vdf and emit "appid|AppName" for every non-Steam
# shortcut. Mirrors cleancompatdata.sh: one grep pass for marker offsets, then
# index into a single hex dump for appid + name bytes.
get_shortcut_appids() {
    local shortcuts_file="$1"
    [[ -f "$shortcuts_file" ]] || return

    local offsets
    offsets=$(grep -aboP '\x02appid\x00' "$shortcuts_file" 2>/dev/null | cut -d: -f1)
    [[ -n "$offsets" ]] || return

    local hex
    hex=$(od -An -v -tx1 "$shortcuts_file" | tr -d ' \n')

    local name_marker_hex='014170704e616d6500'   # \x01AppName\x00
    local -A seen=()
    local off id_hex_off b1 b2 b3 b4 appid
    local after_name_off pre after nb name

    while IFS= read -r off; do
        [[ -z "$off" ]] && continue
        id_hex_off=$(( (off + 7) * 2 ))
        b1=$(( 16#${hex:id_hex_off:2} ))
        b2=$(( 16#${hex:$((id_hex_off+2)):2} ))
        b3=$(( 16#${hex:$((id_hex_off+4)):2} ))
        b4=$(( 16#${hex:$((id_hex_off+6)):2} ))
        appid=$(( b1 + b2*256 + b3*65536 + b4*16777216 ))

        [[ -n "${seen[$appid]:-}" ]] && continue
        seen[$appid]=1

        name=""
        after=${hex:$((id_hex_off + 8))}
        pre=${after%%"$name_marker_hex"*}
        if [[ "$pre" != "$after" ]]; then
            after_name_off=$(( ${#pre} + ${#name_marker_hex} ))
            nb=${after:$after_name_off}
            nb=${nb%%00*}
            if [[ -n "$nb" && $(( ${#nb} % 2 )) -eq 0 ]]; then
                name=$(printf '%b' "$(printf '\\x%s' $(grep -oP '..' <<<"$nb" 2>/dev/null))" 2>/dev/null)
            fi
        fi

        printf '%s|%s\n' "$appid" "${name:-}"
    done <<< "$offsets"
}

# Collect shortcut appids from every Steam account's shortcuts.vdf.
get_all_shortcut_appids() {
    local steam_dir="$1"
    local userdata="$steam_dir/userdata"
    [[ -d "$userdata" ]] || return

    local f
    while IFS= read -r f; do
        get_shortcut_appids "$f"
    done < <(find "$userdata" -mindepth 3 -maxdepth 3 -name shortcuts.vdf -print 2>/dev/null)
}

# Discover every compatdata directory: the main library, the VDF-declared
# libraries, and any Steam library mounted under a top-level /mnt drive.
# Tests known paths directly (no /mnt tree walk) for speed on big libraries.
get_steam_compatdata_dirs() {
    local -n _dirs=$1
    local steam_dir
    steam_dir=$(get_steam_install_dir)

    local _cand=("$steam_dir/steamapps/compatdata")

    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}"
                lib_path="${lib_path//\\//}"
                _cand+=("$lib_path/steamapps/compatdata")
            fi
        done < "$vdf"
    fi

    if [ "$SEARCH_OTHER_DRIVES" = true ]; then
        local drive dir
        for drive in /mnt/*/; do
            [[ -d "$drive" ]] || continue
            for dir in "${drive}steamapps/compatdata" "${drive}SteamLibrary/steamapps/compatdata"; do
                _cand+=("$dir")
            done
        done
    fi

    # De-dup by canonical path (symlinks like ~/.steam/steam -> ~/.local/share/Steam).
    local _uniq=()
    mapfile -t _uniq < <(
        for d in "${_cand[@]}"; do
            [[ -d "$d" ]] && readlink -f "$d"
        done | sort -u
    )
    for d in "${_uniq[@]}"; do
        _dirs+=("$d")
    done
    return 0
}

# Map a steamapps dir to its compatdata dir (same library root).
compatdata_for_steamapps() {
    local sa="$1"
    local root="${sa%/steamapps}"
    echo "$root/steamapps/compatdata"
}

# Create target directories
create_target_directories() {
    mkdir -p "$TARGET_DOCS" "$TARGET_APPDATA" "$TARGET_SAVES"
}

# Process all compatdata directories
process_all_compat_dirs() {
    local dir
    for dir in "$@"; do
        [[ -d "$dir" ]] || continue
        process_single_compat_dir "$dir"
    done
    return 0
}

# Process single compatdata directory
process_single_compat_dir() {
    local dir="$1"
    while IFS= read -r -d $'\0' appid_dir; do
        process_appid_directory "$appid_dir"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0)
    return 0
}

# Process single AppID directory
process_appid_directory() {
    local appid_dir="$1"
    local appid=$(basename "$appid_dir")

    local folder
    for folder in "${FOLDERS[@]}"; do
        process_special_folder "$appid_dir" "$appid" "$folder"
    done
}

# Process individual special folder
process_special_folder() {
    local appid_dir="$1"
    local appid="$2"
    local folder="$3"

    local target
    case "$folder" in
        Documents) target="$TARGET_DOCS" ;;
        AppData) target="$TARGET_APPDATA" ;;
        "Saved Games") target="$TARGET_SAVES" ;;
        *) return 1 ;;
    esac

    local sourcedir="$appid_dir/pfx/drive_c/users/steamuser/$folder"
    local parent_dir=$(dirname "$sourcedir")

    mkdir -p "$parent_dir"
    manage_symlink "$sourcedir" "$target" "$folder" "$appid"
}

# Manage symlink creation/validation
manage_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    if [ -L "$sourcedir" ]; then
        validate_existing_symlink "$sourcedir" "$target" "$folder" "$appid"
    elif [ -d "$sourcedir" ]; then
        migrate_and_link "$sourcedir" "$target" "$folder" "$appid"
    else
        create_symlink "$sourcedir" "$target" "$folder" "$appid"
    fi
}

# Validate existing symlink
validate_existing_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"
    local current_target=$(readlink -f "$sourcedir")

    if [ "$current_target" != "$target" ]; then
        echo "Updating $folder symlink for $appid (was: $current_target)"
        recreate_symlink "$sourcedir" "$target"
    else
        if $VERBOSE; then echo "Valid $folder symlink exists for $appid"; fi
    fi
}

# Migrate directory and create symlink
migrate_and_link() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    echo "Migrating $folder for $appid"
    rsync -a -l --ignore-existing "$sourcedir/" "$target/"
    rm -rf "$sourcedir"
    create_symlink "$sourcedir" "$target" "$folder" "$appid"
}

# Create new symlink
create_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    echo "Creating $folder symlink for $appid"
    ln -svf "$target" "$sourcedir"
}

# Helper to recreate symlink
recreate_symlink() {
    rm -f "$1"
    ln -svf "$2" "$1"
}

# Pre-create the pfx skeleton + symlinks for installed games that have no
# compatdata yet. Tested against Shift At Midnight (appid 3722330): Proton
# completes the skeleton on first launch and leaves the pre-made symlinks
# untouched, so saves land in the unified targets immediately.
provision_missing_prefixes() {
    local steam_dir="$1"

    # Build the keep-set of installed appids and where each one's compatdata
    # should live (so we create the skeleton in the right library).
    declare -A SHOULD_EXIST=()   # appid -> compatdata dir
    local appid sa cdir

    while IFS='|' read -r appid sa; do
        [[ -z "$appid" ]] && continue
        cdir=$(compatdata_for_steamapps "$sa")
        SHOULD_EXIST["$appid"]="$cdir"
    done < <(get_installed_games "$steam_dir")

    local size
    while IFS='|' read -r appid size; do
        [[ -z "$appid" ]] && continue
        if [[ "$size" != "0" ]] && [[ -z "${SHOULD_EXIST[$appid]:-}" ]]; then
            # No manifest, but Steam reports a real install size: put it in the
            # main library compatdata as a safe default.
            SHOULD_EXIST["$appid"]="$steam_dir/steamapps/compatdata"
        fi
    done < <(get_vdf_app_sizes "$steam_dir")

    local name
    while IFS='|' read -r appid name; do
        [[ -z "$appid" ]] && continue
        [[ -n "${SHOULD_EXIST[$appid]:-}" ]] && continue
        SHOULD_EXIST["$appid"]="$steam_dir/steamapps/compatdata"
    done < <(get_all_shortcut_appids "$steam_dir")

    local provisioned=0
    for appid in "${!SHOULD_EXIST[@]}"; do
        cdir="${SHOULD_EXIST[$appid]}"
        local appid_dir="$cdir/$appid"
        if [[ -d "$appid_dir/pfx/drive_c/users/steamuser" ]]; then
            # Already provisioned or already launched: normal linking pass
            # will handle it. Skip here.
            continue
        fi
        echo "Provisioning skeleton for $appid in $cdir"
        local folder
        for folder in "${FOLDERS[@]}"; do
            process_special_folder "$appid_dir" "$appid" "$folder"
        done
        provisioned=$(( provisioned + 1 ))
    done

    if [[ $provisioned -gt 0 ]]; then
        echo "Provisioned $provisioned new prefix skeleton(s)."
    else
        if $VERBOSE; then echo "Nothing to provision; all installed games already have a prefix."; fi
    fi
    return 0
}

# Check runtime dependencies. rsync is only needed for the migrate path, but
# we fail fast if it is missing so the script never silently no-ops a migrate.
check_dependencies() {
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Error: rsync is required but not found." >&2
        exit 1
    fi
}

# Main function coordinating the process
main() {
    parse_args "$@"
    check_dependencies

    local steam_dir
    steam_dir=$(get_steam_install_dir)

    create_target_directories

    local compat_dirs=()
    get_steam_compatdata_dirs compat_dirs

    process_all_compat_dirs "${compat_dirs[@]}"

    if $PROVISION; then
        provision_missing_prefixes "$steam_dir"
    fi

    echo "All Windows special folders have been unified and validated."
}

main "$@"