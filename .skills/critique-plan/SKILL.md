---
name: critique-plan
description: Critically examine a previously written plan to find problems before it is executed. Use when asked to review, critique, red-team, or stress-test a plan, or when asked to find problems with a plan. Also handles "critique and fix in a loop until clean" when the prompt asks for looping.
allowed-tools:
  - bash
  - Read
  - Edit
  - Write
  - Agent
---

## Purpose

Find every problem in a plan before it is executed.

You do not critique the plan yourself. You dispatch a set of fresh critic agents, you fix what
they find, and you dispatch a fresh set again. This is the whole point of the skill, so do not
shortcut it.

An agent that has already worked on a plan is the worst judge of whether the plan is finished.
It remembers the effort it spent, so it drifts towards "good enough" after a few rounds instead
of stopping when the plan is actually clean. A critic with a fresh context cannot do that. It
cannot remember any earlier round, and it is never told which round it is on, so it has no way
to decide that enough rounds have happened.

Your job is orchestration and repair, not judgement about whether the plan deserves more
scrutiny. The critics decide that.

---

## Step 0 — Decide the mode

Two modes. Read the invoking prompt and pick one before doing anything else.

**Single-pass (default).** Dispatch one set of critics, report, stop. You do not touch the plan
file.

**Loop.** Dispatch critics, fix everything they found, dispatch a fresh set, and keep going
until a round finds nothing. Do not hand back between rounds.

Choose loop mode when the same prompt asks for it. Signals include: "loop", "loop on this",
"keep going until there are no more critiques", "iterate until clean", "fix all then critique
again", "repeat until you find nothing", or any instruction that pairs critiquing with fixing
and repetition.

If the prompt only asks for a critique, stay in single-pass mode. Do not upgrade to loop mode
because the plan turns out to have many problems. That decision is the user's.

---

## Step 1 — Identify the plan

Check whether the plan has already been identified from the conversation:

- If the user has provided a path or pasted plan content directly, use that.
- If a plan was recently discussed or written in this conversation, use that.
- If nothing can be inferred, **ask the user** which plan they want you to critique before
  continuing. Do not guess.

Read the plan in full yourself. You need it to write the brief in Step 2 and to apply fixes
later.

---

## Step 2 — Set up the two areas

The loop needs two areas, and they must stay apart.

- The **history area** holds a git mirror of the plan, one commit per round. It persists between
  runs. Only you read it.
- The **review area** holds the plain copy the critics read. It lives in the scratchpad, so it
  belongs to this session alone.

Every command below is written with literal paths, and uses no shell variables. Which interpreter
runs a tool command depends on the harness, and it is not always the login shell. Literal paths
work in all of them. Substitute the paths yourself as you go.

Two names to substitute:

- `<slug>` is the plan's file name without the extension.
- `<scratch>` is your scratchpad directory.

### The history area: one repository for each plan

```bash
mkdir -p ~/plans/.critique/<slug>
git -C ~/plans/.critique/<slug> rev-parse --git-dir || git -C ~/plans/.critique/<slug> init -q
```

**One repository for each plan, never one repository for all plans.** Several agents critique
several plans at the same time, and git serialises nothing across processes. A shared repository
would give you index lock failures, commits landing in another plan's history, and a thrash check
reading another plan's diffs. A directory for each plan removes the shared state instead of
trying to coordinate access to it.

Key the directory on the plan's file name, not on its full path, and write the plan's real path
into a `SOURCE` file so the history stays readable.

**Two agents on the same plan still share one repository.** Take a lock with `mkdir`, which fails
when the directory exists and is atomic in every shell:

```bash
mkdir ~/plans/.critique/<slug>/lock
```

If that fails, the history area is in use. Tell the user, keep the mirror in your scratchpad for
this run instead of in `~/plans`, and say in the final report that this run's history was not
retained. Never write to a locked history area. Remove the lock when the loop ends, including
when it ends early.

### Mark where this run starts

The history holds earlier runs, so record the starting point:

```bash
cp <path-to-plan> ~/plans/.critique/<slug>/plan.md
git -C ~/plans/.critique/<slug> add plan.md SOURCE
git -C ~/plans/.critique/<slug> commit -q --allow-empty -m "run start: plan as written"
git -C ~/plans/.critique/<slug> rev-parse HEAD
```

`--allow-empty` is needed because a second run on an unchanged plan has nothing to commit, and
the marker must exist anyway.

Keep that SHA in your own notes and use it literally in the thrash check. Every later `git`
command reads only from that SHA forward. Otherwise the thrash check reads an argument that an
earlier run already settled, and reports a reversal that never happened in this run.

### The review area

```bash
mkdir -p <scratch>/critique-plan/<slug>/review
```

That directory must have no `.git` directory in it or above it. Keep it in the scratchpad, and
never inside `~/plans/.critique/`.

Do not point the critics at the plan where it lives. A plan inside a project repository carries
its own history, and a critic has `bash`. An instruction not to read the history is weaker than
a directory that holds no history to read.

