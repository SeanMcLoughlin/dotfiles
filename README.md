# Dotfiles

My config (dot) files.

Run `dotter deploy` to install. Agent skills are the one exception: `dotter`
recurses a directory into per-file links, so a newly added skill file would
silently stay outside this repo. Link the whole directory once instead:

```sh
ln -s ~/.dotfiles/.skills ~/.skills
```

`~/.claude/skills` is itself a symlink to `~/.skills`.

`glab` needs one extra step: `scripts/glab-config.sh`. Its `config.yml` lives at a
different path per platform, glab rewrites it on every run, and it holds the API token
when no keyring is available, so the file is not tracked here. The script sets the one
option that matters, and `.config/fish/conf.d/glab.fish` sets the variable it needs.
