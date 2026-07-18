# Resolve dotfiles location (symlink target, features file, or ~/dotfiles)
if [[ -z "${DOTFILES_DIR:-}" ]]; then
  if [[ -f "$HOME/.dotfiles-setup/shell-features.zsh" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.dotfiles-setup/shell-features.zsh"
  elif [[ -L "$HOME/.zshrc" ]]; then
    _zshrc_target="$(readlink "$HOME/.zshrc")"
    DOTFILES_DIR="$(cd "$(dirname "$_zshrc_target")" 2>/dev/null && pwd)"
    unset _zshrc_target
  else
    DOTFILES_DIR="$HOME/dotfiles"
  fi
fi

export DOTFILES_DIR

# Load wizard-generated feature flags if not already loaded
[[ -f "$HOME/.dotfiles-setup/shell-features.zsh" ]] && \
  source "$HOME/.dotfiles-setup/shell-features.zsh"

# Defaults when features file is absent
: "${DOTFILES_ENABLE_STARSHIP:=1}"
: "${DOTFILES_ENABLE_OMZ:=0}"

[[ -f "$DOTFILES_DIR/.zsh/aliases.zsh" ]] && source "$DOTFILES_DIR/.zsh/aliases.zsh"
[[ -f "$DOTFILES_DIR/.zsh/nvm.zsh" ]] && source "$DOTFILES_DIR/.zsh/nvm.zsh"
[[ -f "$DOTFILES_DIR/.zsh/plugins.zsh" ]] && source "$DOTFILES_DIR/.zsh/plugins.zsh"

# Oh My Zsh (optional — before Starship so Starship can own the prompt in merged mode)
[[ -f "$DOTFILES_DIR/.zsh/oh-my-zsh.zsh" ]] && source "$DOTFILES_DIR/.zsh/oh-my-zsh.zsh"

# Starship (optional)
[[ -f "$DOTFILES_DIR/.zsh/starship.zsh" ]] && source "$DOTFILES_DIR/.zsh/starship.zsh"
