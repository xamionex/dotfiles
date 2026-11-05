#!/bin/bash

STREAM_KEY="${2:-${STREAM_KEY:-$(id -un 2>/dev/null)}}"
WHIP_URL="https://broadcast.petar.cc/api/whip"
WATCH_URL="https://broadcast.petar.cc/$STREAM_KEY"
PID_FILE="/tmp/gsr-whip-stream.pid"
KEY_FILE="/tmp/gsr-whip-stream.key"
LOG_FILE="/tmp/gsr-whip-stream.log"

is_whip_stream() {
    local pid="$1"
    local cmd

    cmd=$(ps -p "$pid" -o args= 2>/dev/null) || return 1
    [[ "$cmd" == *"gpu-screen-recorder"* && "$cmd" == *"-c whip"* ]]
}

remove_state() {
    rm -f "$PID_FILE" "$KEY_FILE"
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
        -bm cbr \
        -q 8000 \
        -cr limited \
        -a "app-inverse:TeamSpeak|app-inverse:discord|app-inverse:plasmashell|app-inverse:pipewire|app-inverse:linuxsoundboard.local_playback|app-inverse:linuxsoundboard.virtual_mic_feeder" \
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
    echo "Stream started (PID: $pid)"
    echo "Watch: $WATCH_URL"
    echo "Log: $LOG_FILE"
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

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop && start ;;
    *) echo "Usage: $0 {start|stop|restart} [stream_key]"
       echo "Stream key defaults to the current username." ;;
esac
