#!/usr/bin/env bash

stops=0

# How many time units to print
if [ -z "$1" ]; then
    stopafter=2
else
    stopafter="$1"
fi

# Get filesystem birth time of / (in seconds since epoch)
os_install_epoch=$(stat -c %W /)

if [ "$os_install_epoch" -eq 0 ]; then
    echo "Filesystem birth time not supported."
    exit 1
fi

# Convert to YYYY-MM-DD for calendar calculations
install_date=$(date -d "@$os_install_epoch" +%Y-%m-%d)
install_month_day=$(date -d "@$os_install_epoch" +%m-%d)

current_epoch=$(date +%s)
today=$(date +%Y-%m-%d)

if [ -z "$2" ]; then
    # Age mode: time since install
    diff=$((current_epoch - os_install_epoch))
    prefix=""
    suffix="old"
else
    # Birthday mode: time until next anniversary of install date
    # Find the next occurrence of install_month_day on or after today
    next_anniv=$(date -d "$today" +%Y)-$install_month_day
    if [[ $(date -d "$next_anniv" +%s) -lt $(date -d "$today" +%s) ]]; then
        # If this year's anniversary already passed, use next year
        next_year=$(( $(date -d "$today" +%Y) + 1 ))
        next_anniv="$next_year-$install_month_day"
    fi

    target_epoch=$(date -d "$next_anniv" +%s)
    diff=$((target_epoch - current_epoch))
    prefix="In "
    suffix=""
fi

# Ensure diff is non‑negative
if [ "$diff" -lt 0 ]; then
    diff=$(( -diff ))
fi

# Break down the difference using average month/day lengths for display only
year=31556926
month=$((year / 12))
day=86400
hour=3600
minute=60

years=$((diff / year))
diff=$((diff % year))

months=$((diff / month))
diff=$((diff % month))

days=$((diff / day))
diff=$((diff % day))

hours=$((diff / hour))
diff=$((diff % hour))

minutes=$((diff / minute))
seconds=$((diff % minute))

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
