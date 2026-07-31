#!/usr/bin/env bash
# restore-title.sh — UserPromptSubmit hook.
#
# Re-emits the saved OSC-0 tab title (set via set-title.sh) on every prompt
# submit, so the title set for this session survives /resume, a new
# terminal tab, or a tmux/terminal restart. No-op if no title was ever set
# for this session.
set -euo pipefail

input=$(cat)
[[ -z "$input" ]] && exit 0

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
[[ -z "$session_id" ]] && exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
title_file="$state_dir/${session_id}.title"
[[ -f "$title_file" ]] || exit 0

title=$(cat "$title_file")
[[ -z "$title" ]] && exit 0

if [[ -w /dev/tty ]]; then
    printf '\033]0;%s\007' "$title" 2>/dev/null > /dev/tty || true
fi

exit 0
