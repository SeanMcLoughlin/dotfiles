set -g fish_greeting # Disable help message at startup
fish_config theme choose "catppuccin-mocha"

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

################
# Tmux Aliases #
################
alias tmas 'tmux attach-session -t'
alias tmasd 'tmux attach-session -d -t'
alias tmls 'tmux ls'

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

######################
# GitLab CI (local)  #
######################

# Run CI, ignoring rules:changes to always run the specified jobs, and forcing a shell executor to not use Docker.
# You should almost always use this alias instead of the main command.
alias ci "gitlab-ci-local --force-shell-executor --evaluate-rule-changes=false"

# Run CI with the ability to glob all jobs after a colon of the job name. If you have jobs like:
# my_dir:job1, my_dir:job2, my_dir:job3
# and they all share the same stage as other jobs like:
# other_dir:jobX, other:dir:jobY
# Then you can run:
# cig my_dir
# and it will run all jobs under my_dir.
# This is a workaround for gitlab-ci-local not supporting regexes or globs in job names, requiring you to only
# filter on either exact stage names, or exact job names.
# https://github.com/firecow/gitlab-ci-local/issues/1664
function cig
    ci --force-shell-executor (ci --list 2>&1 | awk "/^$argv[1]:/{printf \"--job %s \", \$1}" | string split ' ' | string match -v '')
end

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
