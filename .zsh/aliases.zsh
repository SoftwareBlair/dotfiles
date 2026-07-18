# Prefer eza; fall back to exa then ls
if command -v eza >/dev/null 2>&1; then
  _LS=eza
elif command -v exa >/dev/null 2>&1; then
  _LS=exa
else
  _LS=ls
fi

if [[ "$_LS" == "ls" ]]; then
  alias l='ls -lah'
  alias grid='ls -lah'
  tree() {
    local level=${1:-2}
    local path=${2:-.}
    if command -v tree >/dev/null 2>&1; then
      command tree -L "$level" "$path"
    else
      find "$path" -maxdepth "$level"
    fi
  }
else
  alias l="$_LS --all --binary --long --group --header --git --group-directories-first --icons"
  alias grid="$_LS --grid --all --binary --long --group --header --git --group-directories-first --icons"

  tree() {
    default_level=2
    default_path="."
    default_ignore=".git|node_modules|dist|build|coverage|*.log|.nyc_output|*.zip"

    $_LS --tree --level=${1:-$default_level} --all --binary --long --header --group-directories-first --ignore-glob=${3:-$default_ignore} ${2:-$default_path} --icons
  }
fi
unset _LS

# git aliases
alias g='git'
alias gs='git status'
alias gf='git fetch'
alias gfa='git fetch --all'
alias gfp='git fetch --prune --all'
alias gp='git pull'
alias gpo='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -D'

take() {
  mkdir -p "$1"
  cd "$1"
}

killport() {
  for port in "$@"
  do
    lsof -tiL"$port" | xargs kill
  done
}
