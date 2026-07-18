[[ -f $HOME/dotfiles/.zsh/aliases.zsh ]] && source $HOME/dotfiles/.zsh/aliases.zsh
[[ -f $HOME/dotfiles/.zsh/nvm.zsh ]] && source $HOME/dotfiles/.zsh/nvm.zsh

# zsh-autosuggestions (Homebrew or system paths)
if command -v brew >/dev/null 2>&1; then
  [[ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -d "$(brew --prefix)/share/zsh-syntax-highlighting" ]] && \
    source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [[ -f "$(brew --prefix)/etc/profile.d/z.sh" ]] && \
    source "$(brew --prefix)/etc/profile.d/z.sh"
fi
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f "$HOME/.z-jump/z.sh" ]] && source "$HOME/.z-jump/z.sh"

# zoxide (if installed)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