### The brief

Write `<scratch>/critique-plan/<slug>/review/BRIEF.md` once, and never change it. It holds:

- The goal the plan is meant to achieve, in the user's own terms.
- The constraints the user stated.
- The repository or directory the plan applies to, as an absolute path.

The critics need this because a critic with no conversation context cannot judge scope. It
cannot tell that the plan does more than the user asked, or less, unless you tell it what was
asked.

The brief must be identical in every round. It must contain no round number, no earlier
critique, no list of what previous rounds fixed, and no changelog. Any of those tell a critic
how much work has already happened, which is the bias this design removes.

---

## Step 3 — Dispatch a round of critics

Refresh the copy the critics read, then dispatch all five critics in one message so they run at
the same time:

```bash
cp <path-to-plan> <scratch>/critique-plan/<slug>/review/plan.md
```

Five critics, each with its own part of the checklist. Split the work so that no critic has to
choose which category to spend its attention on.

1. **Correctness.** Factual errors. Wrong file paths, function names, flags, APIs, command
   syntax. Names that do not exist or are misspelled. Rationale that contradicts how the system
   works. Instructions that would introduce a bug as written. Off-by-one errors, wrong defaults,
   wrong assumptions about types or ranges. This critic must check every claim against the real
   code.
2. **Completeness.** Steps too vague to act on. Unstated prerequisites, such as tools that must
   be installed or prior work that must be done first. Edge cases and error paths the plan
   ignores. Missing cleanup, rollback, or recovery steps. Whether the verification section
   exists and tests more than the happy path.
3. **Design and scope.** Unnecessary coupling, duplication, or complexity. Logic in the wrong
   layer. Code smells. Violations of the conventions already in the codebase. Whether a simpler
   design reaches the same goal, and whether the extra complexity is justified. Whether the plan
   solves the root cause or a symptom. Whether it does more or less than the brief asked. A
   pattern that would cause systemic problems if repeated.
4. **Behaviour and safety.** Data loss, corruption, or irreversible change the plan does not
   flag. Race conditions, concurrency problems, ordering dependencies. Assumed idempotency where
   the operation is not idempotent. Handling of secrets and sensitive data. This critic must
   trace the runtime path or the generated artefact by hand, and ask what happens on the second
   iteration, at the boundary, when the loop runs a thousand times, when two features are
   enabled together, and when default values collide.
5. **Clarity.** Typos, grammar, and phrasing that a reader could misread. Abbreviations and
   domain terms used before they are introduced. Step ordering. Steps that read as optional but
   are mandatory, or the reverse.

### What every critic is told

Give each critic the same frame, and change only its category:

- Give the absolute path of the plan copy and of the brief. Both are in the review area. Give no
  other path in `~/plans` and no path under `~/plans/.critique/`.
- Assume the plan has problems, and try to find them. Do not defend it.
- Your category is `<category>`. Report anything serious you notice outside it, but spend your
  effort inside it.
- Understand the domain before you judge it. A critique that misreads the domain is worse than
  no critique. Read the referenced files.
- Verify claims against the real code with `bash` and `read`. Do not reason from memory.
- Report every finding, including small ones. Do not filter by how much work a fix would be.
- You are read-only. Do not edit the plan.
- Report nothing about how finished or polished the plan seems. Report only findings.

Never tell a critic which round it is on, that earlier rounds happened, or that anything was
already fixed. If a critic asks, do not answer it. Dispatch a new one.

### What every critic returns

```
#### <Short title> [<category>]
**Severity:** Critical | Major | Minor | Nit
**Evidence:** <the exact text from the plan that is wrong>

<What is wrong, and what the consequence is if it is not fixed.>

**Suggestion:** <What should be done differently.>
```

Categories: `correctness`, `completeness`, `architecture`, `safety`, `scope`, `clarity`.

Severity:

- **Critical** — would cause the plan to fail outright, introduce a serious bug, or cause data
  loss.
- **Major** — would likely cause incorrect behaviour, significant rework, or a hard-to-fix
  structural problem.
- **Minor** — suboptimal, fragile, or likely to cause confusion, but not a showstopper.
- **Nit** — typo, style issue, or very small improvement.

A critic that finds nothing says so, and says which checks it ran to earn that.

---

## Step 4 — Deliver the critique (single-pass mode)

Merge the five reports. Drop exact duplicates, keep near-duplicates that make different points,
and order by severity. Present it as:

```
## Plan Critique: <plan name or path>

### Summary
One or two sentences on the overall state of the plan and how serious the problems are. Be
direct.

### Issues
<the merged findings, numbered>

### Verdict
One of:
- **Ready** — no significant issues; proceed with execution.
- **Needs revision** — one or more issues must be addressed before execution.
- **Fundamental rethink required** — the plan has deep structural problems; it should be
  substantially rewritten before being executed.
```

Do not implement any fixes. Do not rewrite the plan. Your job is to surface problems so that the
user, or a separate agent, can decide what to do about them.

