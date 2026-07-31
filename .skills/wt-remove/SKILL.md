---
name: wt-remove
description: Remove a git worktree (and delete its branch if merged) using wt.
allowed-tools:
- "Bash(wt:*)"
- "Bash(git:*)"
---

## Examples

> wt-remove
> wt-remove: my-feature

## Inputs

The user provides:
- **Name** (optional): the branch name (or short name — the branch is `smcloughlin/<name>`)
- Optionally: flags like `--force`, `--force-delete` / `-D`, or `--no-delete-branch`

If the user doesn't provide a branch name, it is because you've been working on a specific worktree throughout the conversation. That is the one you should delete. If you've been working on _more_ than one, or you haven't been working on one at all, you MUST ask the user for clarification on what worktree to operate on.

## Workflow

### 1. Fetch origin/main

You need to fetch `origin/main` to accurately determine if the branch has merged.

```bash
git fetch origin main
```

### 2. Remove the worktree

> **Note on submodules:** Cleanup of submodule worktrees is handled automatically by the `pre-remove.submodules` hook in `~/.config/worktrunk/config.toml` — it runs `git worktree remove --force` on each submodule's git dir and prunes any stale entries before the working directory is deleted.

Run from the current repo directory:

```bash
wt remove -y --force --foreground smcloughlin/<name>
```

- Use `--force` to handle untracked files (e.g. build artifacts).
- Use `--foreground` so we can confirm completion.
- Use `-y` to skip interactive prompts.
- If the user asks to keep the branch, add `--no-delete-branch`.
- If the user asks to force-delete an unmerged branch, add `-D`.

### 3. Re-pin submodule pointers to the main clone

Removing a worktree can leave each submodule's *shared* `core.worktree`
(`.git/modules/<sm>/config`) pointing at the now-deleted worktree, because that
pointer is single-valued and shared across every worktree. The next `git status`
in the main clone then fatals with `cannot chdir to '.../callandor.<name>/...'`.

Run this guard from the main clone to re-pin every top-level submodule's shared
pointer back to the main checkout:

```bash
GIT_COMMON_DIR=$(git rev-parse --absolute-git-dir)
ROOT=$(git rev-parse --show-toplevel)
git config --file "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.path' | awk '{print $2}' | while read -r sm; do
  cfg="$GIT_COMMON_DIR/modules/$sm/config"
  [ -f "$cfg" ] || continue
  # depth = (.git, modules) + components in sm
  up=$(printf '../%.0s' $(seq 1 $(( $(awk -F/ '{print NF}' <<<"$sm") + 2 ))))
  git config -f "$cfg" core.worktree "${up}${sm}"
done
git status --short >/dev/null && echo "submodule pointers OK"
```

### 4. Confirm

Report to the user that the worktree and branch were removed (or that the branch was kept, if unmerged).
