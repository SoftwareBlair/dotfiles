# Aliases using exa
alias l='exa --all --binary --long --group --header --git --group-directories-first --icons'
alias grid='exa --grid --all --binary --long --group --header --git --group-directories-first --icons'

tree() {
  default_level=2
  default_path="."

  exa --tree --level=${1:-$default_level} --all --binary --long --header --group-directories-first --ignore-glob=".git|node_modules|dist|build|coverage|*.log" ${2:-$default_path} --icons
}

take() {
  mkdir -p "$1"
  cd "$1"
}

# git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -D'
