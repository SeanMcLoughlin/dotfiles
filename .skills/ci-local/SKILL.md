---
name: ci-local
description: Run CI locally as a pre-flight check before committing or pushing.
allowed-tools:
- "Bash(git:*)"
- "Bash(gitlab-ci-local:*)"
- "Bash(vm:*)"
---

**Skip this entire skill if `.gitlab-ci.yml` does not exist at the repo root.**

**Determine the runner.** Check whether the `vm` command is available:

```bash
vm exec -h 2>&1 | head -1
```

If this produces any output, `gitlab-ci-local` must run inside the VM — use `vm exec gitlab-ci-local` as the command for all invocations. Otherwise use `gitlab-ci-local` directly.

**Find changed files** relative to `main`:

```bash
git diff --name-only $(git merge-base HEAD origin/main) HEAD
```

**Identify relevant CI jobs.** Read `.gitlab-ci.yml` and find all jobs whose `changes:` rules include paths that overlap with the changed files. Run only those jobs — do not run the entire pipeline.

**Run the jobs:**

```bash
<runner> --force-shell-executor --evaluate-rule-changes=false --job <job1> --job <job2> ...
```

Each relevant job requires its own `--job` flag. Globs are not supported.

**If any job fails**, fix the issue before proceeding. Do not commit or push broken code.
