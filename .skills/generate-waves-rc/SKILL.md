---
name: generate-waves-rc
description: Write a Verdi/nWave signal-restore (.rc) file grouping the signals under investigation, loadable via File → Restore Signal. Use after a waveform debug session when the user wants a saved signal view. Assumes the conversation already established WHICH signals, times, and groupings belong in the file; this skill only supplies the file SYNTAX.
---

# Generate an nWave signal-restore (.rc) file

This produces a file in nWave's **native signal-file format** — the one written by
**File → Save Signal…** and read by **File → Restore Signal…**. It is NOT Tcl.
(A Tcl `wvAddSignal` script fails to load here: nWave's restore reader rejects every
line with "Unrecognized keyword in file", including `set`/`if`/`catch`.)

Decide the *contents* (which signals, grouping, key timestamps) from the conversation.
This file only tells you how to write them.

## File skeleton

```
Magic 271485
Revision Verdi_X-2025.06

; comments start with a semicolon

viewPort 0 11 1673 533 448 251

openDirFile -d / "" "/abs/path/to/waves.fsdb"

signalSpacing 5

zoom <start> <end>
cursor <time>
marker <time>

; user define markers: userMarker time_pos marker_name color linestyle
userMarker <time> "<name>" <color_int> <linestyle_int>

top 0
markerPos 0

activeDirFile "" "/abs/path/to/waves.fsdb"

curSTATUS ByChange

addGroup "TOP" -e TRUE
activeDirFile "" "/abs/path/to/waves.fsdb"

addSubGroup "1_first_group" -e TRUE
addSignal -h 16 /full/hier/path/single_bit_sig
addSignal -h 16 -UNSIGNED -HEX /full/hier/path/vector_sig[11:0]
endSubGroup "1_first_group"

addSubGroup "2_next_group" -e TRUE
addSignal -h 16 -UNSIGNED -HEX /full/hier/path/multidim_sig
endSubGroup "2_next_group"
```

- The file must be **pure ASCII**. nWave's restore reader rejects the whole file with
  `<path> is not an ascii file` if it finds any non-ASCII byte — a single UTF-8 character
  is enough. The usual culprit is a "smart" punctuation character in a comment: an em-dash
  (`—`), en-dash (`–`), curly quotes (`“ ” ‘ ’`), or a non-breaking space. Use plain ASCII
  (`-`, `"`, `'`, regular spaces) everywhere, comments included. Verify before handing off:
  `LC_ALL=C grep -nP '[^\x00-\x7F]' <file>` (should print nothing) or `file <file>` (should
  say `ASCII text`, not `UTF-8 text`).
- First two lines are mandatory: `Magic 271485` and `Revision Verdi_X-<ver>`. Match the
  user's Verdi version (seen in the banner / `Help → About`, e.g. `Verdi_X-2025.06`). Copy
  the header from an existing repo `.rc` (e.g. `dv/signals/call_ls.rc`) if unsure.
- Repeat `activeDirFile "" "<fsdb>"` once before the first `addGroup` and again right
  after it (matches what nWave writes).
- Do NOT emit `endGroup` for the top `addGroup` — it is closed implicitly at EOF, and the
  keyword may be rejected. Every `addSubGroup` DOES need a matching `endSubGroup "name"`.

## Signal paths — the multi-dimensional gotcha (most common failure)

nWave uses the **FSDB's native dimensions**. Append a `[msb:lsb]` bit range ONLY to a
signal that is genuinely a **1-D packed vector** of exactly that width. For anything with
extra dimensions, add it by **bare name** and let nWave pull the full multi-dim bus (the
user expands it in the GUI).

| Declared type | Write it as |
| --- | --- |
| `logic sig` (scalar) | `/path/sig` |
| `logic [11:0] sig` (1-D vector) | `/path/sig[11:0]` (bare `/path/sig` also fine) |
| `logic [1:0][2:0] sig` (2-D) | `/path/sig`  ← bare, NO range |
| `logic [1:0][2:0][1:0] sig` (3-D+) | `/path/sig`  ← bare |
| element of an unpacked array `sig[0][2]` (a flat vector) | `/path/sig[0][2][66:0]` ← needs the range |

Rule of thumb: if a flat `[N:0]` range does not match the native declaration, drop it.
A signal added with a wrong/oversized range comes up **red / not-found**; bare name resolves.

> `wavequery` auto-flattens multi-dim signals (so `sig[13:0]` works there); nWave does not —
> that mismatch is why a range copied from `wavequery` output can fail on load.

Other path rules:
- Absolute paths use `/` as the delimiter (set by `openDirFile -d /`):
  `/cal_core_tb/u_dut/u_ls/...`.
- Generate-block scopes are path segments with their index:
  `/…/u_tap_ctl/g_line_hit_ta3_copy[0]/g_line_hit_ta3_pipe[1]/g_line_hit_ta3_line[0]/real_hit_vec[3:0]`.
- `-holdScope <relname>` reuses the previous signal's scope for a relative name; prefer full
  paths for robustness.

## addSignal options

- `-h 16` — row height (use 16).
- `-UNSIGNED -HEX` — display a bus in hex (use for any multi-bit value; essential for wide
  arrays like tag/state RAMs and packed structs).
- Omit format flags for single-bit signals.
- `/BLANK` as the path inserts a spacer row.

## Groups

- `addGroup "NAME" -e TRUE` — top-level group. `-e TRUE` = expanded, `-e FALSE` = collapsed.
- `addSubGroup "NAME" -e TRUE` … `endSubGroup "NAME"` — nestable; name in `endSubGroup`
  must match. Give subgroups ordinal-prefixed names (`1_…`, `2_…`) so they read as the
  investigation's causal order.

## Times, cursor, markers

- All time values are in the **FSDB time resolution** (commonly ps — the same integer
  `wavequery` prints as `…ps`). Sanity-check the scale against an existing repo `.rc`
  (`cursor`/`zoom` magnitudes) before trusting a unit.
- `cursor <t>` — parks the main cursor (put it at the primary event).
- `marker <t>` — the single primary marker.
- `userMarker <t> "<name>" <color> <linestyle>` — one labeled reference line per key event;
  `color` and `linestyle` are small integers. These persist regardless of zoom.
- `zoom <start> <end>` — initial view. If key events span a wide interval, set `zoom` wide
  enough to show every `userMarker` at once (the user double-clicks / box-zooms a marker to
  drop into cycle detail); a zoom tighter than the marker spread hides the off-screen ones.
- nWave parses each line independently: a malformed `userMarker` only drops that marker, it
  does not abort the signal load. If markers do not appear, try `#RRGGBB` or a named color
  for `<color>`.

## Loading (tell the user)

**File → Restore Signal…** → pick the `.rc`. The waveform must already be open (e.g. launched
with `verdi -ssf waves.fsdb -dbdir <…>.daidir`); the `openDirFile`/`activeDirFile` lines
reference the same FSDB and nWave reuses the loaded database.
