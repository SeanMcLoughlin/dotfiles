---
name: new-plan
description: Write a detailed implementation plan to ~/plans for a fresh agent to execute later.
allowed-tools:
  - read
  - write
  - edit
  - bash
---

## Purpose

Write a detailed, self-contained implementation plan and save it to `~/plans`. You are the
**plan author**, not the plan executor — do not implement anything described in the plan.

---

## Audience

Every plan is written for a **fresh agent with no prior context**: an agent who has never seen
this codebase, this conversation, or any background that led to the plan. Write as if handing
the document to a stranger. Define every abbreviation, explain why things are being done, and
never assume the reader has the context you have. If a term or system needs explanation,
provide it inline or in a "Background" section at the top.

---

## Workflow

### 1. Choose a location

Plans live under `~/plans`. That directory contains subdirectories organised by work area
(e.g. `adrenaline/`, `ttrun/`, `ttsim/`). Inspect the directory to choose the best
subdirectory. Choose a descriptive kebab-case filename (e.g. `address-generation.md`).

If a plan does not have a relevant subdirectory, just place it under `~/plans`.

```bash
ls ~/plans/
```

If the user has specified an exact path, use that path exactly and skip this step.

### 2. Survey the context directory

Look at the files available in `~/context/` to find any that are relevant to the types of
files being modified or created by this plan:

```bash
ls ~/context/
```

Read every relevant context file in full. These files define the **acceptance criteria and
verification commands** that the executing agent must satisfy. You will embed them verbatim
(or by direct reference) in the plan's "Verification" section.

### 3. Write the plan

A good plan includes, at minimum:

- **Overview** — what is being built or changed, and why.
- **Background** (if needed) — any concepts, subsystems, or terminology a fresh agent needs
  to understand before reading the rest of the document.
- **Scope** — what is in scope and, where useful, what is explicitly out of scope.
- **Step-by-step implementation** — ordered, unambiguous instructions. Each step should be
  concrete enough that the agent can act on it without making assumptions.
- **Verification** — see §4 below.

### 4. Verification section (mandatory for code plans)

Every plan that involves writing or modifying code **must** include a Verification section.
This section must make the following point explicit:

> **The plan is not complete until every verification step passes.**

Populate the section from the relevant `~/context/*.md` files you read in step 2. Copy the
exact commands and acceptance criteria from those files so the executing agent does not need
to go looking for them. If multiple context files are relevant, include all of their criteria.

Example structure:

```markdown
## Verification

The following checks must pass before the plan can be considered complete. Do not mark
the plan done until every item below is satisfied.

### Rust code (`~/context/rust-code.md`)

- Run `cargo fmt --all --check`
- Run `cargo clippy --tests`
- Run `cargo nextest run`
- …(copy the full criteria from the context file)…

### Markdown (`~/context/markdown.md`)

- Run `prettier --check "**/*.md"`
```

### 5. Review the plan before saving

After drafting, **re-read the entire plan from the top as if you are the fresh agent who will
execute it**. Check for:

- Ambiguities: steps that could be interpreted more than one way.
- Unknowns: things the plan assumes are known but does not explain.
- Missing context: references to files, systems, or terms that are not introduced.
- Gaps: steps that skip over non-obvious intermediate work.

If you have **any doubts at all** — even small ones — **ask the user for clarification before
saving**. Do not make assumptions and silently paper over gaps. It is always better to ask.

### 6. Save and report

Write the plan to the chosen path. Then end your turn by telling the user:

> Plan written to `<path>`.

Do not proceed to implement any part of the plan. Your job is finished once the file is saved
and the path is reported.
