set -g fish_greeting # Disable help message at startup

######################################################################
# Color scheme: named ANSI colors, not a fixed catppuccin-mocha hex  #
# palette. Ghostty swaps its own ANSI palette between Catppuccin     #
# Frappe (dark) and Latte (light) based on macOS appearance, so      #
# pointing fish at ANSI names lets these colors adapt automatically  #
# -- in both modes, and over SSH, since Ghostty (not the remote      #
# host) resolves them.                                               #
######################################################################
set -g fish_color_normal normal
set -g fish_color_command blue
set -g fish_color_quote yellow
set -g fish_color_redirection cyan --bold
set -g fish_color_end green
set -g fish_color_error brred
set -g fish_color_param cyan
set -g fish_color_comment red
set -g fish_color_match --background=brblack
set -g fish_color_search_match bryellow --background=brblack
set -g fish_color_history_current --bold
set -g fish_color_operator brcyan
set -g fish_color_escape brcyan
set -g fish_color_cwd green
set -g fish_color_cwd_root red
set -g fish_color_valid_path --underline
set -g fish_color_autosuggestion brblack
set -g fish_color_user brgreen
set -g fish_color_host normal
set -g fish_color_host_remote yellow
set -g fish_color_cancel -r
set -g fish_color_selection white --bold --background=brblack
set -g fish_color_status red

# Aliases for editing aliases and sourcing them
alias cfg='$EDITOR ~/.config/fish/config.fish'
alias scfg='source ~/.config/fish/config.fish'

alias tmuxcfg='$EDITOR ~/.tmux.conf'

#########################
# Environment Variables #
#########################
if command -q hx
    set -x EDITOR hx
else if command -q nvim
    set -x EDITOR nvim
else
    set -x EDITOR vim
end
set -x PATH $PATH $HOME/Documents/scripts

#####################
# Command overrides #
#####################
alias e $EDITOR
alias edit $EDITOR
alias h history
alias rp realpath
alias copy pbcopy
alias paste pbpaste
alias v vim
alias icp it2copy
alias ls eza
alias l 'eza --icons'
alias tree 'eza --tree --git-ignore'
alias espcfg "cd /Users/$USER/Library/Application\ Support/espanso"
alias web "ddgr --noua"

##########
# GitLab #
##########
alias mr "glab mr view"
alias pl "glab ci get -p"
# ci-status lives in the callandor repo (tools/ci-status) and monitors itself,
# so these no longer need viddy.
function mrci --description 'Monitor the CI of a merge request, child pipelines included'
    ci-status -m --mr $argv
end
function plci --description 'Monitor the CI of a pipeline, child pipelines included'
    ci-status -m -p $argv
end

function cdr
    if git rev-parse --show-toplevel >/dev/null 2>&1
        cd (git rev-parse --show-toplevel)
    else
        echo "Not a git repository"
    end
end
function mkcd
    mkdir -p $argv && cd $argv[-1]
end

##########
# Claude #
##########
alias c claude
alias cs "claude --model sonnet"
alias cps "claude -p --model sonnet"
alias co "claude --model opus"
alias cpo "claude -p --model opus"
alias cf "claude --model fable"
alias cpf "claude -p --model fable"

################
# Tmux Aliases #
################
alias tmas 'tmux attach-session -t'
alias tmasd 'tmux attach-session -d -t'
alias tmls 'tmux ls'
alias t 'tmux new-session -A -s main'

##############
# Difftastic #
##############
set -x DFT_OVERRIDE '*.svh:verilog'

#######################
# cd backwards with , #
#######################
alias , 'cd ..'
alias ,, 'cd ../..'
alias ,,, 'cd ../../..'
alias ,,,, 'cd ../../../..'
alias ,,,,, 'cd ../../../../..'

###############
# LLM Aliases #
############### 
set -x HOMEBREW_NO_ENV_HINTS 1

test -f ~/.config/fish/private_config.fish && source ~/.config/fish/private_config.fish
test -f ~/.config/fish/pi.fish && source ~/.config/fish/pi.fish

# direnv
if command -q direnv
    direnv hook fish | source
end

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/spm/.lmstudio/bin
# End of LM Studio CLI section

# Created by `pipx` on 2026-01-23 21:15:22
set PATH $PATH /Users/smcloughlin/.local/bin

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/smcloughlin/.lmstudio/bin
# End of LM Studio CLI section
