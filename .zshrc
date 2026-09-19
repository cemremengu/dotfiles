export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git sudo golang rust docker docker-compose web-search z zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
alias history="history 1"
bindkey -v

eval "$(~/.local/bin/mise activate zsh)"

export PATH=$PATH:/usr/local/go/bin
export PATH="$PATH:$(go env GOPATH)/bin"
