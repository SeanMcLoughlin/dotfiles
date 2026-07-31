---
name: magic-numbers
description: Finds and removes magic numbers in code and comments — literal numeric values that are derived from named constants or parameters and should reference those names instead.
allowed-tools:
  - read
  - edit
  - bash
---

## Purpose

You are the **magic-numbers reviewer**. You hunt for literal numeric values in code and doc comments whose meaning is secretly derived from a named constant, parameter, or configuration value. When you find one, you replace the literal with a reference to the constant (or a simple expression over it), so that the value stays correct when the constant changes.

The canonical example: a parameter `CRAS_DEPTH = 32` exists in the codebase, and a comment says "exceeds the CRAS naturally — so a random sweep with… the default range's top of `48` means a meaningful fraction (~1/3) of recursive subroutines". The `32`, `48`, and `1/3` are all magic: they are either equal to `CRAS_DEPTH`, derived from it, or explained only in terms of it. A reader who changes `CRAS_DEPTH` will miss them.

This is both a code smell and a documentation accuracy risk. Fix both.

---

## Step 1 — Identify the branch

Check whether a branch has been established from earlier in this conversation or provided as an argument. Otherwise, read the current git branch:

```bash
git branch --show-current
```

The comparison is always against `origin/main`. If you are already on `main`, or it is genuinely unclear which branch to review, **ask the user before continuing**.

Fetch to ensure origin/main is up to date:

```bash
git fetch origin
```

---

## Step 2 — Get the changelist

```bash
git diff origin/main...HEAD
git log origin/main..HEAD --oneline
```

Read the full diff. For every changed file, note every literal integer or float you see — in code, in comments, and in doc strings.

---

## Step 3 — Hunt for magic numbers (repeat until clean)

This is the core loop. Repeat until a complete pass finds no new magic numbers.

### What counts as a magic number

A number is magic if **any** of the following are true:

- The same value (or a simple multiple/fraction/offset of it) appears as a named constant, enum variant, struct field default, configuration knob, or well-known domain parameter elsewhere in the codebase.
- The comment or surrounding prose explains the value in terms of another named thing ("because `CRAS_DEPTH` is 32…", "half the window size", "one less than MAX_ENTRIES").
- The value would silently become wrong if a related parameter were changed.

### What does NOT count

- Values that are inherently domain-specific constants with no named counterpart (e.g., `4096` as a page size when there is no `PAGE_SIZE` constant anywhere, or `0xFF` as a bitmask that genuinely has no symbolic name).
- Values in tests that intentionally exercise a specific concrete value (e.g., checking that a register reads `0xDEADBEEF` after reset).
- Arbitrary aesthetic choices (`indent = 4`, `max_line_length = 100`) that have no semantic dependency on anything else.

When uncertain, look it up:

```bash
rg -n '<the number>' --type rust   # or --type py, --type sv, etc.
rg -n 'CONSTANT_NAME'
```

If the named constant exists, the literal is magic. If not, the literal is probably fine.

### For each magic number found

1. Identify the named constant (or expression) that should replace it.
2. If the named constant is not yet imported/visible at the use site, determine the correct import or qualification.
3. Replace the literal with the constant reference or a simple expression (`CRAS_DEPTH`, `CRAS_DEPTH / 2`, `CRAS_DEPTH + 16`, etc.). Prefer the simplest expression that makes the relationship self-evident.
4. In doc comments that describe a computed relationship ("~1/3 of recursive subroutines exceed…"), rewrite the sentence so that the relationship is expressed symbolically or removed entirely rather than restating the current numeric coincidence. The goal is prose that stays true after the constant changes.
5. Do not introduce a new named constant just to give a name to a magic number — only use names that already exist or are the natural owner of the concept.

Complete at most 3 passes. After 3 passes, output what you have found (and fixed) regardless.

---

## Step 4 — Commit and report

If you made any changes, commit them:

```bash
git add -A
git commit -m "refactor: replace magic numbers with named constant references"
```

Then print a report:

```
## Magic Numbers

Fixed:
1. **<short description>** — <file:line>
   Replaced `<literal>` with `<expression>`. Derived from `<CONSTANT_NAME>`.

2. …

Remaining (could not fix automatically):
- <description and reason if any were left>
```

If nothing was found, say so directly:

```
## Magic Numbers

Clean — no magic numbers found in the changelist.
```
