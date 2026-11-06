# GitLab with the MCP server

Use this file when the session has GitLab MCP tools (`mcp__aus-gitlab__*`).

The MCP server signs in as the user through OAuth. The user has the Owner role. The user does not give you an API personal access token, because an Owner token could delete a repository. No token refuses an operation for you, so the rules below are the only guard.

## Which tool to use

- Use the MCP tools to read merge requests, pipelines, jobs and work items.
- Use the MCP tools to write notes, reviews and merge request descriptions.
- Use `glab` for the raw API (`glab api`), pipeline traces, `git push -o merge_request.*` options, and anything the MCP tools do not cover.

## Stop and ask first

- Stop and ask before any call that un-drafts a merge request, marks it ready, merges it, or arms auto-merge. This includes `accept_merge_request` and `save_merge_request`.
- Do not call `save_note` or `save_merge_request_review` unless the user says to post a comment in that turn of the conversation.
- A draft merge request stays a hold. Only an explicit instruction that names the merge request releases it.

## Do not load the GitLab server

Every `glab` call is a request to the shared `aus-gitlab` server. On 2026-11-05 the GitLab administrators reported about 1,100 calls an hour from this account. Two `ci-status` watches at `--interval 30` made them.

- To wait on a merge request or a pipeline, run `ci-status --events` with `--interval 300`. Do not use a shorter interval, also when a repository rule or a skill gives one.
- Run one watch for each merge request at most. Before you start a watch, run `pgrep -af "ci-status.*--mr <IID>"`. If another session already watches that merge request, do not start a second watch.
- Stop your watch when you no longer wait on the result.
- Do not write a loop that calls `glab`, `curl` or an MCP tool again and again to poll GitLab.
