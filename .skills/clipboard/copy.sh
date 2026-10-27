#!/usr/bin/env bash
# Copy Markdown from stdin to the clipboard. With --rich, also put it there as HTML.
# On a Mac with a local shell, use pbcopy, or copy-rich.sh for --rich.
# Elsewhere, send escape sequences to the terminal, so the clipboard of the machine that shows the terminal receives the text: OSC 52 for plain text, then OSC 5522 for plain text with HTML. A terminal that does not know OSC 5522 ignores it and keeps the OSC 52 copy.
# Inside tmux, the escape sequences go through tmux passthrough, which needs "set -g allow-passthrough on".
# Ghostty answers an OSC 5522 write with a status message. The tmux config defines that message as a user key, so tmux drops it instead of typing it into the active pane.
set -euo pipefail

rich=0
if [ "${1:-}" = "--rich" ]; then
    rich=1
fi

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
esc=$'\033'
st="${esc}\\"

md=$(mktemp)
trap 'rm -f "$md"' EXIT
cat >"$md"

if [ -z "${SSH_CONNECTION:-}" ] && command -v pbcopy >/dev/null 2>&1; then
    if [ "$rich" = 1 ]; then
        exec "$here/copy-rich.sh" <"$md"
    fi
    exec pbcopy <"$md"
fi

b64() { base64 | tr -d '\n'; }

osc52="${esc}]52;c;$(b64 <"$md")${esc}\\"

osc5522=""
if [ "$rich" = 1 ] && command -v pandoc >/dev/null 2>&1; then
    html=$(mktemp)
    trap 'rm -f "$md" "$html"' EXIT
    if ! pandoc --from gfm --to html --wrap=none --syntax-highlighting=none "$md" -o "$html" 2>/dev/null; then
        pandoc --from gfm --to html --wrap=none --no-highlight "$md" -o "$html"
    fi
    osc5522="${esc}]5522;type=write${st}"
    for part in "text/plain:$md" "text/html:$html"; do
        mime=${part%%:*}
        mime64=$(printf %s "$mime" | b64)
        while IFS= read -r chunk || [ -n "$chunk" ]; do
            osc5522+="${esc}]5522;type=wdata:mime=${mime64};${chunk}${st}"
        done < <(b64 <"${part#*:}" | fold -w 4096)
    done
    osc5522+="${esc}]5522;type=wdata${st}"
fi

if [ -n "${TMUX:-}" ]; then
    tty=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_tty}')
    tmux load-buffer - <"$md"
    payload="${esc}Ptmux;${osc52//$esc/$esc$esc}${osc5522//$esc/$esc$esc}${st}"
else
    tty=/dev/tty
    payload="${osc52}${osc5522}"
fi

printf '%s' "$payload" >"$tty"
