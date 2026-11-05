#!/bin/bash

SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
TRAY_SCRIPT="$SCRIPT_DIR/stream-tray.py"

STREAM_KEY="${STREAM_KEY:-$(id -un 2>/dev/null)}"
TEAMSPEAK_MODE="${TEAMSPEAK_MODE:-0}"
STREAM_QUALITY="${STREAM_QUALITY:-high}"
WHIP_URL="https://broadcast.petar.cc/api/whip"
PID_FILE="/tmp/gsr-whip-stream.pid"
KEY_FILE="/tmp/gsr-whip-stream.key"
TRAY_PID_FILE="/tmp/gsr-whip-stream-tray.pid"
TS_PID_FILE="/tmp/gsr-whip-stream-ts.pid"
LOG_FILE="/tmp/gsr-whip-stream.log"
TRAY_LOG_FILE="/tmp/gsr-whip-stream-tray.log"

COMMAND="${1:-}"
for arg in "${@:2}"; do
    case "$arg" in
        --teamspeak) TEAMSPEAK_MODE=1 ;;
        *) STREAM_KEY="$arg" ;;
    esac
done

WATCH_URL="https://broadcast.petar.cc/$STREAM_KEY"

process_cmdline() {
    tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null
}

is_whip_stream() {
    local pid="$1"
    local cmd

    cmd=$(process_cmdline "$pid") || return 1
    [[ "$cmd" == *"gpu-screen-recorder"* && "$cmd" == *"-c whip"* ]]
}

is_tray_process() {
    local pid="$1"
    local cmd

    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1

    cmd=$(process_cmdline "$pid") || return 1
    [[ "$cmd" == *"stream-tray.py"* ]]
}

is_ts_watcher() {
    local pid="$1"
    local cmd

    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1

    cmd=$(process_cmdline "$pid") || return 1
    [[ "$cmd" == *"gsr-ts-watch"* ]]
}

terminate_pid() {
    local pid="$1"
    local i

    kill -TERM "$pid" 2>/dev/null || return 0

    for i in {1..20}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
    done

    kill -KILL "$pid" 2>/dev/null
}

stop_tray() {
    if [ ! -f "$TRAY_PID_FILE" ]; then
        return 0
    fi

    local tpid
    tpid=$(cat "$TRAY_PID_FILE" 2>/dev/null)

    if is_tray_process "$tpid"; then
        terminate_pid "$tpid"
    fi

    rm -f "$TRAY_PID_FILE"
}

stop_ts_watcher() {
    if [ ! -f "$TS_PID_FILE" ]; then
        return 0
    fi

    local wpid
    wpid=$(cat "$TS_PID_FILE" 2>/dev/null)

    if is_ts_watcher "$wpid"; then
        terminate_pid "$wpid"
    fi

    rm -f "$TS_PID_FILE"
}

remove_state() {
    stop_tray
    stop_ts_watcher
    rm -f "$PID_FILE" "$KEY_FILE"
}

start_tray() {
    local pid="$1"

    if [ ! -f "$TRAY_SCRIPT" ]; then
        echo "Tray helper not found: $TRAY_SCRIPT" >&2
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 not found, cannot start tray indicator" >&2
        return 1
    fi

    local args=(
        --pid "$pid"
        --key "$STREAM_KEY"
        --watch-url "$WATCH_URL"
        --script "$SELF"
        --tray-pid-file "$TRAY_PID_FILE"
    )

    if [ "$TEAMSPEAK_MODE" = "1" ]; then
        args+=(--teamspeak)
    fi

    nohup python3 "$TRAY_SCRIPT" "${args[@]}" > "$TRAY_LOG_FILE" 2>&1 &
    echo $! > "$TRAY_PID_FILE"

    sleep 0.5
    if ! is_tray_process "$(cat "$TRAY_PID_FILE" 2>/dev/null)"; then
        notify-send -u normal "Stream" "Tray indicator failed to start. See $TRAY_LOG_FILE"
        return 1
    fi
}

start_ts_watcher() {
    local stream_pid="$1"

    nohup bash -c '
watch_pid_file="$1"
self="$2"
stream_pid="$3"
while kill -0 "$stream_pid" 2>/dev/null; do
    if ! pgrep -x TeamSpeak >/dev/null 2>&1; then
        sleep 2
        if ! pgrep -x TeamSpeak >/dev/null 2>&1; then
            notify-send -u critical "Stream stopped" "TeamSpeak is not running" >/dev/null 2>&1 || true
            rm -f "$watch_pid_file"
            exec "$self" stop
        fi
    fi
    sleep 2
done
rm -f "$watch_pid_file"
' gsr-ts-watch "$TS_PID_FILE" "$SELF" "$stream_pid" >/dev/null 2>&1 &

    echo $! > "$TS_PID_FILE"
}

