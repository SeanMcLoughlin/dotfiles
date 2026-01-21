set -U fish_greeting # Disable help message at startup

# Aliases for editing aliases and sourcing them
alias cfg='$EDITOR ~/.config/fish/config.fish'
alias scfg='source ~/.config/fish/config.fish'

alias tmuxcfg='$EDITOR ~/.tmux.conf'

#########################
# Environment Variables #
#########################
set -x EDITOR vim
set -x PATH $PATH $HOME/Documents/scripts

#####################
# Command overrides #
#####################
alias e $EDITOR
alias edit $EDITOR
alias h history
alias rp realpath
alias xc xclip
alias v vim
alias icp it2copy
alias ls eza
alias l 'eza --icons'
alias espcfg "cd /Users/$USER/Library/Application\ Support/espanso"
function cdr
    if git rev-parse --show-toplevel > /dev/null 2>&1
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

source ~/.config/fish/private_config.fish

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/spm/.lmstudio/bin
# End of LM Studio CLI section
