---
name: spec-search
description: Search the Callandor CPU spec (arch + uarch) under vendor/int_tt/risc-v-cpu-spec for information. Use when the user asks about the CPU spec, microarchitecture details, architecture spec, or wants to look something up in the vendor spec.
---

# Spec Search

Search the Callandor RISC-V CPU specification for information provided by the user.

## Spec location

The spec lives at `~/repos/callandor/vendor/int_tt/risc-v-cpu-spec/`. It contains:

- `arch/` — architecture-level specs (ISA, CSRs, integration, RAS, etc.)
- `uarch/` — microarchitecture specs (pipeline, load/store, caches, branch prediction, etc.)
- `common/` — shared content
- `doc/` — additional documentation

The documents are primarily AsciiDoc (`.adoc`) files with diagrams in `images/` subdirectories.

## Procedure

1. **Start broad** — use `rg` to search for the user's query terms across the spec:
   ```bash
   rg -n -i "<term>" ~/repos/callandor/vendor/int_tt/risc-v-cpu-spec/ --include "*.adoc" -l
   ```

2. **Narrow down** — once you identify relevant files, search with context:
   ```bash
   rg -n -i -C 5 "<term>" <file>
   ```

3. **Read sections** — use `read` to load the relevant portions of the matching files. AsciiDoc section headers use `==` notation, so look for those to orient yourself within the document.

4. **Cross-reference** — specs often reference other sections with `<<label>>` syntax. Follow those references if needed to give a complete answer.

5. **Summarise** — provide a clear, concise answer to the user's question, citing the specific file(s) and section(s) where the information was found. Quote key passages when helpful.

## Tips

- Many terms have abbreviations used in the spec (e.g., DMB = Data Merge Buffer, STQ = Store Queue, LDQ = Load Queue, RAR = Read-After-Read buffer). Try both the abbreviation and the full name.
- The `uarch/cpu_uarch/src/` directory contains the core microarchitecture docs (loadstore.adoc, frontend.adoc, etc.).
- The `arch/cpu_arch/src/` directory contains architecture-level docs.
- Diagrams are in SVG/drawio format under `images/` directories — mention them if relevant but you can't render them.
