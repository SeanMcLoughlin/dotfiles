#!/usr/bin/env bash
# Print a tmux status bubble with the disk use of $WORK. Print nothing when $WORK is not set.
# Reads a cache file at once; refreshes it in the background when it is older than MAX_AGE seconds.

[ -n "$WORK" ] || exit 0

MAX_AGE=60
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-work-disk.txt"
LOCK="$CACHE.lock"

mkdir -p "$(dirname "$CACHE")"

if [ "$(uname)" = Darwin ]; then
    mtime() { stat -f %m "$1"; }
else
    mtime() { stat -c %Y "$1"; }
fi

age=$((MAX_AGE + 1))
if [ -f "$CACHE" ] && [ "$(sed -n 1p "$CACHE")" = "$WORK" ]; then
    age=$(($(date +%s) - $(mtime "$CACHE")))
fi

if [ "$age" -gt "$MAX_AGE" ] && mkdir "$LOCK" 2>/dev/null; then
    (
        trap 'rmdir "$LOCK"' EXIT
        use=$(df -P "$WORK" 2>/dev/null | awk 'NR==2 {print $5}')
        if [ -n "$use" ]; then
            printf '%s\n%s' "$WORK" "$use" >"$CACHE.new" && mv "$CACHE.new" "$CACHE"
        fi
    ) >/dev/null 2>&1 &
fi

[ -f "$CACHE" ] && [ "$(sed -n 1p "$CACHE")" = "$WORK" ] || exit 0

# \356\202\266 and \356\202\264 are the round bubble ends; \357\202\240 is the disk glyph.
printf '#[fg=green,bg=default,noreverse,nobold]\356\202\266#[reverse,bold] \357\202\240 %s #[noreverse,nobold]#[fg=green]\356\202\264 ' "$(sed -n 2p "$CACHE")"
