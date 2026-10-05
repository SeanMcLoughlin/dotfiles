---
name: wt-create
description: Create a new git worktree under ~/repos using wt, with a branch named smcloughlin/<name>.
allowed-tools:
- "Bash(wt:*)"
- "Bash(git:*)"
- "EnterWorktree"
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

### 2. Create the worktree and enter it

Call the `EnterWorktree` tool with the `name`:

```
EnterWorktree(name="<name>")
```

The `WorktreeCreate` hook (`~/.claude/hooks/worktree-create.sh`) runs `wt switch --create smcloughlin/<name>` with the path `~/repos/{{ repo }}.{{ branch | sanitize }}`, where `{{ branch | sanitize }}` is the **full branch name** with every `/` replaced by `-`. For example:
- name `my-feature` → branch `smcloughlin/my-feature`, path `~/repos/<repo>.smcloughlin-my-feature`
- name `vm/my-tool` → branch `smcloughlin/vm/my-tool`, path `~/repos/<repo>.smcloughlin-vm-my-tool`

Do **not** put the `smcloughlin` prefix in `name`; the hook adds it. Do **not** pass `path`, and do **not** substitute a `cd`.

A worktree made by the hook keeps the session transcript in the directory where the session started, so `claude --resume` in the main checkout lists the session. The status line reports the new branch, and Claude Code blocks accidental edits to the main checkout.

To leave the worktree later, use `ExitWorktree` with `action: "keep"`. `ExitWorktree` cannot delete a worktree made by the hook — use the `wt-remove` skill for deletion.

### 3. Confirm

Report the worktree path and branch name to the user.

> **Note on submodules:** Submodule initialization is handled automatically by the `pre-start.submodules` hook in `~/.config/worktrunk/config.toml`. Rather than cloning submodule object data from scratch, the hook uses `git worktree add` on each already-initialized submodule's git dir (under `.git/modules/`) to create a fast, object-sharing checkout. It falls back to `git submodule update --init` for any submodule not yet initialized in the main repo, or if a required commit isn't available locally.
>
> After adding each submodule worktree the hook explicitly pins its per-worktree `core.worktree` (`git -C "$TARGET" config --worktree core.worktree "$TARGET"`). `git worktree add` does **not** reliably write this even with `extensions.worktreeConfig` on; when it is absent git falls back to the wrong-depth shared value and `git status` reports every submodule as `(modified content, untracked content)` — the real files look deleted and the git-internal files (`HEAD`, `config`, `objects/`) look untracked. If you see a worktree in that state, it predates the pin; recover it with:
>
> ```bash
> WT=~/repos/<repo>.smcloughlin-<name>
> git config --file "$WT/.gitmodules" --get-regexp 'submodule\..*\.path' | awk '{print $2}' | while read -r s; do
>   git -C "$WT/$s" config --worktree core.worktree "$WT/$s"
> done
> ```

### 4. Follow up Commands

The session is now inside the worktree, so ordinary relative paths already resolve there.
Work on the new worktree, never on the main checkout.

## Renaming an existing worktree

Renaming a worktree (e.g. because the branch was renamed) is more work than `git worktree move` because that command **refuses to operate on worktrees containing submodules** (fails with `fatal: working trees containing submodules cannot be moved or removed`). A repository with submodules always hits this, so plan to do this manually.

### Steps

```bash
OLD_PATH=~/repos/<repo>.smcloughlin-OLD
NEW_PATH=~/repos/<repo>.smcloughlin-NEW
MAIN_GIT=<main-checkout>/.git
OLD_NAME=$(basename "$OLD_PATH")   # e.g. <repo>.smcloughlin-OLD
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
