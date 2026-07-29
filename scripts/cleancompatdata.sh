#!/usr/bin/env bash

set -euo pipefail

# Clean up unused Steam Proton prefixes (compatdata).
#
# A compatdata entry is considered "in use" and kept if its appid is any of:
#   - found in an appmanifest_*.acf across every discovered steamapps library
#   - listed in libraryfolders.vdf with a non-zero install size
#   - a non-Steam shortcut appid parsed from userdata/*/config/shortcuts.vdf
#   - the special shared/system prefix "0"
# Everything else (numeric appid with no install record) is an orphan and a
# deletion candidate. Non-numeric named dirs (e.g. NonSteamLaunchers) are
# reported but preserved unless --purge-named is given.
#
# Default mode is a dry run: it only lists what would be removed. Pass
# --apply to actually delete.

readonly SCRIPT_NAME="${0##*/}"

APPLY=false
PURGE_NAMED=false
VERBOSE=false

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Remove orphaned Steam Proton prefixes (compatdata) for games that are no
longer installed. Scans the main Steam library and every Steam library found
under /mnt.

Options:
  -a, --apply          Actually delete orphaned prefixes (default: dry run)
  -n, --purge-named    Also delete non-numeric named compatdata dirs
                       (e.g. NonSteamLaunchers). Risky: only use if you know
                       what these are.
  -v, --verbose        Show every kept entry and why, not just orphans
  -h, --help           Show this help message and exit

