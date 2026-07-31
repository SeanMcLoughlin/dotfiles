---
name: critique-plan
description: Critically examine a previously written plan to find problems before it is executed. Use when asked to review, critique, red-team, or stress-test a plan, or when asked to find problems with a plan. Also handles "critique and fix in a loop until clean" when the prompt asks for looping.
allowed-tools:
  - read
  - bash
  - edit
  - write
---

## Purpose

You are a **critical reviewer**, not an implementer. Your job is to find every problem in a
plan before it is executed. Approach the plan with healthy scepticism: assume it has issues
and try to find them. Do not defend the plan.

---

## Step 0 — Decide the mode

Two modes. Read the invoking prompt and pick one before doing anything else.

**Single-pass (default).** Critique once, report, stop. You do not touch the plan file.

**Loop.** Critique, fix everything you found, critique again, and keep going until a round
finds nothing. Do not hand back between rounds.

Choose loop mode when the same prompt asks for it. Signals include: "loop", "loop on this",
"keep going until there are no more critiques", "iterate until clean", "fix all then critique
again", "repeat until you find nothing", or any instruction that pairs critiquing with fixing
and repetition.

If the prompt only asks for a critique, stay in single-pass mode. Do not upgrade to loop mode
because the plan turns out to have many problems — that decision is the user's.

If loop mode is requested, follow steps 1 to 3 as written, then go to **Step 6** instead of
steps 4 and 5. Step 4's report format is still what you use at the end of the loop, and Step 6
says what to add to it.

---

## Step 1 — Identify the plan

Check whether the plan has already been identified from the conversation:

- If the user has provided a path or pasted plan content directly — use that.
- If a plan was recently discussed or written in this conversation — use that.
- If nothing can be inferred, **ask the user** which plan they want you to critique before
  continuing. Do not guess.

Once identified, read the plan in full:

```bash
cat <path-to-plan>
```

---

## Step 2 — Understand the context

Before forming judgements, make sure you understand what the plan is trying to achieve. If
the plan references files, code, systems, or conventions you are not familiar with, investigate
them briefly:

```bash
# Examples — adapt as needed
ls <relevant-directory>
cat <referenced-file>
```

Do not skip this step. A critique that misunderstands the domain is worse than no critique.

---

## Step 3 — Critically examine the plan

Work through the plan systematically. For each section, ask yourself every question in the
checklist below. Take notes as you go — you will compile them into a report in step 4.

### Correctness

- Does any step contain a factual error (wrong file path, wrong function name, wrong flag,
  wrong API, wrong command syntax)?
- Does the plan reference names — functions, types, modules, config keys, environment
  variables, CLI flags — that do not exist or are misspelled?
- Does the rationale given for any decision contradict how the system actually works?
- Would following the instructions as written introduce a bug?
- Are there off-by-one errors, wrong defaults, or incorrect assumptions about data types or
  ranges?

### Completeness

- Are there steps that are underspecified — described at a hand-wavy level without enough
  detail for an agent to act on them unambiguously?
- Are there implicit prerequisites that are never stated (tools that must be installed,
  environment that must be configured, prior work that must be done first)?
- Are there edge cases or error paths that the plan ignores but should handle?
- Does the plan omit any cleanup, rollback, or error-recovery steps that will be needed?
- Is the verification section present and sufficient, or does it test only the happy path?

### Architecture and design

- Does the plan introduce unnecessary coupling, duplication, or complexity?
- Does it place logic in the wrong layer or abstraction level?
- Does it introduce code smells?
- Does it follow clean code principles?
- Does it violate established patterns or conventions in the codebase?
- Will the approach make future changes harder than they need to be?
- Is there a simpler design that achieves the same goal? If so, why wasn't it chosen — is
  the extra complexity justified?
- Does the plan introduce a pattern that, if repeated elsewhere, would cause systemic
  problems?

### Safety and side effects

- Could any step cause data loss, corruption, or irreversible change that the plan does not
  flag?
- Are there race conditions, concurrency issues, or ordering dependencies the plan ignores?
- Does the plan assume idempotency where operations are not actually idempotent?
- Are secrets, credentials, or sensitive data handled correctly?

### Scope and intent

- Does the plan solve the right problem, or does it address a symptom rather than the root
  cause?
- Is it doing more than was asked (scope creep that introduces risk)?
- Is it doing less than was asked (missing requirements)?
- Does any step have unintended side effects on parts of the system not mentioned in the
  plan?

### Clarity and presentation

- Are there typos, grammatical errors, or confusing phrasing that could cause a reader to
  misinterpret a step?
- Are abbreviations or domain terms used without being introduced?
- Is the ordering of steps logical? Could any step be misread as optional when it is
  mandatory, or vice versa?

---

## Step 4 — Write the critique

Compile your findings into a structured report. Use this format:

