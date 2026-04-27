# Tools Available to you

- `cig <prefix>` is available as a shell function (via shellCommandPrefix) to run all gitlab-ci-local jobs matching `<prefix>:*` in parallel. E.g. `cig adrenaline`.
- You can search the web with `ddgr --noua`.
  - You can do one search every second or else you'll be rate limited.
  - To read the full content of a URL after searching, use `curl -s <url> | readable --low-confidence=force -p text-content -q` — it strips HTML and returns clean plain text using Firefox's Readability algorithm.
- `subagent`: Use it proactively when tasks would benefit from isolated context or parallel work:
  - Use `scout` (Haiku, fast) for codebase recon before complex changes
  - Use `planner` to create implementation plans from scout findings
  - Use `worker` for self-contained subtasks that don't need your full context
  - Use `reviewer` for code review after changes
  - Use parallel mode when multiple independent investigations are needed
  - Use chain mode for scout → planner → worker workflows
  - Don't use subagents for simple tasks you can handle directly
- `glab` for GitLab access. _Always_ use this if you're working with GitLab.
- `gh` for GitHub access. _Always_ use this if you're working with GitHub.
- `obsidian` for Obsidian CLI access. The user may ask you to search their notes.
- `readwise` for Readwise Reader doc access. The user may ask you to search for an article they read in the past.
- `glean` (via MCP): Search company knowledge (docs, Slack, Jira, GitHub, etc.), chat with Glean AI, or read specific documents. Use this for internal/company questions. **If you're ever asked to search Slack, use this tool!**
- `confluence` (via MCP): Read and write Confluence pages directly. Useful when you need to interact with Confluence beyond what Glean search provides.
- `notebooklm` (via MCP): Research assistant backed by Google NotebookLM. Ask questions against curated notebooks of source material.

# Paths Available to you

- The RISC-V ISA manual (privileged + unprivileged spec AsciiDoc source) is available at `~/riscv-isa-manual`. The privileged spec sections are under `src/priv/` (e.g., `machine.adoc`, `supervisor.adoc`). Use this to verify spec references instead of guessing from training data.
- Plans for various tasks at `~/plans`
- Context for specific tasks at `~/context`

# Rules you must follow

- Do not do `git push` unless the user specifically says you can for that turn of the conversation.
- When writing markdown files...
  - Do not use hard line wraps. Use soft line wraps.
  - Use `prettier` to format the documents.
- If you're using `tart` from within a Callandor repository, you should instead use the tool `vm` available to you in that repo. `tart` has a bug with `tart exec` which can manifest after stopping and starting a VM, but `vm` works around this issue.
