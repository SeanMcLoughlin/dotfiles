#!/usr/bin/env bash
# Print a tmux status bubble with the disk use of $WORK. Print nothing when $WORK is not set.
# When WORK_QUOTA_TOOL names a df-like quota tool (it takes -h --user USER PATH), show the quota: used/limit and percent, red at WARN_PCT or more.
# Elsewhere, show the size of the files under $WORK.
# Reads a cache file at once; refreshes it in the background when it is older than MAX_AGE seconds.

[ -n "$WORK" ] || exit 0

PDF=${WORK_QUOTA_TOOL:-}
WARN_PCT=80
if [ -n "$PDF" ] && [ -x "$PDF" ]; then MAX_AGE=300; else PDF=; MAX_AGE=3600; fi
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
        pct=
        if [ -n "$PDF" ]; then
            read -r use pct < <("$PDF" -h --user "$USER" "$WORK" 2>/dev/null | awk 'NR > 1 && NF >= 5 {
                p = $(NF - 1); sub(/%/, "", p); printf "%s/%s %s\n", $(NF - 3), $(NF - 4), p }' | tail -1)
        else
            use=$(du -sk "$WORK" 2>/dev/null | awk '{
                k = $1
                if (k >= 1073741824) printf "%.1fT", k / 1073741824
                else if (k >= 1048576) printf "%.0fG", k / 1048576
                else if (k >= 1024) printf "%.0fM", k / 1024
                else printf "%dK", k
            }')
        fi
        if [ -n "$use" ]; then
            printf '%s\n%s\n%s' "$WORK" "$use" "$pct" >"$CACHE.new" && mv "$CACHE.new" "$CACHE"
        fi
    ) >/dev/null 2>&1 &
fi

[ -f "$CACHE" ] && [ "$(sed -n 1p "$CACHE")" = "$WORK" ] || exit 0

use=$(sed -n 2p "$CACHE")
pct=$(sed -n 3p "$CACHE")
color=green
label=$use
if [ -n "$pct" ]; then
    label="$use $pct%"
    [ "$pct" -ge "$WARN_PCT" ] 2>/dev/null && color=red
fi

# \356\202\266 and \356\202\264 are the round bubble ends; \357\202\240 is the disk glyph.
printf '#[fg=%s,bg=default,noreverse,nobold]\356\202\266#[reverse,bold] \357\202\240 %s #[noreverse,nobold]#[fg=%s]\356\202\264 ' "$color" "$label" "$color"
