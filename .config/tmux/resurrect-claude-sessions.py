#!/usr/bin/env python3
"""Rewrite a tmux-resurrect save file so each Claude Code pane resumes its own conversation.

Usage: resurrect-claude-sessions.py <save-file>

Claude Code writes ~/.claude/sessions/<pid>.json for every running process. The file names
the conversation (sessionId) and the tmux pane (for example "main:@11.%15"). For each saved
pane that runs claude, this script replaces any --resume/--continue option with
"--resume <sessionId>" so a restore reopens the same conversation.
"""

import glob
import json
import os
import re
import subprocess
import sys

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
RESUME_FLAGS = {"--resume", "-r", "--continue", "-c"}


def pane_locations():
    out = subprocess.run(
        ["tmux", "list-panes", "-a", "-F",
         "#{pane_id}\t#{session_name}\t#{window_index}\t#{pane_index}"],
        capture_output=True, text=True, check=True,
    ).stdout
    locations = {}
    for line in out.splitlines():
        pane_id, session, window, pane = line.split("\t")
        locations[pane_id] = (session, window, pane)
    return locations


def conversations_by_location():
    locations = pane_locations()
    found = {}
    for path in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            with open(path) as f:
                info = json.load(f)
            os.kill(int(info["pid"]), 0)
            pane_id = info["tmux"].rsplit(".", 1)[1]
            found[locations[pane_id]] = info["sessionId"]
        except (OSError, ValueError, KeyError, IndexError):
            continue
    return found


def with_conversation(full_command, session_id):
    tokens = full_command.split(" ")
    kept = []
    skip_value = False
    for token in tokens:
        if skip_value and UUID.match(token):
            skip_value = False
            continue
        skip_value = False
        if token in RESUME_FLAGS:
            skip_value = True
            continue
        kept.append(token)
    return " ".join(kept + ["--resume", session_id])


def main(path):
    conversations = conversations_by_location()
    with open(path) as f:
        lines = f.read().split("\n")
    for i, line in enumerate(lines):
        fields = line.split("\t")
        if fields[0] != "pane" or len(fields) < 11:
            continue
        location = (fields[1], fields[2], fields[5])
        command = fields[10]
        if command.startswith(":claude ") or command == ":claude":
            session_id = conversations.get(location)
            if session_id:
                fields[10] = ":" + with_conversation(command[1:], session_id)
                lines[i] = "\t".join(fields)
    with open(path, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except Exception as error:
        print(f"resurrect-claude-sessions: {error}", file=sys.stderr)
    sys.exit(0)
