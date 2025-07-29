#!/bin/bash
file="$HOME/.config/fastfetch/lines.json"
range=$(jq -r 'length' "$file")
RANDOM=$PPID
n=$((RANDOM % range + 1))

case $1 in
  header) jq -r --arg n "$n" 'to_entries | .[$n|tonumber-1].key' "$file" ;;
  footer) jq -r --arg n "$n" 'to_entries | .[$n|tonumber-1] | if .value != "" then .value else .key end' "$file" ;;
esac
