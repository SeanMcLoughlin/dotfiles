#!/usr/bin/env bash
# Set the glab options that cannot be a tracked file.
#
# glab keeps config.yml in a different place on each platform (an Application
# Support directory on macOS, an XDG directory on Linux), rewrites it on every
# run to record update checks, and writes the API token into it when no keyring
# is available. So the file is set with the CLI rather than linked from here.
#
# glamour_style controls the Markdown palette for `glab mr view` and friends.
# The value "auto" follows the terminal background, but only when the
# GLAB_GLAMOUR_STYLE variable is also set -- .config/fish/conf.d/glab.fish does
# that. With "auto" and no variable, glab drops the description and says nothing.

set -euo pipefail

if ! command -v glab >/dev/null 2>&1; then
    echo "glab not installed; skipping." >&2
    exit 0
fi

glab config set --global glamour_style auto
echo "glamour_style = $(glab config get glamour_style)"
