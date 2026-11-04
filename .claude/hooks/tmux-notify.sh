#!/bin/sh
# Claude Code Notification hook: a Ghostty banner plus a bell for the tab that sent it.
# In tmux, the banner title is the tmux session name.
msg=$(jq -r '.message // "Claude Code"')

if [ -n "$TMUX_PANE" ]; then
    tty=$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}')
    title=$(tmux display -p -t "$TMUX_PANE" '#S')
    printf '\033Ptmux;\033\033]777;notify;%s;%s\a\033\\' "$title" "$msg" > "$tty"
    printf '\a' > "$tty"
    exit 0
fi

pid=$PPID
while [ "$pid" -gt 1 ]; do
    name=$(ps -o tty= -p "$pid" | tr -d ' ')
    case "$name" in
        ''|'?'|'??') pid=$(ps -o ppid= -p "$pid" | tr -d ' ') ;;
        *) printf '\033]777;notify;Claude Code;%s\a' "$msg" > "/dev/$name"; exit 0 ;;
    esac
done
