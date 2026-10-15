# Dotfiles

My config (dot) files.

Run `dotter deploy` to install.

Agent skills deploy into `~/.skills`, which must be a real directory, and `~/.claude/skills` points to it. `.dotter/global.toml` lists each skill directory. `dotter` links every file inside a listed directory, so run `dotter deploy` after you add a skill or a file to a skill.

A second repository deploys its own skills and rules into the same `~/.skills` and `~/.pi/agent/`. `AGENTS.md` imports `~/.pi/agent/private-rules.md` from it.

`glab` needs one extra step: `scripts/glab-config.sh`. Its `config.yml` lives at a
different path per platform, glab rewrites it on every run, and it holds the API token
when no keyring is available, so the file is not tracked here. The script sets the one
option that matters, and `.config/fish/conf.d/glab.fish` sets the variable it needs.
