# NVM directory (official installer + brew fallback)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Dotfiles + Starship config (features file may override)
if [[ -f "$HOME/.dotfiles-setup/shell-features.zsh" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.dotfiles-setup/shell-features.zsh"
fi

if [[ -z "${DOTFILES_DIR:-}" ]]; then
  if [[ -d "$HOME/dotfiles" ]]; then
    export DOTFILES_DIR="$HOME/dotfiles"
  fi
fi

if [[ -n "${DOTFILES_DIR:-}" ]]; then
  export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$DOTFILES_DIR/.config/starship.toml}"
else
  export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$HOME/dotfiles/.config/starship.toml}"
fi

# Local secrets (repo-root .zprofile — gitignored, never committed)
if [[ -n "${DOTFILES_DIR:-}" && -f "$DOTFILES_DIR/.zprofile" ]]; then
  # shellcheck disable=SC1091
  source "$DOTFILES_DIR/.zprofile"
fi
