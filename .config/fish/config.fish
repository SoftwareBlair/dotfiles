# Fish config stub for dotfiles setup wizard

set -gx STARSHIP_CONFIG "$HOME/dotfiles/.config/starship.toml"

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish | source
end

if type -q eza
    alias l='eza --all --binary --long --group --header --git --group-directories-first --icons'
    alias grid='eza --grid --all --binary --long --group --header --git --group-directories-first --icons'
end

set -gx NVM_DIR "$HOME/.nvm"
if test -s "$NVM_DIR/nvm.sh"
    # nvm is bash-oriented; use bass or fnm/nvm.fish plugins if needed
end
