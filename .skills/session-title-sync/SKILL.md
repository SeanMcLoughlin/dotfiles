---
name: session-title-sync
description: Set or update the current Claude Code terminal tab title programmatically (same OSC-0 mechanism as /rename). Use when chaining into simscope-repro-signature (title = "debug <regression-id> sig#<signature-number>") or after filing a Jira bug (append " <BUG-ID>" to the current title).
allowed-tools:
- "Bash(~/.skills/session-title-sync/set-title.sh:*)"
---

## What this does

Sets the terminal tab title for the current session by writing an OSC 0
escape sequence to `/dev/tty` — the same mechanism `/rename` itself uses.
Also persists the title to a state file
(`~/.local/state/claude-code-session-title/<session-id>.title`) so it
survives a `/resume` (a raw OSC write does not persist across TTY restarts
on its own).

## When to invoke

- **From `simscope-repro-signature`**: as soon as the regression ID and
  signature number are both known (usually right after the repro is
  identified, before the deep debug work starts), set the title to:
  `debug <regression-id> sig#<signature-number>`

- **After filing a Jira bug** (e.g. via `callandor-workflow-file-jira-bug`
  during a debug session started above): re-read the current title from the
  state file and append the bug ID, e.g.:
  `debug <regression-id> sig#<signature-number> CAL-1234`

## How to invoke

```bash
~/.skills/session-title-sync/set-title.sh "$CLAUDE_SESSION_ID" "debug 20260719-1 sig#1261"
```

To append to the existing title instead of replacing it, read the current
value first:

```bash
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
current=$(cat "$state_dir/${CLAUDE_SESSION_ID}.title" 2>/dev/null || true)
~/.skills/session-title-sync/set-title.sh "$CLAUDE_SESSION_ID" "${current} CAL-1234"
```

If `$CLAUDE_SESSION_ID` is unset, pass `""` as the first argument — the
script resolves the session ID from the newest transcript file under
`~/.claude/projects/<sanitized-cwd>/`.

Do not narrate this to the user as a major action — it's a cosmetic,
reversible, purely local change (no network, no repo state). A one-line
confirmation ("Tab title set to: <title>") after the call is enough.
