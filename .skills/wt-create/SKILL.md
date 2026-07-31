---
name: wt-create
description: Create a new git worktree under ~/repos using wt, with a branch named smcloughlin/<name>.
allowed-tools:
- "Bash(wt:*)"
- "Bash(git:*)"
---

## Example

> wt-create: my-feature

## Inputs

The user provides:
- **Name**: a short name for the branch (the branch will be `smcloughlin/<name>`)

## Workflow

### 1. Pull latest changes on main

From the current repo directory, pull the latest changes on `main` so the new worktree starts from an up-to-date base:

```bash
git fetch origin main && git merge --ff-only origin/main
```

If the fast-forward merge fails (e.g. local commits ahead of origin), report the conflict to the user and stop — do not create the worktree until the main branch is clean.

### 2. Create the worktree

Run from the current repo directory:

```bash
WORKTRUNK_WORKTREE_PATH="$HOME/repos/{{ repo }}.{{ branch | sanitize }}" wt switch --create smcloughlin/<name>
```

The `{{ branch | sanitize }}` placeholder is the **full branch name** (`smcloughlin/<name>`) with every `/` replaced by `-`. For example:
- branch `smcloughlin/my-feature` → path `~/repos/callandor.smcloughlin-my-feature`
- branch `smcloughlin/vm/rocky9-from-tt-mirror` → path `~/repos/callandor.smcloughlin-vm-rocky9-from-tt-mirror`

Do **not** drop the `smcloughlin` prefix, and do **not** use `.` as a separator within the branch portion.

### 3. Confirm

Report the worktree path and branch name to the user.

> **Note on submodules:** Submodule initialization is handled automatically by the `pre-start.submodules` hook in `~/.config/worktrunk/config.toml`. Rather than cloning submodule object data from scratch, the hook uses `git worktree add` on each already-initialized submodule's git dir (under `.git/modules/`) to create a fast, object-sharing checkout. It falls back to `git submodule update --init` for any submodule not yet initialized in the main repo, or if a required commit isn't available locally.
>
> After adding each submodule worktree the hook explicitly pins its per-worktree `core.worktree` (`git -C "$TARGET" config --worktree core.worktree "$TARGET"`). `git worktree add` does **not** reliably write this even with `extensions.worktreeConfig` on; when it is absent git falls back to the wrong-depth shared value and `git status` reports every submodule as `(modified content, untracked content)` — the real files look deleted and the git-internal files (`HEAD`, `config`, `objects/`) look untracked. If you see a worktree in that state, it predates the pin; recover it with:
>
> ```bash
> WT=/Users/smcloughlin/repos/callandor.smcloughlin-<name>
> git config --file "$WT/.gitmodules" --get-regexp 'submodule\..*\.path' | awk '{print $2}' | while read -r s; do
>   git -C "$WT/$s" config --worktree core.worktree "$WT/$s"
> done
> ```

### 4. Follow up Commands

After confirmation, the user expects you to modify files in the new worktree path you've created; NOT your current path.

## Renaming an existing worktree

Renaming a worktree (e.g. because the branch was renamed) is more work than `git worktree move` because that command **refuses to operate on worktrees containing submodules** (fails with `fatal: working trees containing submodules cannot be moved or removed`). Callandor worktrees all have submodules, so plan to do this manually.

### Steps

```bash
OLD_PATH=/Users/smcloughlin/repos/callandor.smcloughlin-OLD
NEW_PATH=/Users/smcloughlin/repos/callandor.smcloughlin-NEW
MAIN_GIT=/Users/smcloughlin/repos/callandor/.git
OLD_NAME=$(basename "$OLD_PATH")   # e.g. callandor.smcloughlin-OLD
NEW_NAME=$(basename "$NEW_PATH")

# 1. Rename the branch (run from inside the worktree).
git -C "$OLD_PATH" branch -m smcloughlin/OLD smcloughlin/NEW

# 2. Move the worktree directory and its main-repo metadata dir.
mv "$OLD_PATH" "$NEW_PATH"
mv "$MAIN_GIT/worktrees/$OLD_NAME" "$MAIN_GIT/worktrees/$NEW_NAME"

# 3. Patch the worktree's .git file (it's a gitlink, not a dir).
sed -i '' "s|$OLD_NAME|$NEW_NAME|g" "$NEW_PATH/.git"

# 4. Patch the metadata dir's gitdir file (points back at the worktree).
sed -i '' "s|$OLD_NAME|$NEW_NAME|g" "$MAIN_GIT/worktrees/$NEW_NAME/gitdir"

# 5. Patch every submodule reverse pointer.
grep -rlF "$OLD_NAME" "$MAIN_GIT/modules" 2>/dev/null \
    | xargs -I{} sed -i '' "s|$OLD_NAME|$NEW_NAME|g" {}

# 6. Verify.
git worktree list | grep "$NEW_NAME"
```

### After the move

- **Python venvs break.** A `.venv` created via `python -m venv` hard-codes the absolute path in every script's shebang (`.venv/bin/python` is itself a symlink, but `.venv/bin/<other-script>` has `#!/path/to/old/.venv/bin/python3`). Recreate any venv inside the worktree: `rm -rf .venv && python3.X -m venv .venv && .venv/bin/pip install -e .` (or `uv sync`).
- **Other absolute-path artifacts.** Anything generated inside the worktree that captured the absolute path (e.g. baseline trace metadata, ELF symbol paths, build artifacts referencing source paths) may need regeneration. Search for the old path inside the worktree: `grep -rF "$OLD_NAME" "$NEW_PATH"` — false-positive matches inside generated provenance files are usually safe to ignore, but anything an executable consumes (scripts, configs, lockfiles) needs updating.