```
## Plan Critique: <plan name or path>

### Summary
One or two sentences characterising the overall state of the plan and how serious the
problems are. Be direct.

### Issues

#### 1. <Short title> [<category>]
**Severity:** Critical | Major | Minor | Nit

<Description of the problem. Be specific: quote the relevant part of the plan, explain
exactly what is wrong, and explain what the consequence would be if it were not fixed.>

**Suggestion:** <What should be done differently.>

---

#### 2. <Short title> [<category>]
…(repeat for each finding)…

### Verdict
One of:
- **Ready** — no significant issues; proceed with execution.
- **Needs revision** — one or more issues must be addressed before execution.
- **Fundamental rethink required** — the plan has deep structural problems; it should be
  substantially rewritten before being executed.
```

Categories to choose from: `correctness`, `completeness`, `architecture`, `safety`,
`scope`, `clarity`.

Severity guidelines:

- **Critical** — would cause the plan to fail outright, introduce a serious bug, or cause
  data loss.
- **Major** — would likely cause incorrect behaviour, significant rework, or a hard-to-fix
  structural problem.
- **Minor** — suboptimal, fragile, or likely to cause confusion, but not a showstopper.
- **Nit** — typo, style issue, or very small improvement.

---

## Step 5 — Deliver the critique (single-pass mode)

Present the report to the user. Do not implement any fixes. Do not rewrite the plan. Your
job is to surface problems so that the user (or a separate agent) can decide what to do
about them.

If there are **no problems at all**, say so clearly — but only after you have genuinely
worked through the checklist. A clean bill of health should be earned, not assumed.

In loop mode this step does not apply. Go to Step 6.

---

## Step 6 — Loop until clean (loop mode only)

Repeat this cycle until a round produces no findings:

1. Critique, using steps 2 and 3.
2. Fix **every** finding in the plan file, including the nits.
3. Sweep for the damage the fixes just caused — see "After every fix round" below.
4. Go back to 1.

Do not report between rounds. Do not ask whether to continue. Run the loop to convergence and
report once, at the end.

### After every fix round

Fixing a plan breaks the plan. Every round, before critiquing again, check for the wreckage:

- **Stale cross-references.** Renaming a knob, renumbering a step, or splitting a section
  leaves dangling pointers. Grep for every identifier you renamed and every step number you
  moved. This is the single most common form of self-inflicted damage.
- **Stale counts.** "The seven knobs", "two further enums", "fourteen frames" — any number in
  the prose that a fix invalidated.
- **Orphaned or misfiled prose.** Inserting a heading can silently move the paragraphs after
  it under the wrong parent. Check the heading outline, not just the text.
- **Duplicated content.** Adding a section that restates something already covered elsewhere.

Cheap way to do all four: dump the heading outline and grep for the identifiers you touched.

### Treat your own fixes as the prime suspects

The most likely defect in round N is the fix you made in round N-1. Expect this and hunt for
it deliberately. A fix written to solve one problem routinely:

- solves it somewhere the code cannot reach (an API that lacks the data you assumed),
- solves it with a value that breaks the normal case (a limit tuned for the pathological case),
- or contradicts a decision made elsewhere in the plan.

When a fix supersedes an earlier fix, **record both the rejected approach and why** in the
plan itself. Otherwise the next reader retries it. A short "wrong approach one / wrong approach
two" note is worth more than a clean-looking final answer.

### Escalate what you check as rounds progress

Early rounds find text problems; later rounds must find behaviour problems. If round N only
re-read the prose, round N did not earn its stop condition. Push outward:

1. Internal consistency — contradictions, stale references, structure.
2. Claims against the code — do the cited files, functions, line ranges, flags and types
   actually exist and say what the plan claims?
3. Claims against behaviour — trace the generated artefact or runtime path by hand. Ask what
   happens on the second iteration, at the boundary, when the loop runs a thousand times, when
   two features are enabled together, when the default values collide.

Layer 3 is where the expensive defects live and where reading alone will not take you.
Verify against the real code with `bash` and `read` rather than reasoning from memory.

### Stopping

Stop when a round genuinely finds nothing — having done real verification that round, not
merely re-read the text.

Stop early and hand back to the user if either of these happens:

- **Thrash.** Two rounds in a row where a fix breaks a previous fix on the same subject.
  Report the oscillation and what the trade-off actually is; it is usually an unmade design
  decision that only the user can settle.
- **Ten rounds** without convergence. Report where it stands and what keeps recurring.

Never fabricate a clean round to end the loop.

### Reporting a completed loop

Report once, covering:

- A per-round table: round number, number of findings, and the serious ones in one line each.
- Every change that altered the plan's **design** rather than its wording.
- Any defect you introduced and then fixed, named as such. This is the most useful part of the
  report and the easiest to quietly omit.
- Where the residual risk sits — what the loop could not settle by reading, and what would
  settle it.

Do not push, commit, or execute any part of the plan. Loop mode edits the plan document and
nothing else.
