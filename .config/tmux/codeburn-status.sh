#!/usr/bin/env bash
# Print today's AI spend for the tmux status bar.
# Reads a cache file at once; refreshes it in the background when it is older than MAX_AGE seconds.

MAX_AGE=120
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-codeburn.txt"
LOCK="$CACHE.lock"

mkdir -p "$(dirname "$CACHE")"

age=$((MAX_AGE + 1))
if [ -f "$CACHE" ]; then
    age=$(($(date +%s) - $(stat -c %Y "$CACHE")))
fi

if [ "$age" -gt "$MAX_AGE" ] && mkdir "$LOCK" 2>/dev/null; then
    (
        trap 'rmdir "$LOCK"' EXIT
        if json=$(codeburn status --format json 2>/dev/null); then
            cost=$(printf '%s' "$json" | sed -n 's/.*"today":{"cost":\([0-9.]*\).*/\1/p')
            if [ -n "$cost" ]; then
                printf '$%.2f' "$cost" >"$CACHE.new" && mv "$CACHE.new" "$CACHE"
            fi
        fi
    ) >/dev/null 2>&1 &
fi

[ -f "$CACHE" ] && cat "$CACHE"
