#!/usr/bin/env bash

# Default base Windows drive letter mapped to /
WINROOT="Z:"

convert_path() {
    local path="$1"

    # Normalize path
    path=$(realpath "$path" 2>/dev/null || echo "$path")

    # Special case: /mnt/c/... or /mnt/... style
    if [[ "$path" == /mnt/* ]]; then
        echo "$WINROOT$path" | sed 's|/|\\|g'
    # Normal /home/petar/... or anything else
    else
        echo "$WINROOT$path" | sed 's|/|\\|g'
    fi
}

# Usage check
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path1> [<path2> ...]"
    exit 1
fi

# Convert all paths passed as arguments
for p in "$@"; do
    convert_path "$p"
done
