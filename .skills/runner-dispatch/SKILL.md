---
name: runner-dispatch
description: Dispatch an on-demand CI job (or comma-list of jobs) on the Callandor GitLab runner via `glab ci run`, with arbitrary pipeline variables, from any branch, optionally after editing files first. Jobs that support it fan out to SLURM. Prints the exact env-expanded commands each job runs, and returns a link to the spawned pipeline plus a copy-paste live-trace command.
allowed-tools:
- "Bash(git:*)"
- "Bash(glab:*)"
- "Bash(wt:*)"
- "Bash(cat:*)"
- "Bash(test:*)"
- "Bash(python3:*)"
- "Bash(uv:*)"
- "Read"
- "Write"
- "Edit"
---

## Examples

> runner-dispatch: core-tb:tlist with `--sim vcs -t 512 -s 1 --coverage --simscope-tags ci --gen-test-config dv/test_gen/configs/gen-test/ci.jsonc --executor slurm`
> runner-dispatch: core-tb:verilator-compile on branch smcloughlin/foo
> runner-dispatch: core-tb:tlist, 512 seeds, but first empty dv/core/test_gen_configs/exclusions.json

## What this does

Triggers one or more **on-demand** CI jobs on the shared GitLab runner without opening an MR,
by creating an `api`-source pipeline gated on the `RUN_JOB` variable. Any job whose rules match
`$RUN_JOB` runs; every other job is `when: never`. Some jobs then fan out to **SLURM** (either
because you pass `--executor slurm` in the job's args, or because the job's own script wraps
itself in `srun` — e.g. `core-tb:verilator-compile`).

This is the generic dispatcher. It doesn't know about any specific job's arguments — you tell it
the job name(s) and the variables to pass.

## The mechanism (`RUN_JOB`)

`.gitlab-ci.yml` jobs meant for on-demand use are gated like:

```yaml
rules:
  - if: '$RUN_JOB =~ /(^|,)core-tb:tlist(,|$)/'
```

and every other job carries `- if: $CI_PIPELINE_SOURCE == "schedule" || $RUN_JOB` → `when: never`.
So setting `RUN_JOB` to a comma-separated list of job names runs **exactly** those jobs.

Known on-demand jobs (grep the repo for `$RUN_JOB =~` to find the current set):
- `core-tb:tlist` — runs `dv/core/tlist.py` with whatever you put in `TLIST_ARGS` (verbatim).
  Add `--executor slurm` to `TLIST_ARGS` for SLURM dispatch. **When using `--executor slurm`
  you MUST also set QoS**, or srun jobs land in the partition-default QOS and can sit in the
  queue indefinitely: `--build-qos boost` (high priority so the shared compile finishes fast)
  and `--sim-qos regr` (the per-test sims) — these mirror the nightly. Without a build QoS the
  compile may never leave the queue; without a sim QoS the sims dispatch slowly.
- `core-tb:verilator-compile` — heavy Verilator build; already SLURM-wrapped (`srun --qos=boost`)
  in its own script, no extra args needed.

Full docs: `docs/ci.md` → "Running a Job On Demand".

## Inputs

- **Job name(s)** — one name or a comma-list → the `RUN_JOB` value.
- **Pipeline variables** (optional) — e.g. `TLIST_ARGS:...`. Pass each as its own `--variables`.
- **Branch** (optional) — default the current branch. Must exist on origin.
- **File edits** (optional) — if the user wants to test a change, edit files on a throwaway
  branch first (step 2).

## Workflow

### 1. Token (required for `glab ci run`)

`glab ci run` needs an `api`-scoped token. The user's default PAT deliberately lacks `api` (they
are a GitLab Owner). Use the Developer-role **Project Access Token**, and prefix every
`glab ci run` with it:

```bash
test -r ~/.callandor_gitlab_pat.apitoken || { echo "token missing"; exit 1; }
```

`GITLAB_TOKEN=$(cat ~/.callandor_gitlab_pat.apitoken) glab ci run ...`

Read-only `glab api` polling works with the session token — it does not need this.

### 2. (Optional) throwaway branch for file edits

Only if the user wants to test uncommitted changes. Create a worktree off `main` so the main
clone stays clean, edit, and commit:

