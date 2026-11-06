# GitLab with `glab`

Use this file when the session has no GitLab MCP tools.

- Use `glab` for all GitLab work.
- The user keeps two tokens. A personal token has few write permissions. A project token has the Developer role and has all the write permissions.
- If a read-only token refuses an operation, and you must use an API-scoped token to force it, that refusal is the signal to stop and ask.

## Do not load the GitLab server

Every `glab` call is a request to the shared `aus-gitlab` server. On 2026-11-05 the GitLab administrators reported about 1,100 calls an hour from this account, from two `ci-status` watches. Since dvtools !113, `ci-status --events` makes one GraphQL request for each check, and `glab` telemetry is off.

- To wait on a merge request or a pipeline, run `ci-status --events` with `--interval 30`. Do not use a shorter interval.
- Run one watch for each merge request at most. Before you start a watch, run `pgrep -af "ci-status.*--mr <IID>"`. If another session already watches that merge request, do not start a second watch.
- Stop your watch when you no longer wait on the result.
- Do not write a loop that calls `glab`, `curl` or an MCP tool again and again to poll GitLab.