start() {
    #pkill -9 obs 2>/dev/null
    #obs --collection Untitled --minimize-to-tray --startstreaming &

    if [ -z "$STREAM_KEY" ]; then
        notify-send -u critical "Stream" "Could not determine a stream key"
        echo "Could not determine a stream key" >&2
        return 1
    fi

    if [ -f "$PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")

        if is_whip_stream "$old_pid"; then
            local running_key
            running_key=$(cat "$KEY_FILE" 2>/dev/null)

            echo "Stream is already running (PID: $old_pid)"
            if [ -n "$running_key" ]; then
                echo "Watch: https://broadcast.petar.cc/$running_key"
            fi
            return 0
        fi

        remove_state
    fi

    case "$STREAM_QUALITY" in
        medium|high|very_high|ultra) ;;
        *)
            notify-send -u critical "Stream not started" "Invalid STREAM_QUALITY: $STREAM_QUALITY"
            echo "Invalid STREAM_QUALITY: $STREAM_QUALITY" >&2
            echo "Use medium, high, very_high or ultra." >&2
            return 1
            ;;
    esac

    if [ "$TEAMSPEAK_MODE" = "1" ] && ! pgrep -x TeamSpeak >/dev/null 2>&1; then
        notify-send -u critical "Stream not started" "TeamSpeak is not running"
        echo "TeamSpeak is not running" >&2
        return 1
    fi

    # Keep the stream key out of the process list.
    export GSR_AUTH="$STREAM_KEY"

    nohup gpu-screen-recorder \
        -w DP-1 \
        -c whip \
        -k h264 \
        -ac opus \
        -ab 128 \
        -f 60 \
        -s 1920x1080 \
        -bm qp \
        -q "$STREAM_QUALITY" \
        -cr limited \
        -a "app-inverse:TeamSpeak|app-inverse:discord|app-inverse:Zen|app-inverse:chromium|app-inverse:firefox|app-inverse:plasmashell|app-inverse:pipewire|app-inverse:linuxsoundboard.local_playback|app-inverse:linuxsoundboard.virtual_mic_feeder" \
        -o "$WHIP_URL" \
        -v no > "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1
    if ! is_whip_stream "$pid"; then
        notify-send -u critical "Stream failed" "See $LOG_FILE"
        echo "Stream failed to start. Log:"
        tail -n 20 "$LOG_FILE"
        remove_state
        return 1
    fi

    echo "$STREAM_KEY" > "$KEY_FILE"

    if [ "$TEAMSPEAK_MODE" = "1" ]; then
        start_ts_watcher "$pid"
    fi

    start_tray "$pid"

    echo "Stream started (PID: $pid)"
    echo "Watch: $WATCH_URL"
    echo "Log: $LOG_FILE"
    if [ "$TEAMSPEAK_MODE" = "1" ]; then
        echo "TeamSpeak mode: on"
    fi
}

stop() {
    #pkill -9 obs 2>/dev/null

    if [ ! -f "$PID_FILE" ]; then
        remove_state
        echo "Stream is not running"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if ! is_whip_stream "$pid"; then
        remove_state
        echo "Stream is not running (stale PID file)"
        return 0
    fi

    stop_ts_watcher

    echo "Stopping stream (PID: $pid)..."
    kill -INT "$pid" 2>/dev/null

    local i
    for i in {1..50}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            remove_state
            echo "Stream stopped"
            return 0
        fi
        sleep 0.1
    done

    echo "Stream did not stop on SIGINT, sending SIGTERM"
    kill -TERM "$pid" 2>/dev/null

    for i in {1..20}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            remove_state
            echo "Stream stopped"
            return 0
        fi
        sleep 0.1
    done

    echo "Stream did not stop on SIGTERM, sending SIGKILL"
    kill -KILL "$pid" 2>/dev/null
    remove_state
    echo "Stream killed"
}

case "$COMMAND" in
    start) start ;;
    stop) stop ;;
    restart) stop && start ;;
    *)
        echo "Usage: $0 {start|stop|restart} [stream_key] [--teamspeak]"
        echo "Stream key defaults to the current username."
        echo "Quality defaults to high (QP 30). Override with STREAM_QUALITY=medium|high|very_high|ultra."
        ;;
esac