```bash
git worktree add -b smcloughlin/<slug> ~/repos/callandor.smcloughlin-<slug> main
# ...edit files in that worktree...
git -C ~/repos/callandor.smcloughlin-<slug> commit -am "test: <what changed>"
```

Otherwise skip this — dispatch against an existing branch as-is.

### 3. Push WITHOUT a stray pipeline

A bare push auto-creates a `push` pipeline that fires the branch's normal changes-gated jobs.
Suppress it with `ci.skip`; the real run comes from `glab ci run`:

```bash
git -C <branch-dir> push -o ci.skip -u origin smcloughlin/<slug>
```

If the branch is already on origin with no new commits, the push is a no-op (no pipeline) — skip
to step 4.

### 4. Dispatch

```bash
GITLAB_TOKEN=$(cat ~/.callandor_gitlab_pat.apitoken) glab ci run \
  -b <branch> \
  --variables RUN_JOB:<job1[,job2,...]> \
  [--variables 'VAR:value']...
```

Example (core-tb smoke-style, SLURM, 512 seeds):

```bash
GITLAB_TOKEN=$(cat ~/.callandor_gitlab_pat.apitoken) glab ci run \
  -b smcloughlin/<slug> \
  --variables RUN_JOB:core-tb:tlist \
  --variables 'TLIST_ARGS:--sim vcs -t 512 -s 1 --coverage --simscope-tags ci --gen-test-config dv/test_gen/configs/gen-test/ci.jsonc --executor slurm --build-qos boost --sim-qos regr'
```

### 5. Print the exact commands the job(s) will run (env-expanded)

Always show the user what each dispatched job actually runs, with variables like `$TLIST_ARGS`
substituted. The GitLab job trace only echoes the *un-expanded* script lines, so resolve it
yourself: the helper `show_job_cmds.py` (next to this SKILL.md) fetches the compiled CI config
(`glab ci config compile` — `extends`/`!reference`/`include` all resolved), merges each job's
`variables` with the pipeline's trigger variables (trigger wins), and expands them into the
resolved `before_script`/`script`/`after_script`. It is job-agnostic — it prints for every job
the pipeline actually scheduled.

```bash
GITLAB_TOKEN=$(cat ~/.callandor_gitlab_pat.apitoken) \
  uv run --with pyyaml python ~/.skills/runner-dispatch/show_job_cmds.py <pipeline-id>
```

(Needs the api-scoped token: `glab ci config compile` and the pipeline `variables` endpoint both
require `api`. `uv run --with pyyaml` supplies PyYAML, which isn't in the base env.) Shell
constructs like `case`/`if` are printed resolved but not evaluated — the user sees every branch,
including the one that matches. Paste this output for the user, and also give them the command so
they can re-run it themselves.

### 6. Report the pipeline link + a copy-paste monitor command

Resolve the newest non-skipped pipeline for the ref, confirm the scheduled jobs match what was
requested, and grab the job id (for the live-trace command):

```bash
PID=$(glab api "projects/arch%2Fcallandor/pipelines?ref=<branch>&per_page=5" \
  | python3 -c "import sys,json; print([x for x in json.load(sys.stdin) if x['status']!='skipped'][0]['id'])")
glab api "projects/arch%2Fcallandor/pipelines/$PID/jobs?per_page=100" \
  | python3 -c "import sys,json; [print(j['status'], j['name'], j['id']) for j in json.load(sys.stdin)]"
echo "https://aus-gitlab.local.tenstorrent.com/arch/callandor/-/pipelines/$PID"
```

**Always end your reply with BOTH of these, so the user can watch it live in their own
terminal:**

1. The pipeline web URL as a clickable link.
2. A ready-to-paste live-trace command with the real job id filled in:

   ```bash
   glab ci trace <job-id> -b <branch>
   ```

   (The job id changes if the pipeline retries; for a durable watch mention the TUI fallback
   `glab ci view <branch>`, which always resolves the current job.)

## Cleanup

Any throwaway branch/worktree is the user's to keep or drop. Offer to remove it once the run is
done (`git worktree remove <dir>` + `git push origin --delete <branch>`); don't delete without
asking.

## Related memory

- `reference_on_demand_tlist_ci.md` — the `RUN_JOB` mechanism, MR-pipeline merge-gate safety,
  and the Project Access Token path.
