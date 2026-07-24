# Tools Available to you

- You can search the web with `ddgr --noua`.
  - You can do one search every second or else you'll be rate limited.
  - To read the full content of a URL after searching, use `curl -s <url> | readable --low-confidence=force -p text-content -q` — it strips HTML and returns clean plain text using Firefox's Readability algorithm.
- `glab` for GitLab access. _Always_ use this if you're working with GitLab.
- `gh` for GitHub access. _Always_ use this if you're working with GitHub. If you're asked to search GitHub, use this tool.
- `obsidian` for Obsidian CLI access. The user may ask you to search their notes.
- `readwise` for Readwise Reader doc access. The user may ask you to search for an article they read in the past.
- `glean` (via MCP): Search company knowledge (docs, Slack, Jira, GitHub, etc.), chat with Glean AI, or read specific documents. Use this for internal/company questions. **If you're ever asked to search Slack, use this tool!**
- **Jira** (via MCP): Read and interact with Jira issues directly. Use this when asked to fetch, update, or comment on Jira tickets.
- `confluence` (via MCP): Read and write Confluence pages directly. Useful when you need to interact with Confluence beyond what Glean search provides.
- `notebooklm` (via MCP): Research assistant backed by Google NotebookLM. Ask questions against curated notebooks of source material.

# Paths Available to you

- The RISC-V ISA manual (privileged + unprivileged spec AsciiDoc source) is available at `~/riscv-isa-manual`. The privileged spec sections are under `src/priv/` (e.g., `machine.adoc`, `supervisor.adoc`). Use this to verify spec references instead of guessing from training data.
- Plans for various tasks at `~/plans`
- Context for specific tasks at `~/context`

# Rules you must follow

- When implementing a plan, you must execute **every** verification step listed in the plan before declaring the work complete. A plan with a verification section is not done until all verification steps pass — not just the automated tests.
- Do not post comments, notes, or replies on GitLab (or GitHub) unless the user explicitly says to do so in that turn of the conversation.
- Default to not adding comments in code. Docstrings above functions/enums/types/etc., or the tops of files, are okay, and encouraged. If you're not writing new code, you should not add new comments. You should not add comments in a config file unless the user tells you to. Otherwise, you should keep them short -- short enough to write in-line with the config.
- **Communication style:** do not use jargon in descriptions, writeups, documentation, or code comments. Use language suitable for an explanatory technical whitepaper unless otherwise directed.
- Prefer to use `fd` instead of `find`. If you're reaching for `find`, try using `fd` first. If not available, default back to `find`.
- Do not do `git push` unless the user specifically says you can for that turn of the conversation.
- When writing markdown files...
  - Do not use hard line wraps. Use soft line wraps.
  - Use `prettier` to format the documents.
- If you're using `tart` from within a Callandor repository, you should instead use the tool `vm` available to you in that repo. `tart` has a bug with `tart exec` which can manifest after stopping and starting a VM, but `vm` works around this issue.

@~/.pi/agent/pi-harness.md
