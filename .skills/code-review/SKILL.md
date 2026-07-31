---
name: code-review
description: "Runs all code review personas against the current changelist. The personas find problems in parallel as read-only agents, the costly findings are then verified, and the fixes are applied in priority order: naming-critic, architect, bug-hunter, test-reviewer, doc-nitpicker, questioner, perf-reviewer, magic-numbers."
allowed-tools:
  - bash
  - Workflow
  - Read
  - Agent
---

## Purpose

Run every code review persona against the current changelist, and do it in
parallel where parallel is safe.

Finding problems is the expensive part of a review, and finding problems changes
no files. So all personas hunt at the same time, on the same commit, read-only.
Fixing is NOT safe in parallel, because the fixers share one worktree. So fixes
are applied afterwards, one persona at a time, in the order that matters.

This is a four phase run:

1. **Find**: every persona, on every shard of the diff, at once. No edits.
2. **Verify**: an independent agent tries to refute each costly finding.
3. **Apply**: one fixer per persona, serial, in priority order. Each fixer gets a
   verified list, so it never repeats the search.
4. **Report**: one combined report.

The `Workflow` tool does the orchestration. This skill is your authorisation to
call it.

### What this costs you

The earlier version of this skill ran eight find-and-fix agents back to back, and
each one re-read the whole diff up to five times. On a large diff that took
hours.

The trade is real and you should know it. The finders all see the same starting
commit, so they cannot see each other's fixes. A finding can therefore go stale:
the architect may move code that the naming critic has just renamed. Applying in
priority order limits this, and each fixer is told to skip findings that no
longer apply. The result is not identical to a fully serial review. It is close,
and it is much faster.

---

## Step 1 - Identify the branch

Use a branch already established in this conversation, or one given as an
argument. Otherwise read the current branch:

```bash
git branch --show-current
pwd
```

The comparison is always against `origin/main`. If you are on `main`, or the
branch to review is genuinely unclear, **ask the user before you continue**.

---

## Step 2 - Prepare the branch

```bash
git fetch origin
git rebase origin/main
```

**If the rebase fails**, run `git rebase --abort` at once, then stop with this
message:

> Rebase against origin/main failed. Resolve merge conflicts manually, then re-run /code-review.

Start no agents if the rebase failed.

Then confirm the tree is clean:

```bash
git status --porcelain
```

If uncommitted changes exist, stop and tell the user to commit or stash them.

---

## Step 3 - Scope the review

Get the changelist:

```bash
git diff origin/main...HEAD --stat
git diff origin/main...HEAD --name-only
git log origin/main..HEAD --oneline
```

**Exclude files no persona should review**: lock files, generated code, vendored
third-party trees, and binary or data files. Name what you excluded in the final
report, so a silent gap never looks like a clean result.

If nothing remains after exclusion, stop and say so.

**Choose the personas.** Run all eight by default. Drop one only when it clearly
has no work:

- Only prose and configuration changed, with no source code: run `doc-nitpicker`
  and `questioner` only.
- No source code and no test files changed: also drop `test-reviewer`.

Never drop a persona to save time on a diff it could genuinely review.

**Shard the diff.** Sharding is what makes a large diff fast, because each shard
is read by a separate agent at the same time.

- 20 files or fewer: one shard that holds every file.
- More than 20 files: `ceil(files / 12)` shards, capped at 6 shards.
- Keep files from the same directory in the same shard, so each agent sees a
  coherent module. Balance the shards roughly by file count.

---

## Step 4 - Run the workflow

Call the `Workflow` tool with the script beside this file, and pass the scope as
`args`:

```
scriptPath: ~/.skills/code-review/review-workflow.js
args: {
  "branch": "<branch>",
  "workdir": "<absolute path from Step 1>",
  "personas": ["naming-critic", "architect", "bug-hunter", "test-reviewer",
               "doc-nitpicker", "questioner", "perf-reviewer", "magic-numbers"],
  "shards": [["path/a.rs", "path/b.rs"], ["other/c.py"]]
}
```

Pass `shards` and `personas` as real JSON arrays, not as strings.

The workflow runs in the background. It returns a run identifier and a transcript
directory, and later the report data for Step 6.

**If the workflow fails part way through**, do not start again from the
beginning. Relaunch it with the same `scriptPath` and `resumeFromRunId: <runId>`.
Every agent that already finished returns its cached result at once, so only the
failed work runs again.

**If a result looks empty or wrong**, read `journal.jsonl` in the transcript
directory before you diagnose anything. It records what each agent actually
returned.

---

## Step 5 - Safety net

Each fixer commits its own work. Check whether they did:

```bash
git status --porcelain
```

Uncommitted changes here mean a fixer crashed or exited before it committed. Fall
back to:

```bash
git add -A
git commit -m "chore: code review (uncommitted changes, a fixer may have exited early)"
```

This message is deliberately generic and flagged, so you can investigate it. Do
not try to infer a better one, because the fixer should have written it.

Ignore untracked build artefacts such as `target/`, `__pycache__/` or
`.coverage`. Do not commit them.

---

## Step 6 - Print the combined report

Use the data the workflow returned. Keep the persona order it gives you.

```
# Code Review: <branch>

<n> files in <shardCount> shard(s), <finderCount> finders in parallel,
<totalFound> findings, <refuted.length> refuted

## 1. Naming Critic
<applied, skipped and flagged items, or "Clean">

---

## 2. Architect
...

(one section per persona, in the order returned)

---

## Refuted findings

Findings that a verifier disproved, with the reason. One line each. Say "None" if
the list is empty. This section is how the reader tells a quiet review from a
review that threw everything away.

---

## Summary

One line per persona: "Clean", or the number of fixes applied and findings
skipped.

Flag these first, because a human must look at them:
- Any persona that returned an `escalation`.
- Any persona whose fixer reported `committed: false`.
- `deadFinders` above zero. That many files went unreviewed.
- `unverifiedCount` above zero. That many low-severity findings bypassed
  verification because the cap was reached.
- The files you excluded in Step 3.
```

Report only what the workflow returned. Never present a persona as clean when its
finder died.
