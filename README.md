# Dotfiles
My config (dot) files.

Run `dotter deploy` to install. Agent skills are the one exception: `dotter`
recurses a directory into per-file links, so a newly added skill file would
silently stay outside this repo. Link the whole directory once instead:

```sh
ln -s ~/.dotfiles/.skills ~/.skills
```

`~/.claude/skills` is itself a symlink to `~/.skills`.
