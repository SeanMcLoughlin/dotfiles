---
name: shipit
description: Commit, push with auto-merge MR, monitor CI, and clean up the worktree on success.
allowed-tools:
- "Bash(git:*)"
- "Bash(wt:*)"
- "Bash(glab:*)"
- "Bash(sleep:*)"
- "Bash(open:*)"
- "Bash(vm:*)"
---

## Examples

> shipit
> shipit: smcloughlin/my-feature

## Inputs

The user provides:
- **Branch name** (optional): the branch to ship. If omitted, use the branch you've been working on in this conversation. If ambiguous, ask.

## Workflow

### 0. Run CI locally (pre-flight)

Run the **Pre-flight** section of the `/ci` skill.

### 1. Resolve the GitLab project path

Derive the URL-encoded project path from the git remote. Store it in a variable and reuse it for all `glab api` calls:

```bash
GLAB_PROJECT=$(git remote get-url origin | sed -E 's#(https?://[^/]*/|.*:)##; s#\.git$##; s#/#%2F#g')
```

This handles both SSH (`git@host:namespace/project.git`) and HTTPS (`https://host/namespace/project.git`) remotes. All subsequent `glab api` calls use `projects/$GLAB_PROJECT/...`.

### 2. Commit (git-commit)

Run the skill `/git-commit`.

If there are no uncommitted changes, skip this step.

### 3. Rebase on origin/main

