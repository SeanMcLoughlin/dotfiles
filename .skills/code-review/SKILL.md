---
name: code-review
description: "Runs all code review personas sequentially as fresh sub-agents against the current changelist. Order: naming-critic → architect → bug-hunter → test-reviewer → doc-nitpicker → questioner → perf-reviewer → magic-numbers."
allowed-tools:
  - bash
  - Agent
---

## Purpose

Run all code review personas against the current changelist in the correct order. Each persona runs as a fresh Opus sub-agent with its own context. Because each persona may modify code, they run sequentially — each one sees the committed output of the previous.

---

## Step 1 — Identify the branch

Check whether a branch has been established from earlier in this conversation or provided as an argument. Otherwise, read the current git branch:

```bash
git branch --show-current
```

The comparison is always against `origin/main`. If you are already on `main`, or it is genuinely unclear which branch to review, **ask the user before continuing**.

Note the working directory:

```bash
pwd
```

---

## Step 2 — Prepare the branch

Fetch and rebase:

```bash
git fetch origin
git rebase origin/main
```

**If the rebase fails**, run `git rebase --abort` immediately, then halt with this message:

> Rebase against origin/main failed. Resolve merge conflicts manually, then re-run /code-review.

Do not spawn any sub-agents if the rebase failed.

Also verify the working tree is clean before starting:

```bash
git status --porcelain
```

If there are uncommitted changes, halt and tell the user to commit or stash them before running the review.

---

## Step 3 — Run each persona as a sequential sub-agent

For each persona below, spawn a sub-agent using the Agent tool with model `opus`. **Wait for each agent to complete before proceeding.**

After each agent completes, **before spawning the next one**, run a safety-net check:

```bash
git status --porcelain
```

Each fixer skill is responsible for committing its own changes with a meaningful message. If `git status` shows uncommitted changes after a skill finishes, that means the skill crashed or failed to commit — treat this as a fallback:

```bash
git add -A
git commit -m "chore: <persona-name> review (uncommitted changes — skill may have exited early)"
```

This fallback message is intentionally generic and flagged so you can investigate. Do not try to infer a better message here — the skill should have done that itself.

If the agent left untracked files that look like build artifacts (e.g., `target/`, `__pycache__/`, `.coverage`), ignore them — do not commit them.

Collect the final report text from each agent's response. You will assemble them in Step 4.

---

### Persona prompts

Substitute `<branch>` and `<workdir>` with the values from Steps 1 and 2.

---

#### 1. naming-critic

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/naming-critic/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
When you are finished, commit any changes you made before exiting.
```

---

#### 2. architect

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/architect/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
When you are finished, commit any changes you made before exiting.
```

---

#### 3. bug-hunter

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/bug-hunter/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
```

---

#### 4. test-reviewer

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/test-reviewer/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
When you are finished, commit any changes you made before exiting.
```

---

#### 5. doc-nitpicker

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/doc-nitpicker/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
When you are finished, commit any changes you made before exiting.
```

---

#### 6. questioner

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/questioner/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
```

---

#### 7. perf-reviewer

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/perf-reviewer/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
```

---

#### 8. magic-numbers

```
You are doing a code review on branch <branch> in the repository at <workdir>.
cd to <workdir> before doing anything.
Read the file ~/.skills/magic-numbers/SKILL.md and follow those instructions exactly.
The branch has already been fetched and rebased against origin/main — skip the fetch/rebase step.
When you are finished, commit any changes you made before exiting.
```

---

## Step 4 — Print the combined report

After all seven agents have completed, print each report in order:

```
# Code Review: <branch>

## 1. Naming Critic
<report from naming-critic agent>

---

## 2. Architect
<report from architect agent>

---

## 3. Bug Hunter
<report from bug-hunter agent>

---

## 4. Test Reviewer
<report from test-reviewer agent>

---

## 5. Doc Nitpicker
<report from doc-nitpicker agent>

---

## 6. Questioner
<report from questioner agent>

---

## 7. Performance Reviewer
<report from perf-reviewer agent>

---

## 8. Magic Numbers
<report from magic-numbers agent>

---

## Summary

For each persona, one line: either "Clean" or a count of findings/fixes.
Flag any persona that escalated (cycle detected, iteration cap hit, test runner not found) so the human knows to look at it first.
```
