#!/bin/bash

stops=0
if [ -z $1 ]; then
    stopafter=2
else
    stopafter=$1
fi

os_install_date=$(stat -c %W /)
current=$(date +%s)

if [ -z $2 ]; then
    time_diff=$(( ($current - $os_install_date) ))
    suffix="old"
else
    prefix="In "
    os_install_date=$(( $os_install_date + 31556926 ))
    time_diff=$(( ($(date -d @$os_install_date '+%s') - $current) ))
fi

seconds=$((time_diff % 60))
minutes=$(( (time_diff / 60) % 60 ))
hours=$(( (time_diff / (60 * 60)) % 24 ))
days=$(( (time_diff / (60 * 60 * 24)) % 30 ))
months=$(( (time_diff / (60 * 60 * 24 * 30)) % 12 ))
years=$((time_diff / (60 * 60 * 24 * 30 * 12)))

echo -n "$prefix"

format() {
    if [ $stops -ne $stopafter ]; then
        if [ $1 -gt 0 ]; then
            plural=""
            if [ $1 -gt 1 ]; then
                plural="s"
            fi
            echo -n "$1 $2$plural "
            stops=$(( $stops + 1 ))
        fi
    fi
}

format "$years" "year"
format "$months" "month"
format "$days" "day"
format "$hours" "hour"
format "$minutes" "minute"
format "$seconds" "second"

echo "$suffix"
