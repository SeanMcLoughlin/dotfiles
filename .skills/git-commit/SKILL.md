---
name: git-commit
description: Commit your changes with a well-formed commit message. Optionally push if the user says to.
allowed-tools:
- "Bash(git status:*)"
- "Bash(git diff:*)"
- "Bash(git log:*)"
- "Bash(git add:*)"
- "Bash(git commit:*)"
- "Bash(git branch:*)"
- "Bash(git push:*)"
- "Bash(prettier:*)"
- "Bash(awk:*)"
---
Before committing, run the **Pre-flight** section of the `/ci` skill to catch any CI failures early.

Commit the existing changes with git.

Do not reference yourself as a co-author in the commit.

Use existing commit message style and stay consistent.

Use good commit message formatting. Use the 50/72 rule.

Use backticks to wrap things you expect to be monospaced. This is so that GitHub/GitLab PRs/MRs that use the commit message for the summary are formatted properly.

Never pass the commit message via `-m` — shell quoting will add backslashes before backticks, producing unreadable messages like `\`foo\`` instead of `` `foo` ``. Always write the message to a temporary file with the `write` tool and pass it to git via `-F`.

After writing the temp file and **before** running `git commit`:

1. Check the subject line length — it must be ≤ 50 characters:

```bash
awk 'NR==1{print length, $0}' /tmp/commit-msg.txt
```

If it exceeds 50, rewrite the file with a shorter subject and check again.

2. Reflow the body through prettier to enforce the 72-char line limit:

```bash
prettier --parser markdown --prose-wrap always --print-width 72 --write /tmp/commit-msg.txt
```

Then commit with:

```bash
git commit -F /tmp/commit-msg.txt
```

Then delete the temp file.

If the user asks you to make this a fixup or squash commit, simply add "fixup!" or "squash!" respectively to the beginning of the commit message. Make sure you don't add a backslash in front of the "!" if you're using a shell command to do this.

If the user asks you to push, then push the commit after committing it.
