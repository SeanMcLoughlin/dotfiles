#!/bin/bash
# WorktreeCreate hook: make the worktree with wt at ~/repos/<repo>.smcloughlin-<name> and print its path.
set -euo pipefail
input=$(cat)
name=$(jq -r '.name' <<<"$input")
cwd=$(jq -r '.cwd' <<<"$input")
branch="smcloughlin/$name"
cd "$cwd"
WORKTRUNK_WORKTREE_PATH="$HOME/repos/{{ repo }}.{{ branch | sanitize }}" \
  wt switch --create "$branch" --no-cd --yes >&2
git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{p=$2} $0=="branch "b{print p}'