Before pushing, fetch and rebase on top of the latest `main` to minimize the change of "ships passing" CI failures when merging code (e.g. when not rebased, our MR CI passes, but if we had rebased on top of `origin/main` it would have failed due to someone else's changes):

```bash
git fetch origin main
git rebase origin/main
```

If the rebase produces conflicts, stop and tell the user.

### 4. Push with auto-merge MR

For the **first push** (branch has no upstream):

```bash
git push -u origin HEAD \
  -o merge_request.create \
  -o merge_request.target=main \
  -o merge_request.merge_when_pipeline_succeeds \
  -o merge_request.remove_source_branch \
  -o merge_request.squash \
  -o merge_request.title="<title>" \
  -o merge_request.description="$(cat <DESC_FILE>)"
```

The `-u origin HEAD` is required so git knows where to push a new branch. The `-o merge_request.merge_when_pipeline_succeeds` flag arms auto-merge at push time so it does not need to be set separately via the API. The `-o merge_request.squash` flag ensures all branch commits are squashed into a single commit on merge, so fixup commits never land in `main` as separate entries.

**Title and description.** Set them at push time via `merge_request.title` / `merge_request.description` — this is the only write path we have, since `glab`/API write access is intentionally withheld (an Owner token could edit anything). Write a proper title (repo convention: `area: imperative summary`, e.g. `ci(nightly): …`, `dv/core: …`) and a markdown body. If the title/description aren't provided, draft them from the commit message and the conversation, and show the user before pushing.

**Multi-line descriptions.** `git push` **rejects any option value containing a real newline** (`fatal: push options must not have new line characters`). Encode the body's newlines as the literal two-character sequence `\n` first — GitLab renders them back into real newlines (verified). Write the markdown to a file, then:

```bash
DESC=$(awk '{printf "%s\\n", $0}' <DESC_FILE>)   # real newlines -> literal \n
git push … -o merge_request.description="$DESC"
```

Do **not** use `-o merge_request.description="$(cat <DESC_FILE>)"` — the real newlines make git reject the whole push.

**Updating title/description after the MR exists.** The same two options **overwrite** the MR's title/description on any *subsequent* push to the branch — but a push only applies them if it updates the ref. For a metadata-only change (no code change), re-stamp the commit so there's something to push, and add **`-o ci.skip`** so the edit does not restart CI:

```bash
git commit --amend --no-edit
DESC=$(awk '{printf "%s\\n", $0}' <DESC_FILE>)
git push --force-with-lease -o ci.skip \
  -o merge_request.title="<title>" \
  -o merge_request.description="$DESC"
```

`ci.skip` is load-bearing, not tidiness. A force-push cancels the running pipeline and starts a new one, so on a repo where an MR runs 100+ jobs, three rounds of wording edits burn three full pipelines and the reviewer watches the pipeline restart each time. `ci.skip` suppresses pipeline creation for that push, so the body updates and nothing runs.

**Only ever use `ci.skip` on a push whose diff is empty.** Two rules follow:

- Never on the failure-fix path (step 9) or any push that changes code — that push exists precisely to get a pipeline.
- The **last** push before merging must not carry it. Merge trains need a passing pipeline for the final SHA, and a skipped pipeline is not a passing one. If a metadata-only edit was the last thing pushed, re-push with a real pipeline before arming auto-merge (`git commit --amend --no-edit && git push --force-with-lease -o merge_request.merge_when_pipeline_succeeds`).

Verify it worked by confirming no pipeline was created for the new SHA, rather than assuming:

```bash
glab api "projects/$GLAB_PROJECT/merge_requests/<MR_NUMBER>/pipelines" | jq -r '.[0:2][] | "\(.id) \(.status) \(.sha[0:9])"'
```

Prefer batching: draft the whole body before the first push, and if the user asks for several wording changes, make them all in one push.

**Why push options at all, rather than the API.** The `agent` token holds `read_api`, `read_user`, `read_repository`, `write_repository`, `read_registry` — git push but no API writes. `PUT /merge_requests/<iid>` returns HTTP 403 `insufficient_scope`. Do not try it, and do not propose widening the token as a fix for a wording change: GitLab's PAT scopes are coarse, there is no merge-request-description scope, and `api` grants full read/write across every project the account can reach. Push options are scoped to the branch's own MR, which is the point. On the failure-fix path you're already amending and force-pushing, so append the title/description options there and correct the body in the same push.

After pushing, open the MR URL in the browser. Get it from the push output or from the API query in step 4, then:

```bash
open <MR_URL>
```

If the branch already has an upstream, just push normally — the existing MR will pick it up:

```bash
git push -o merge_request.merge_when_pipeline_succeeds
```

### 5. Resolve the MR number

Do NOT try to parse the MR number from push output — it's fragile. Instead, query `glab` by branch name:

```bash
glab api "projects/$GLAB_PROJECT/merge_requests?source_branch=<BRANCH_NAME>&state=opened" | jq '.[0] | {iid, web_url}'
```

Use the `iid` as the MR number for all subsequent API calls. Save the `web_url` to report to the user later.

If no MR is returned, wait 5 seconds and retry (GitLab may not have created it yet).

### 6. Verify auto-merge is armed

Wait 10 seconds after pushing to give GitLab time to create the pipeline, then verify MWPS:

```bash
sleep 10
glab api "projects/$GLAB_PROJECT/merge_requests/<MR_NUMBER>" | jq '{merge_when_pipeline_succeeds}'
```

If `merge_when_pipeline_succeeds` is `false`, this means the API token lacks write access. Do NOT attempt to arm it via the API. Instead, tell the user that MWPS could not be verified and they should confirm it is armed in the GitLab UI.

### 7. Monitor CI

First, get the pipeline ID:

```bash
PIPELINE_ID=$(glab api "projects/$GLAB_PROJECT/merge_requests/<MR_NUMBER>/pipelines" | jq -r '.[0].id')
```

Then run this poll **in the background** (`run_in_background: true`). It exits on the first failed job (within ~30s) rather than waiting for the pipeline-terminal state, and it uses **Python's `json.loads`** to parse `glab api` responses — `jq` rejects unescaped control characters that legitimately appear in some job string fields (URLs, log snippets) and silently hangs the loop forever. Python tolerates them.

**Crucially, on `MERGED` the script performs the worktree cleanup inline** (step 8b's shell), in the same background process, so no second inference step is needed to clean up. Cleanup is gated strictly on `mr.state == "merged"` — never on pipeline status alone — and it emits a `CLEANED <branch>` or `CLEANUP_FAILED <reason>` marker so the follow-up can report truthfully. The `CONFLICTS` / `FAILED_JOBS` / `PIPELINE_*` paths never touch the worktree.

Template in `BRANCH` (the branch being shipped) alongside the other placeholders:

```bash
python3 <<'PY' &
import json, os, subprocess, time
PROJ = '<URL_ENCODED_PROJECT_PATH>'   # e.g. arch%2Fcallandor
MR = <MR_NUMBER>
PIPE = <PIPELINE_ID>
BRANCH = '<BRANCH_NAME>'               # e.g. smcloughlin/my-feature

def gl(path):
    out = subprocess.run(['glab','api',f'projects/{PROJ}/{path}'], capture_output=True).stdout
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None

def all_jobs():
    # Paginate. 100 is the API's per-page maximum, not the pipeline's job count:
    # any MR touching rtl/ or dv/ runs well over 100 jobs, and a single page
    # silently reports failed=0 while a real failure sits on page 2.
    jobs, page = [], 1
    while page <= 20:
        chunk = gl(f'pipelines/{PIPE}/jobs?per_page=100&page={page}')
        if not chunk:
            break
        jobs += chunk
        if len(chunk) < 100:
            break
        page += 1
    return jobs

def cleanup():
    # Runs only after mr.state == "merged". All pure shell — no MCP/inference.
    main = subprocess.run(['git','worktree','list'], capture_output=True, text=True).stdout.splitlines()[0].split()[0]
    os.chdir(main)   # move our own CWD out of the worktree we're about to remove
    def sh(cmd):
        r = subprocess.run(cmd, capture_output=True, text=True)
        print(f'$ {" ".join(cmd)}\n{r.stdout}{r.stderr}', end='', flush=True)
        return r.returncode
    sh(['git','fetch','origin','main'])
    if sh(['wt','remove','-y','--force','--foreground',BRANCH]) != 0:
        print(f'CLEANUP_FAILED wt-remove {BRANCH}', flush=True); return
    if subprocess.run(['git','rev-parse','--verify','--quiet',BRANCH], capture_output=True).returncode == 0:
        sh(['git','branch','-D',BRANCH])
    sh(['git','checkout','main'])
    sh(['git','pull','--ff-only','origin','main'])
    print(f'CLEANED {BRANCH}', flush=True)

while True:
    mr = gl(f'merge_requests/{MR}') or {}
    pipe = gl(f'pipelines/{PIPE}') or {}
    jobs = all_jobs()
    failed = [j for j in jobs if j.get('status') == 'failed']
    ts = time.strftime('%H:%M:%S')
    print(f'=== {ts} === MR={mr.get("state")} pipeline={pipe.get("status")} '
          f'jobs={len(jobs)} failed_jobs={len(failed)}', flush=True)
    if mr.get("has_conflicts"):
        print("CONFLICTS"); break
    if mr.get("state") == "merged":
        print("MERGED", flush=True); cleanup(); break
    # Named failures before the pipeline verdict: the job list says which job
    # broke, where the pipeline status only says that something did.
    if failed:
        print("FAILED_JOBS:")
        for j in failed:
            print(f'  {j["name"]} (id={j["id"]})')
        break
    if pipe.get("status") in ("failed","canceled","skipped"):
        print(f'PIPELINE_{pipe["status"]}'); break
    time.sleep(30)
PY
wait
```

Exit conditions (whichever fires first):
- `CLEANED <branch>` → merged **and** worktree already removed by the script → go to step 8 (only the optional Jira comment + final report remain)
- `CLEANUP_FAILED <reason>` → merged, but the inline cleanup hit an error (e.g. the submodule `core.worktree` corruption gotcha) → go to step 8, do the cleanup manually per 8b, and surface the reason
- `MERGED` with neither marker following → the script died before finishing cleanup → treat as `CLEANUP_FAILED`
- `FAILED_JOBS:` → one or more jobs failed → go to step 9
- `PIPELINE_failed` / `PIPELINE_canceled` / `PIPELINE_skipped` → pipeline ended without a job-level failure being visible (rare) → go to step 9
- `CONFLICTS` → merge conflicts → stop monitoring, tell the user, do NOT attempt to fix automatically, do NOT remove the worktree

**Why paginate?** `per_page=100` is the API's maximum page size, not a count of the pipeline's jobs. A Callandor MR touching `rtl/`, `dv/`, or `tools/` runs well over 100 jobs (MR !2379 had 121), and the unpaginated call returned only the first page. The loop printed `failed_jobs=0` for ten minutes while `core-tb:vcs-single` sat failed on page 2, so a red pipeline read as healthy and the run looked stuck rather than broken. Always page until a short chunk comes back.

Note that retried jobs drop out of this endpoint by default (`include_retried` defaults to false), so after someone retries a failed job the list shows only the new attempt — which is what the loop wants.

**Why not jq?** Earlier versions of this skill piped `pipelines/<id>/jobs` through `jq` filters. `jq`'s input parser rejects unescaped control characters that legitimately appear inside job string fields (`web_url` query params, log snippets). When that happens, every `jq` invocation in the loop emits a parse error to stderr, the `$FAILED` / `$ALL_DONE` shell variables become empty, both `-gt 0` and `= "0"` checks fail, and the loop runs forever without ever exiting — no task notification, MR sits "done" while polling spins. Python's `json.loads` keeps control chars in strings as ordinary bytes and parses successfully.

### 8. On success: post Jira comment (if applicable) and confirm cleanup

On the `CLEANED` path the worktree, branch, and `main` pull are **already done** by the step-7 background script — do not repeat them. This step only handles the one thing shell can't (the Jira comment) and reports.

#### 8a. Post Jira comment

If the work being shipped is linked to a Jira ticket (e.g. the branch name or commit message references a ticket key such as `CAL-123`, or the user mentioned one earlier in the conversation), post a comment on that ticket containing **only** the MR URL — nothing else:

```
<MR_URL>
```

Use `mcp` with tool `jira_add_comment` (or `jira_jira_post` to `POST /rest/api/3/issue/<TICKET_KEY>/comment`) to add the comment.

> **Important:** Do NOT transition, resolve, or mark the ticket as Done. Do NOT change the ticket status in any way. Only post the comment. Only mark the ticket as Done if the user explicitly asks you to do so in that turn of the conversation.

If no Jira ticket is associated with this work, skip this step.

#### 8b. Remove worktree (wt-remove) — manual fallback

On a `CLEANED <branch>` marker this is already done; **skip it**. Run these steps only on a `CLEANUP_FAILED` marker (or if the background script died before cleaning up):

1. Change to the **main repo directory** (the primary worktree, not the one being removed):
   ```bash
   cd $(git worktree list | head -1 | awk '{print $1}')
   ```
2. Fetch origin/main:
   ```bash
   git fetch origin main
   ```
3. Remove the worktree:
   ```bash
   wt remove -y --force --foreground smcloughlin/<name>
   ```
4. Delete the local branch if it still exists. `wt remove` already deletes the branch when its tree is contained in `origin/main` (which includes squash-merged branches), so this is usually a no-op — guard it so it stays silent instead of printing `error: branch ... not found`:
   ```bash
   git rev-parse --verify --quiet smcloughlin/<name> >/dev/null && git branch -D smcloughlin/<name>
   ```
6. Pull the merged commit into the main clone's `main` branch:
   ```bash
   git checkout main
   git pull --ff-only origin main
   ```

#### 8c. Report

Report success to the user. Include the MR URL. If cleanup ran inline (`CLEANED`), say so; if you had to run the manual fallback, say what failed and that it's now resolved.

### 9. On failure: fix, push without auto-merge, and hand back

1. Check the failed job logs:
   ```bash
   glab api --paginate "projects/$GLAB_PROJECT/pipelines/<PIPELINE_ID>/jobs" | jq '.[] | select(.status == "failed") | {id, name, status}'
   glab api "projects/$GLAB_PROJECT/jobs/<JOB_ID>/trace" 2>&1 | tail -50
   ```
2. Fix the issue in the worktree.
3. **Amend** the last commit (do not create a new one):
   ```bash
   git add <changed files>
   git commit --amend --no-edit
   ```
   Amending keeps the branch as a single clean commit so that the squash
   setting is irrelevant and the history stays tidy regardless of how the
   MR is eventually merged.
4. Force-push, re-arming auto-merge via push option:
   ```bash
   git push --force-with-lease -o merge_request.merge_when_pipeline_succeeds
   ```
5. Do NOT remove the worktree.
6. Tell the user:
   - What failed and what you fixed.
   - That auto-merge has been re-armed and the MR will merge automatically if CI passes.
   - Provide the MR URL.
