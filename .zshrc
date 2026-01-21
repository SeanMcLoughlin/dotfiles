alias cfg="vim ~/.zsh_aliases"
alias scfg="source ~/.zsh_aliases"


#########################
# Environment Variables #
#########################
if type "nvim" &> /dev/null; then
	export EDITOR=nvim
        alias vim=nvim
else
	export EDITOR=vim
fi
export PATH=$PATH:$HOME/Documents/scripts

#####################
# Command overrides #
#####################
alias h="history"
alias rp="realpath"
alias xc="xclip"
alias v="nvim"
alias icp="it2copy"
alias espcfg="cd /Users/$USER/Library/Application\ Support/espanso"

################
# Tmux Aliases #
################
alias tmas="tmux attach-session -t"
alias tmasd="tmux attach-session -d -t"
alias tmls="tmux ls"

#######################
# cd backwards with , #
#######################
alias ,="cd .."
alias ,,="cd ../.."
alias ,,,="cd ../../.."
alias ,,,,="cd ../../../.."
alias ,,,,,="cd ../../../../.."

# Aliases that I don't want committed to a public repository
source ~/.private_aliases
source ~/.tokens
export HOMEBREW_NO_ENV_HINTS=1

