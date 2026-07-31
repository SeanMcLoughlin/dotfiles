---
name: rewrite-history
description: Squash related commits and rewrite messages to be legible and user-focused, ready for MR review.
allowed-tools:
- "Bash(git log:*)"
- "Bash(git show:*)"
- "Bash(git rebase:*)"
- "Bash(git commit:*)"
- "Bash(awk:*)"
- "Bash(prettier:*)"
---

Clean up the commits on the current branch so they are ready for MR
review: squash related commits together, then rewrite each message to be
clear and readable to someone who doesn't know the code.

## Pitfalls to avoid

- **Don't over-squash by default.** A branch usually has multiple
  reviewable steps. Squashing everything into one commit is wrong
  unless the user explicitly asks for it (e.g. "squash everything into
  one commit").
- **Touching the same file is not a reason to squash.** Two commits
  that modify the same area may be doing unrelated things (e.g. a
  formatting cleanup and a behaviour change).
- **Don't squash intentionally-separate commits.** A refactor kept
  separate from the feature that uses it, or infrastructure split from
  the thing built on top of it, may have been separated deliberately
  to make review easier. Be conservative: if the intent is unclear,
  keep them separate.
- **Don't over-sanitise messages.** Removing jargon shouldn't remove
  meaning. A vague message is worse than a technical one.
- **If a rebase conflict occurs, abort and report it** rather than
  attempting to resolve it silently. Run `git rebase --abort` and tell
  the user what happened.

Default to keeping commits separate when their relationship is ambiguous.

## Step 1 — Plan the new commit structure

List the commits on the branch:

```bash
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

Read each diff to understand what it does:

```bash
git show <sha>
```

Group commits by feature or logical change. Commits that fix up,
refine, or are otherwise inseparable from an earlier commit in the
branch should be squashed into it. Each resulting commit should
represent one coherent, self-contained change.

## Step 2 — Rewrite in a single interactive rebase

Do the squashing and message rewrites in one `git rebase -i` pass.
Because the terminal editor won't open, drive it with
`GIT_SEQUENCE_EDITOR`:

```bash
GIT_SEQUENCE_EDITOR="sed -i '' '...'" git rebase -i $(git merge-base HEAD origin/main)
```

Use `squash` or `fixup` for commits being merged into the one above
them, and `reword` for commits whose message needs changing. When
rebase pauses on a `reword`, amend using a prepared file:

```bash
git commit --amend -F /tmp/commit-msg.txt
git rebase --continue
```

## Step 3 — Write each message

For each resulting commit, write a message that describes **what
changed and why** at a behavioural or user-visible level. Avoid
implementation jargon: internal type names, method signatures, trait
names, and similar details should not appear unless there is no better
way to express the change.

Good: "Address Sequence view now tracks the memory region across regenerations"
Bad: "Add `generation_count` to `AppState` and call `PlotMemory::reset()`"

Use backticks only for things that are genuinely user-facing
identifiers (CLI flags, config keys, file names), not for internal
code symbols.

Follow the 50/72 rule (subject ≤ 50 chars, body wrapped at 72).
Write each message to `/tmp/commit-msg.txt` using the `write` tool,
then check and reflow before amending:

```bash
awk 'NR==1{print length, $0}' /tmp/commit-msg.txt
prettier --parser markdown --prose-wrap always --print-width 72 --write /tmp/commit-msg.txt
```

Delete the temp file when done.
