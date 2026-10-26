#!/usr/bin/env bash
# Copy stdin to the clipboard as plain text.
# On a Mac with a local shell, use pbcopy. Elsewhere, send an OSC 52 escape sequence through tmux or the terminal, so the clipboard of the machine that shows the terminal receives the text.
set -euo pipefail

if [ -z "${SSH_CONNECTION:-}" ] && command -v pbcopy >/dev/null 2>&1; then
    exec pbcopy
fi

if [ -n "${TMUX:-}" ]; then
    exec tmux load-buffer -w -
fi

payload=$(base64 | tr -d '\n')
printf '\033]52;c;%s\a' "$payload" >/dev/tty
