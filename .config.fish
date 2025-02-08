set -U fish_greeting # Disable help message at startup

# Aliases for editing aliases and sourcing them
alias al='vim ~/.config/fish/config.fish'
alias sal='source ~/.config/fish/config.fish'


#########################
# Environment Variables #
#########################
if command -v nvim &> /dev/null
    set -x EDITOR nvim
    alias vim 'nvim'
else
    set -x EDITOR vim
end

set -x PATH $PATH $HOME/Documents/scripts

#####################
# Command overrides #
#####################
alias h 'history'
alias rp 'realpath'
alias xc 'xclip'
alias v 'nvim'
alias icp 'it2copy'
alias espcfg "cd /Users/$USER/Library/Application\ Support/espanso"

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
alias llmsyscmd "\"Respond with nothing but the command to run.\""

set -x HOMEBREW_NO_ENV_HINTS 1
source ~/.config/fish/private_config.fish
