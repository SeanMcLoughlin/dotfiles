---
name: clipboard
description: Copy the text the user most likely wants to paste next into their clipboard. By default it is Markdown that pastes cleanly into GitLab or GitHub; with "slack" or "jira" in the arguments it is rich text that pastes with its formatting into a Slack message or a Jira Cloud field. Choose the text from the conversation. Use when the user says "copy that", "put it in my clipboard", "paste this into my clipboard", or invokes /clipboard with or without a hint.
allowed-tools:
  - "Bash(pbcopy:*)"
  - "Bash(pbpaste:*)"
  - "Bash(prettier:*)"
  - "Bash(printf:*)"
  - "Bash(diff:*)"
  - "Bash(osascript:*)"
  - "Bash(~/.skills/clipboard/copy-rich.sh:*)"
  - "Bash(~/.skills/clipboard/copy.sh:*)"
---

The user invokes this skill and expects one result: the right text is in the clipboard. Do not ask a question. Do not post, send or save the text anywhere else.

## 1. Choose the target

- If the arguments contain the word `slack` (any case), the target is **Slack**.
- If the arguments contain the word `jira` (any case), the target is **Jira**. This is the Jira Cloud editor, for a description or a comment.
- Otherwise the target is **Markdown**, for GitLab and GitHub.

Remove the target word from the arguments; what is left is the hint.

## 2. Choose the text

If a hint is left (for example "the comment", "the command", "the second example"), copy the text that the hint names.

With no hint, copy the most recent text in the conversation that was written for the user to paste somewhere else. In order of preference:

1. Text you labelled as ready to paste: a comment, a reply, a message, a merge request or commit description, a ticket body.
2. A command you gave the user to run.
3. A code or config snippet you proposed.
4. Your last answer, when nothing above exists.

Copy the whole item, and only that item. Leave out your own lead-in and closing lines, such as "You can paste this:" or "I did not post it."

## 3. Format the text

For every target, write it as GitHub-flavored Markdown:

- Remove the display wrapping you added in the chat: the `> ` quote marks on each line, and any outer fence that only held the text for display.
- Keep inner fenced code blocks, with their language tag (` ```jsonc `, ` ```rust `, ` ```bash `).
- Keep inline code in backticks for names, paths, knobs and commands.
- Use soft wraps only. One paragraph is one line.
- Put one blank line between paragraphs, lists and code blocks.
- Keep the exact characters of code and identifiers. Do not change quotes, dashes or spaces inside code.

One exception: a single shell command for the user to run in a terminal is copied as the bare command, with no fence and no backticks, whatever the target.

For the **Slack** target, also change the parts that Slack cannot show:

- A heading becomes a line of bold text.
- A table becomes a list, one item per row, or a code block when the columns must stay aligned.
- An image becomes its link.

For the **Jira** target, keep headings and tables: the Jira editor shows both.

Then normalize the Markdown with Prettier when Prettier is installed. Skip this for a bare command.

## 4. Copy and check

Use a quoted heredoc so the shell expands nothing. Choose a delimiter that does not occur in the text.

`copy.sh`, next to this file, copies the Markdown from its input. With `--rich`, it also puts the text on the clipboard as HTML.

- On a Mac with a local shell, it uses `pbcopy`, or `copy-rich.sh` for `--rich`.
- In every other case, such as a Linux machine reached over SSH or a tmux session, it sends escape sequences to the terminal. The clipboard of the machine that shows the terminal receives the text. OSC 52 carries the plain text. For `--rich`, OSC 5522 follows it and carries the plain text with the HTML, which `pandoc` makes. Ghostty 1.4 or later accepts OSC 5522. A terminal that does not accept it keeps the plain text.

**Markdown target:**

```bash
prettier --stdin-filepath clip.md --prose-wrap never <<'CLIP_EOF' | ~/.skills/clipboard/copy.sh
<the text>
CLIP_EOF
```

**Slack and Jira targets:** use `--rich`. Slack and Jira paste the HTML with its formatting; a plain-text field pastes the Markdown.

```bash
prettier --stdin-filepath clip.md --prose-wrap never <<'CLIP_EOF' | ~/.skills/clipboard/copy.sh --rich
<the text>
CLIP_EOF
```

A bare command goes straight to `copy.sh`, without `--rich`, for every target. If `prettier` is not on `PATH`, leave it out of the pipe. If `pandoc` is not on `PATH`, `copy.sh` copies plain text only; say that the paste will be plain text.

On a Mac with a local shell, check the result with `pbpaste | head -5`. Any other shell cannot read the clipboard of the machine that shows the terminal, so skip the check and say that you did not check it. For the Slack and Jira targets on a Mac with a local shell, also check that the clipboard holds HTML:

```bash
osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.deepUnwrap($.NSPasteboard.generalPasteboard.types).includes("public.html")'
```

It must print `true`. If a check fails, fix the problem and copy again.

## 5. Report

Reply in one or two lines: what you copied, for which target, and any formatting you removed or changed. Do not print the text again.
