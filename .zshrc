[[ -f $HOME/dotfiles/.zsh/aliases.zsh ]] && source $HOME/dotfiles/.zsh/aliases.zsh
[[ -f $HOME/dotfiles/.zsh/nvm.zsh ]] && source $HOME/dotfiles/.zsh/nvm.zsh

# zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# z
[[ -f $(brew --prefix)/etc/profile.d/z.sh ]] && source $(brew --prefix)/etc/profile.d/z.sh

eval "$(starship init zsh)"
