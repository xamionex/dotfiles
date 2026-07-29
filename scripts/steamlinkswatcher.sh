#!/usr/bin/env bash

set -euo pipefail

# Keep steamlinks.sh running as saves change. Two modes, pick whichever you
# prefer (you can run both: watcher for reactivity, interval as a safety net):
#
#   --watch             inotify on every compatdata dir; re-run steamlinks.sh
#                       whenever a prefix changes (created/modified). Also
#                       runs a safety sweep every 30 min to catch in-place
#                       prefix rebuilds that parent-level watches would miss.
#                       Requires inotifywait (inotify-tools).
#
#   --interval N        poll: run steamlinks.sh every N minutes.
#
#   --provision         pass --provision through to steamlinks.sh so newly
#                       installed games get a pre-made skeleton too.
#
# Both modes run steamlinks.sh once at startup before waiting.

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STEAMLINKS="$SCRIPT_DIR/steamlinks.sh"

MODE=""
INTERVAL_MIN=""
PROVISION=false
SAFETY_SWEEP_MIN=30

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <MODE> [OPTIONS]

Re-run steamlinks.sh reactively or on a schedule so Proton save symlinks stay
present even when Steam creates/rebuilds a prefix (version switch, verify, etc).

Modes (pick one):
  --watch            Watch compatdata dirs with inotify and re-run on change.
                     Includes a 30-min safety sweep. Requires inotifywait.
  --interval N       Run every N minutes (poll).

Options:
  -p, --provision    Pass --provision to steamlinks.sh (pre-make skeletons for
                     installed games that have no prefix yet)
  -v, --verbose      Verbose logging
  -h, --help         Show this help message and exit

Examples:
  ${SCRIPT_NAME} --watch
  ${SCRIPT_NAME} --interval 15
  ${SCRIPT_NAME} --watch --provision
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --watch)
                [[ -n "$MODE" && "$MODE" != "watch" ]] && { echo "Error: --watch and --interval are mutually exclusive" >&2; exit 1; }
                MODE="watch"; shift ;;
            --interval)
                [[ -n "$MODE" && "$MODE" != "interval" ]] && { echo "Error: --watch and --interval are mutually exclusive" >&2; exit 1; }
                MODE="interval"
                shift
                [[ $# -eq 0 || ! "$1" =~ ^[0-9]+$ ]] && { echo "Error: --interval requires a numeric argument" >&2; exit 1; }
                INTERVAL_MIN="$1"; shift ;;
            -p|--provision) PROVISION=true; shift ;;
            -v|--verbose)   VERBOSE=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    VERBOSE=${VERBOSE:-false}

    if [[ -z "$MODE" ]]; then
        echo "Error: a mode is required (--watch or --interval N)" >&2
        echo >&2
        usage
        exit 1
    fi
}

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

# Build the steamlinks.sh invocation array with optional flags.
run_steamlinks() {
    log "running steamlinks"
    local cmd=("$STEAMLINKS")
    if $PROVISION; then cmd+=("--provision"); fi
    if $VERBOSE;  then cmd+=("--verbose"); fi

    if ! "${cmd[@]}" >/tmp/steamlinkswatcher.log 2>&1; then
        log "steamlinks failed (see /tmp/steamlinkswatcher.log)"
        cat /tmp/steamlinkswatcher.log >&2
    else
        if $VERBOSE; then tail -n +1 /tmp/steamlinkswatcher.log >&2; fi
    fi
}

check_watch_deps() {
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "Error: inotifywait is required for --watch (install inotify-tools)" >&2
        exit 1
    fi
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Error: rsync is required (steamlinks needs it for migration)" >&2
        exit 1
    fi
}

# Discover compatdata dirs the same way steamlinks does (reuse its logic).
get_compatdata_dirs() {
    local -n _out=$1
    _out=()
    local steam_dir
    if [[ -d "$HOME/.steam/steam" ]]; then
        steam_dir="$HOME/.steam/steam"
    elif [[ -d "$HOME/.local/share/Steam" ]]; then
        steam_dir="$HOME/.local/share/Steam"
    else
        return 0
    fi

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

    local drive dir
    for drive in /mnt/*/; do
        [[ -d "$drive" ]] || continue
        for dir in "${drive}steamapps/compatdata" "${drive}SteamLibrary/steamapps/compatdata"; do
            _cand+=("$dir")
        done
    done

    local _uniq=()
    mapfile -t _uniq < <(
        for d in "${_cand[@]}"; do
            [[ -d "$d" ]] && readlink -f "$d"
        done | sort -u
    )
    for d in "${_uniq[@]}"; do
        _out+=("$d")
    done
    return 0
}

watch_loop() {
    check_watch_deps

    local compat_dirs=()
    get_compatdata_dirs compat_dirs
    if [[ ${#compat_dirs[@]} -eq 0 ]]; then
        log "no compatdata dirs found; nothing to watch"
        exit 0
    fi

    log "watching ${#compat_dirs[@]} compatdata dir(s):"
    for d in "${compat_dirs[@]}"; do log "  $d"; done

    # Marker file touched whenever inotify sees activity. The coordinator runs
    # steamlinks after a short debounce once activity stops, and also on the
    # fixed safety-sweep cadence. Both feed into the same marker so the run is
    # coalesced and we never run twice for the same burst.
    local marker
    marker=$(mktemp -t slwatch.XXXXXX)
    rm -f "$marker"

    local inotify_pid sweep_pid
    cleanup() {
        # Kill the producer subshells first. The inotify one is a pipeline
        # (inotifywait | while); killing the subshell orphans inotifywait, so
        # also pkill any inotifywait watching our compatdata dirs.
        for pid in "$inotify_pid" "$sweep_pid"; do
            kill "$pid" 2>/dev/null || true
        done
        pkill -f 'inotifywait.*compatdata' 2>/dev/null || true
        rm -f "$marker"
    }
    trap 'cleanup; exit 0' INT TERM
    trap 'cleanup' EXIT

    # 1. inotify producer: touch the marker on any compatdata change.
    (
        inotifywait -m -q -r \
            -e create -e modify -e move \
            --format '%e' \
            "${compat_dirs[@]}" 2>/dev/null \
            | while IFS= read -r _; do touch "$marker"; done
    ) &
    inotify_pid=$!

    # 2. safety-sweep producer: touch the marker on a fixed cadence so a run
    #    happens even if inotify misses an in-place prefix rebuild.
    (
        while true; do
            sleep $(( SAFETY_SWEEP_MIN * 60 ))
            touch "$marker"
        done
    ) &
    sweep_pid=$!

    # 3. coordinator: debounce. Wait for a quiet window, then run once.
    local last_run=0
    while true; do
        if [[ -f "$marker" ]]; then
            # Activity happened. Debounce: wait until 5s of quiet, then run.
            while [[ -f "$marker" ]]; do
                rm -f "$marker"
                sleep 5
            done
            if (( last_run == 0 )) || (( $(date +%s) - last_run >= 5 )); then
                run_steamlinks
                last_run=$(date +%s)
            fi
        fi
        sleep 1
    done
}

interval_loop() {
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Error: rsync is required (steamlinks needs it for migration)" >&2
        exit 1
    fi
    local secs=$(( INTERVAL_MIN * 60 ))
    log "running every ${INTERVAL_MIN} min"
    while true; do
        run_steamlinks
        sleep "$secs"
    done
}

main() {
    parse_args "$@"
    case "$MODE" in
        watch)    watch_loop ;;
        interval) interval_loop ;;
        *) echo "Error: unknown mode '$MODE'" >&2; exit 1 ;;
    esac
}

main "$@"