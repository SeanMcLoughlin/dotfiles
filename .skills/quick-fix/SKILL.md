---
name: quick-fix
description: Create a worktree, apply a small fix, commit, push with auto-merge MR, monitor CI, and clean up.
allowed-tools:
- "Bash(git status:*)"
- "Bash(git diff:*)"
- "Bash(git log:*)"
- "Bash(git add:*)"
- "Bash(git commit:*)"
- "Bash(git push:*)"
- "Bash(git branch:*)"
- "Bash(wt:*)"
- "Bash(glab:*)"
---

## Example

> quick-fix: name=fix-ci-doc, fix: replace `cal_tools` with `pytools` in docs/ci.md

## Inputs

The user provides:
- **Name**: a short name; the branch will be `$USER/<name>`
- **Fix description**: what to change

## Workflow

### 1. Create worktree

```bash
cd ~/repos/callandor
wt switch --create $USER/<name>
```

Note the worktree path from the output (e.g., `~/repos/callandor.$USER-<name>`). All subsequent commands run from that path.

### 2. Apply the fix

Make the requested change in the worktree directory. Keep it minimal.

### 3. Commit

- Stage all changes with `git add -A`
- Write a commit message using the 50/72 rule
- Match the existing commit message style (check `git log --oneline -5`)
- Do not reference yourself as a co-author

### 4. Push with auto-merge MR

For the **first push**:

```bash
git push -u origin HEAD \
  -o merge_request.create \
  -o merge_request.target=main \
  -o merge_request.merge_when_pipeline_succeeds \
  -o merge_request.remove_source_branch
```

For **subsequent pushes** (after a CI fix):

```bash
git push --force-with-lease \
  -o merge_request.merge_when_pipeline_succeeds
```

Note the MR URL from the push output. Extract the MR number (e.g., `97` from `.../merge_requests/97`).

After pushing, verify that auto-merge (MWPS) is armed:

```bash
glab api "projects/arch%2Fcallandor/merge_requests/<MR_NUMBER>" | jq '{merge_when_pipeline_succeeds}'
```

If `merge_when_pipeline_succeeds` is `false`, the API token lacks write access — do not attempt to arm it via the API. Tell the user to confirm it is armed in the GitLab UI.

### 5. Monitor CI and clean up

Poll the pipeline status every 30 seconds using `glab`:

```bash
glab api "projects/arch%2Fcallandor/merge_requests/<MR_NUMBER>/pipelines" | jq '.[0] | {id, status}'
```

Pipeline statuses:
- `running` / `pending` / `created` — keep polling
- `success` — CI passed, proceed to cleanup
- `failed` / `canceled` — CI failed, proceed to fix

**On success:**
1. Remove the worktree:
   ```bash
   cd ~/repos/callandor
   wt remove $USER/<name>
   ```
2. Report success to the user.

**On failure:**
1. Check the failed job logs:
   ```bash
   glab api "projects/arch%2Fcallandor/pipelines/<PIPELINE_ID>/jobs" | jq '.[] | select(.status == "failed") | {id, name, status}'
   glab api "projects/arch%2Fcallandor/jobs/<JOB_ID>/trace" 2>&1 | tail -50
   ```
2. Fix the issue in the worktree.
3. Commit the fix (amend or new commit as appropriate).
4. Push with `--force-with-lease` (see step 4 above).
5. Return to monitoring (this step).