A prefix is kept when its appid is recognized as installed/in-use:
  - present as an appmanifest_*.acf in any steamapps library
  - listed in libraryfolders.vdf with a non-zero size
  - a non-Steam shortcut appid from userdata/*/config/shortcuts.vdf
  - the shared system prefix "0"

By default nothing is deleted; orphaned entries are only listed with their
on-disk size. Review the list, then re-run with --apply.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--apply)        APPLY=true; shift ;;
            -n|--purge-named)  PURGE_NAMED=true; shift ;;
            -v|--verbose)      VERBOSE=true; shift ;;
            -h|--help)         usage; exit 0 ;;
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

# Parse libraryfolders.vdf and emit "appid|size" for every listed app.
# Mirrors the path extraction in opensaysmegame.sh, then walks each library's
# "apps" block to collect appid -> install size.
get_vdf_app_sizes() {
    local steam_dir="$1"
    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    [[ -f "$vdf" ]] || return

    # Walk the apps blocks: appid lines look like  "12345"   "6789"
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

# Collect installed-app appids from every appmanifest_*.acf across all
# steamapps libraries declared in libraryfolders.vdf. Emits one appid per
# line. Mirrors opensaysmegame.sh: the VDF is the source of truth for which
# libraries Steam knows about, so we do not blindly walk /mnt game trees
# (which is slow on drives with many installed games).
get_installed_appids() {
    local steam_dir="$1"
    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    local dirs=()

    # Main library always counts.
    dirs+=("$steam_dir/steamapps")

    # Extra libraries declared in libraryfolders.vdf.
    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}"
                lib_path="${lib_path//\\//}"
                dirs+=("$lib_path/steamapps")
            fi
        done < "$vdf"
    fi

    # De-dup, then scan manifests. (Same VDF-driven discovery as
    # opensaysmegame.sh; no /mnt walk, which would be slow here.)
    printf '%s\n' "${dirs[@]}" | sort -u | while IFS= read -r sa; do
        [[ -d "$sa" ]] || continue
        for acf in "$sa"/appmanifest_*.acf; do
            [[ -f "$acf" ]] || continue
            local appid
            appid=$(basename "$acf" | sed -n 's/appmanifest_\([0-9]*\)\.acf/\1/p')
            [[ -n "$appid" ]] && printf '%s\n' "$appid"
        done
    done
}

# Parse a binary shortcuts.vdf and emit "appid|AppName" for every non-Steam
# shortcut. Steam stores the appid as a little-endian int32 right after the
# \x02appid\x00 marker, and the name as a null-terminated string after the
# next \x01AppName\x00 marker.
#
# We get every marker offset in one grep pass (fast), then index into a single
# hex dump of the file to read the appid bytes and the name. One od + one grep
# per file, no per-entry dd.
get_shortcut_appids() {
    local shortcuts_file="$1"
    [[ -f "$shortcuts_file" ]] || return

    # Byte offsets of every \x02appid\x00 marker.
    local offsets
    offsets=$(grep -aboP '\x02appid\x00' "$shortcuts_file" 2>/dev/null | cut -d: -f1)
    [[ -n "$offsets" ]] || return

    # One hex dump of the whole file; index into it for appid + name bytes.
    local hex
    hex=$(od -An -v -tx1 "$shortcuts_file" | tr -d ' \n')

    local name_marker_hex='014170704e616d6500'   # \x01AppName\x00
    local -A seen=()
    local off id_hex_off b1 b2 b3 b4 appid
    local after_name_off pre after nb name

    while IFS= read -r off; do
        [[ -z "$off" ]] && continue
        # 4 appid bytes start right after the 7-byte marker.
        id_hex_off=$(( (off + 7) * 2 ))
        b1=$(( 16#${hex:id_hex_off:2} ))
        b2=$(( 16#${hex:$((id_hex_off+2)):2} ))
        b3=$(( 16#${hex:$((id_hex_off+4)):2} ))
        b4=$(( 16#${hex:$((id_hex_off+6)):2} ))
        appid=$(( b1 + b2*256 + b3*65536 + b4*16777216 ))

        [[ -n "${seen[$appid]:-}" ]] && continue
        seen[$appid]=1

        # Find the next \x01AppName\x00 after the appid bytes; the name is the
        # null-terminated UTF-8 string right after that marker.
        name=""
        after=${hex:$((id_hex_off + 8))}
        pre=${after%%"$name_marker_hex"*}
        if [[ "$pre" != "$after" ]]; then
            after_name_off=$(( ${#pre} + ${#name_marker_hex} ))
            nb=${after:$after_name_off}
            # Name bytes = leading hex up to first "00" (null terminator).
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
# We test known paths directly instead of walking the /mnt tree with find,
# which is slow on drives holding many installed games.
get_compatdata_dirs() {
    local steam_dir="$1"
    local -n _out=$2

    local _dirs=("$steam_dir/steamapps/compatdata")

    # VDF-declared libraries.
    local vdf="$steam_dir/steamapps/libraryfolders.vdf"
    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*\"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}"
                lib_path="${lib_path//\\//}"
                _dirs+=("$lib_path/steamapps/compatdata")
            fi
        done < "$vdf"
    fi

    # Top-level drives under /mnt: probe the two common Steam layouts directly.
    # drive ends with '/', so concatenate without an extra slash.
    local drive dir
    for drive in /mnt/*/; do
        [[ -d "$drive" ]] || continue
        for dir in "${drive}steamapps/compatdata" "${drive}SteamLibrary/steamapps/compatdata"; do
            _dirs+=("$dir")
        done
    done

    # De-dup by canonical path (symlinks like ~/.steam/steam point at
    # ~/.local/share/Steam, so literal dedup would process the same dir twice).
    # mapfile keeps us in the current shell so the nameref writes survive.
    local _uniq=()
    mapfile -t _uniq < <(
        for d in "${_dirs[@]}"; do
            [[ -d "$d" ]] && readlink -f "$d"
        done | sort -u
    )
    for d in "${_uniq[@]}"; do
        _out+=("$d")
    done
    return 0
}

# Human-readable byte size for a path, falling back gracefully on errors.
human_size() {
    local path="$1"
    du -sh "$path" 2>/dev/null | cut -f1 || echo "?"
}

# Exact byte count for totals (best-effort; bad perms yield 0).
byte_size() {
    local path="$1"
    du -sb "$path" 2>/dev/null | cut -f1 || echo 0
}

