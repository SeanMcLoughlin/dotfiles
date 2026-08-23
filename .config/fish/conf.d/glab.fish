# Pair this with `glamour_style: auto` in the glab config (scripts/glab-config.sh).
# glab only consults the terminal background when BOTH are set; `auto` on its own
# makes it drop merge request descriptions with no error.
set -gx GLAB_GLAMOUR_STYLE auto
