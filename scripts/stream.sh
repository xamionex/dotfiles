#!/bin/bash

start() {
    # Kill any running OBS processes
    pkill -x obs 2>/dev/null
    # Launch OBS in the background
    obs --collection Untitled --minimize-to-tray --startstreaming &
    echo "Started OBS streaming."
}

stop() {
    # Kill any running OBS processes
    pkill -x obs 2>/dev/null
    echo "Stopped OBS."
}

case "$1" in
    start) start ;;
    stop)  stop  ;;
    restart) stop && start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
