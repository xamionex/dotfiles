#!/usr/bin/env bash

stops=0

# How many time units to print
if [ -z "$1" ]; then
    stopafter=2
else
    stopafter="$1"
fi

# Get filesystem birth time of /
os_install_date=$(stat -c %W /)

if [ "$os_install_date" -eq 0 ]; then
    echo "Filesystem birth time not supported."
    exit 1
fi

current=$(date +%s)

# Seconds constants (consistent units)
year=31556926
month=$((year / 12))
day=86400
hour=3600
minute=60

if [ -z "$2" ]; then
    time_diff=$((current - os_install_date))
    prefix=""
    suffix="old"
else
    prefix="In "
    suffix=""
    target=$((os_install_date + year))
    time_diff=$((target - current))
fi

# Handle negative values safely
if [ "$time_diff" -lt 0 ]; then
    time_diff=$(( -time_diff ))
fi

years=$((time_diff / year))
time_diff=$((time_diff % year))

months=$((time_diff / month))
time_diff=$((time_diff % month))

days=$((time_diff / day))
time_diff=$((time_diff % day))

hours=$((time_diff / hour))
time_diff=$((time_diff % hour))

minutes=$((time_diff / minute))
seconds=$((time_diff % minute))

echo -n "$prefix"

format() {
    if [ "$stops" -lt "$stopafter" ] && [ "$1" -gt 0 ]; then
        plural=""
        if [ "$1" -ne 1 ]; then
            plural="s"
        fi
        echo -n "$1 $2$plural "
        stops=$((stops + 1))
    fi
}

format "$years" "year"
format "$months" "month"
format "$days" "day"
format "$hours" "hour"
format "$minutes" "minute"
format "$seconds" "second"

echo "$suffix"