Do not soften a finding because you disagree with it. Report it and say you disagree.

---

## Step 5 — Loop until clean (loop mode only)

Each round is:

1. Dispatch a fresh set of five critics, as in Step 3.
2. Fix **every** finding in the plan file, including the nits.
3. Sweep for the damage the fixes just caused. See "After every fix round".
4. Commit the round.
5. Check for thrash. See "Stopping for thrash".
6. Go back to 1.

Do not report between rounds. Do not ask whether to continue. Run the loop to convergence and
report once, at the end.

**All findings are in scope.** A round is clean only when all five critics return nothing. Nits
count. Do not stop because only nits remain.

Commit after the fixes of each round:

```bash
cp <path-to-plan> ~/plans/.critique/<slug>/plan.md
git -C ~/plans/.critique/<slug> commit -qam "round <n>: <count> findings — <short subjects>"
```

One commit per round keeps each diff small, which is what makes the thrash check cheap.

### After every fix round

Fixing a plan breaks the plan. Every round, before you dispatch again, check for the wreckage:

- **Stale cross-references.** Renaming a knob, renumbering a step, or splitting a section leaves
  dangling pointers. Grep for every identifier you renamed and every step number you moved. This
  is the most common form of self-inflicted damage.
- **Stale counts.** "The seven knobs", "two further enums", "fourteen frames". Any number in the
  prose that a fix invalidated.
- **Orphaned or misfiled prose.** Inserting a heading can silently move the paragraphs after it
  under the wrong parent. Check the heading outline, not just the text.
- **Duplicated content.** A new section that restates something already covered elsewhere.

Cheap way to do all four: dump the heading outline, and grep for the identifiers you touched.

### Record rejected approaches in the plan

The plan must hold a section named "Rejected approaches, and why". Add it if it is missing. When
a fix supersedes an earlier fix, record the rejected approach and the reason there.

This section is load-bearing in this design. Each round's critics are new, so they know only
what the plan tells them. If the plan does not say why an approach was refused, a later critic
will propose it again, and the loop will fight itself. A short "wrong approach one, wrong
approach two" note is worth more than a clean-looking final answer.

### Repeat findings

A fresh critic that raises a subject an earlier round already settled is giving you real
information, not noise. It has no memory to be tired, so treat the repeat as evidence that the
plan does not justify its own decision.

You may dismiss a repeat finding only when both hold:

- The plan already records the decision and the reason, in the rejected-approaches section.
- The critic adds no argument the record does not already answer.

List every dismissal in the final report, with the reason. A dismissal you do not report is
indistinguishable from a finding you hid.

### Treat your own fixes as the prime suspects

The most likely defect in round N is the fix you made in round N-1. A fix written to solve one
problem routinely:

- solves it somewhere the code cannot reach, such as an API that lacks the data you assumed,
- solves it with a value that breaks the normal case, such as a limit tuned for the pathological
  case,
- or contradicts a decision made elsewhere in the plan.

### Stopping for thrash

Two rounds that fight over the same decision mean the loop cannot settle it. That is usually an
unmade design decision that only the user can make, so hand it back.

Read this run's per-round diffs and judge whether a change undoes an earlier one. Read from
the run-start SHA only, never the whole history, because earlier runs settled their own arguments:

```bash
git -C ~/plans/.critique/<slug> log --oneline <run-start-sha>..HEAD
git -C ~/plans/.critique/<slug> log -p --unified=3 <run-start-sha>..HEAD
```

Judge this by meaning, not by text. A change that returns to an earlier decision in new wording
is still a reversal. A value that moves 8, then 64, then 128 is not a reversal. It is a plan
converging, and the loop continues.

**You may end the loop for thrash only if you quote both diff hunks:** the hunk that made the
change, and the later hunk that undoes it, with the round of each named. If you cannot produce
both hunks, the loop continues.

This rule exists because ending for thrash is an easy way out, and you are the party with a
reason to take it. Evidence the user can check in a few seconds is the guard.

### Stopping

Stop when a round genuinely finds nothing, with all five critics reporting nothing.

Stop early and hand back if either of these happens:

- **Thrash**, proven with both hunks as above. Report the oscillation and what the trade-off
  actually is.
- **25 rounds** without convergence. Report where it stands and what keeps recurring.

Never fabricate a clean round to end the loop. Never drop a critic to make a round clean.

### Reporting a completed loop

Report once, covering:

- A per-round table: round number, findings per critic, and the serious ones in one line each.
- Every change that altered the plan's **design** rather than its wording.
- Any defect you introduced and then fixed, named as such. This is the most useful part of the
  report and the easiest to quietly omit.
- Every repeat finding you dismissed, and why.
- Where the residual risk sits. What the loop could not settle by reading, and what would settle
  it.

Then release the lock:

```bash
rmdir ~/plans/.critique/<slug>/lock
```

Do not push, commit to a project repository, or execute any part of the plan. Loop mode edits
the plan document, and commits only to that plan's own history area under `~/plans/.critique/`.