main() {
    parse_args "$@"

    local steam_dir
    steam_dir=$(get_steam_install_dir)

    declare -A KEEP_REASON=()
    local keep_appid

    # 1. App manifests = on-disk ground truth for installed games.
    while IFS= read -r keep_appid; do
        [[ -n "$keep_appid" ]] || continue
        KEEP_REASON["$keep_appid"]="manifest"
    done < <(get_installed_appids "$steam_dir")

    # 2. libraryfolders.vdf entries with non-zero size (Steam's own index).
    local appid size
    while IFS='|' read -r appid size; do
        [[ -z "$appid" ]] && continue
        if [[ "$size" != "0" ]]; then
            KEEP_REASON["$appid"]="vdf:$size"
        fi
    done < <(get_vdf_app_sizes "$steam_dir")

    # 3. Non-Steam shortcuts.
    local name
    while IFS='|' read -r appid name; do
        [[ -z "$appid" ]] && continue
        KEEP_REASON["$appid"]="shortcut:${name:-?}"
    done < <(get_all_shortcut_appids "$steam_dir")

    # 4. Shared system prefix.
    KEEP_REASON["0"]="system"

    if $VERBOSE; then
        echo "Keeping ${#KEEP_REASON[@]} recognized appid(s):" >&2
        for k in "${!KEEP_REASON[@]}"; do
            printf '  %s  (%s)\n' "$k" "${KEEP_REASON[$k]}" >&2
        done
        echo >&2
    fi

    # Discover compatdata directories.
    local compat_dirs=()
    get_compatdata_dirs "$steam_dir" compat_dirs

    if [[ ${#compat_dirs[@]} -eq 0 ]]; then
        echo "No compatdata directories found." >&2
        exit 0
    fi

    local total_bytes=0
    local orphan_count=0

    for cdir in "${compat_dirs[@]}"; do
        [[ -d "$cdir" ]] || continue
        echo "## $cdir" >&2

        local entry
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            local reason="${KEEP_REASON[$entry]:-}"

            if [[ -n "$reason" ]]; then
                if $VERBOSE; then
                    printf '  [keep ] %s  (%s)\n' "$entry" "$reason" >&2
                fi
                continue
            fi

            # Non-numeric named dirs (e.g. NonSteamLaunchers) are left alone
            # unless explicitly purged.
            if [[ ! "$entry" =~ ^[0-9]+$ ]]; then
                if $PURGE_NAMED; then
                    :
                else
                    if $VERBOSE; then
                        printf '  [keep ] %s  (named, use --purge-named to remove)\n' "$entry" >&2
                    fi
                    continue
                fi
            fi

            local full="$cdir/$entry"
            if [[ ! -e "$full" ]]; then
                continue
            fi

            local hsize bsize
            hsize=$(human_size "$full")
            bsize=$(byte_size "$full")
            total_bytes=$(( total_bytes + bsize ))
            orphan_count=$(( orphan_count + 1 ))

            if $APPLY; then
                printf '  [del  ] %s  (%s)\n' "$entry" "$hsize" >&2
                rm -rf -- "$full"
            else
                printf '  [WOULD] %s  (%s)\n' "$entry" "$hsize" >&2
            fi
        done < <(find "$cdir" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
        echo >&2
    done

    # Print a readable total.
    local total_h
    total_h=$(awk -v b="$total_bytes" 'BEGIN {
        if (b < 1024)        { printf "%d B", b; exit }
        u = "KMGTPE"; split("", x); n = 0
        while (b >= 1024 && n < length(u)) { b/=1024; n++ }
        printf "%.1f %siB", b, substr(u, n, 1)
    }')

    if $APPLY; then
        echo "Deleted $orphan_count orphaned prefix(es), freeing ~$total_h." >&2
    else
        echo "Dry run: $orphan_count orphaned prefix(es), ~$total_h reclaimable." >&2
        echo "Re-run with --apply to delete them." >&2
    fi
}

main "$@"