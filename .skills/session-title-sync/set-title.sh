#!/usr/bin/env bash
# set-title.sh — set the current Claude Code session's terminal tab title.
#
# Same primitive as the built-in `/rename` command: an OSC 0 escape sequence
# written to /dev/tty. Also persists the title to a state file so a
# UserPromptSubmit hook can restore it after /resume or a terminal restart
# (a raw OSC write does not survive that on its own).
#
# Usage: set-title.sh <session-id> <title>
#   session-id: pass $CLAUDE_SESSION_ID if set; otherwise omit as "" and this
#               script will resolve it from the newest transcript under
#               ~/.claude/projects/<sanitized-cwd>/.
set -euo pipefail

session_id="${1:-}"
title="${2:-}"

if [[ -z "$title" ]]; then
    echo "usage: $0 <session-id-or-empty> <title>" >&2
    exit 1
fi

if [[ -z "$session_id" ]]; then
    project_dir="$HOME/.claude/projects/$(pwd | tr '/_' '-_')"
    if [[ -d "$project_dir" ]]; then
        latest=$(ls -t "$project_dir"/*.jsonl 2>/dev/null | head -1 || true)
        [[ -n "$latest" ]] && session_id=$(basename "$latest" .jsonl)
    fi
fi
[[ -z "$session_id" ]] && session_id="unknown"

# Reject path-shaped values before they can land as a tab title.
case "$title" in
    /*|*/var/folders/*|*/tmp/*|*/private/*)
        echo "refusing path-shaped title: $title" >&2
        exit 1
        ;;
esac

# Strip control chars, collapse newlines, cap length.
title="${title//$'\033'/}"
title="${title//$'\007'/}"
title="${title//$'\r'/}"
title="${title//$'\n'/ }"
[[ ${#title} -gt 80 ]] && title="${title:0:80}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
mkdir -p "$state_dir"
printf '%s\n' "$title" > "$state_dir/${session_id}.title"

if [[ -w /dev/tty ]]; then
    printf '\033]0;%s\007' "$title" 2>/dev/null > /dev/tty || true
fi

printf '%s\n' "$title"
