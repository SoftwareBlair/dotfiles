# Fish config stub for dotfiles setup wizard

if test -z "$DOTFILES_DIR"
    if test -d "$HOME/dotfiles"
        set -gx DOTFILES_DIR "$HOME/dotfiles"
    else
        set -gx DOTFILES_DIR "$HOME/dotfiles"
    end
end

set -gx STARSHIP_CONFIG "$DOTFILES_DIR/.config/starship.toml"

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
