---
name: git-commit
description: Commit staged or unstaged changes with a well-formatted git commit message using the 50/72 rule.
allowed-tools:
- "Bash(git status:*)"
- "Bash(git diff:*)"
- "Bash(git log:*)"
- "Bash(git add:*)"
- "Bash(git commit:*)"
- "Bash(git branch:*)"
---
Commit the existing changes with git.

Do not reference yourself as a co-author in the commit.

Use existing commit message style and stay consistent.

Use good commit message formatting. Use the 50/72 rule.

If the user asks you to make this a fixup or squash commit, simply add "fixup!" or "squash!" respectively to the beginning of the commit message. Make sure you don't add a backslash in front of the "!" if you're using a shell command to do this.
