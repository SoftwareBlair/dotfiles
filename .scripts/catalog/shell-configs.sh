#!/bin/bash
# Shell configuration tools

catalog_register "starship" \
    "name=Starship" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Cross-shell prompt (works best with a Nerd Font)" \
    "check=command -v starship" \
    "install_brew_macos=brew install starship" \
    "install_brew_linux=brew install starship" \
    "install_apt=curl -sS https://starship.rs/install.sh | sh -s -- -y" \
    "install_dnf=sudo dnf install -y starship || curl -sS https://starship.rs/install.sh | sh -s -- -y" \
    "install_pacman=sudo pacman -S --noconfirm starship" \
    "uninstall_brew=brew uninstall starship" \
    "uninstall_script=rm -f ~/.local/bin/starship /usr/local/bin/starship" \
    "install_dest=starship in PATH" \
    "shells=zsh" \
    "install_requires_sudo=false"

catalog_register "oh_my_zsh" \
    "name=Oh My Zsh" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=zsh framework with plugins and themes" \
    "check=test -d \$HOME/.oh-my-zsh" \
    "install_script=install_oh_my_zsh" \
    "uninstall_script=uninstall_oh_my_zsh" \
    "install_dest=~/.oh-my-zsh" \
    "shells=zsh" \
    "install_requires_sudo=false"

catalog_register "eza" \
    "name=eza" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Modern ls replacement (exa successor)" \
    "check=command -v eza" \
    "install_brew_macos=brew install eza" \
    "install_brew_linux=brew install eza" \
    "install_apt=sudo apt-get install -y eza || cargo install eza" \
    "install_dnf=sudo dnf install -y eza" \
    "install_pacman=sudo pacman -S --noconfirm eza" \
    "uninstall_brew=brew uninstall eza" \
    "uninstall_apt=sudo apt-get remove -y eza" \
    "uninstall_dnf=sudo dnf remove -y eza" \
    "uninstall_pacman=sudo pacman -R --noconfirm eza" \
    "install_dest=eza in PATH" \
    "shells=zsh" \
    "install_requires_sudo=true"

catalog_register "nvm" \
    "name=NVM + Node LTS" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Node Version Manager with Node LTS" \
    "check=test -s \$HOME/.nvm/nvm.sh || (command -v brew >/dev/null && brew --prefix nvm >/dev/null 2>&1)" \
    "install_script=install_nvm_official" \
    "uninstall_script=uninstall_nvm_official" \
    "install_dest=~/.nvm" \
    "shells=zsh" \
    "install_requires_sudo=false"

catalog_register "zsh_autosuggestions" \
    "name=zsh-autosuggestions" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Fish-like autosuggestions for zsh" \
    "check=test -f \$(brew --prefix 2>/dev/null)/share/zsh-autosuggestions/zsh-autosuggestions.zsh || test -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "install_brew_macos=brew install zsh-autosuggestions" \
    "install_brew_linux=brew install zsh-autosuggestions" \
    "install_apt=sudo apt-get install -y zsh-autosuggestions" \
    "install_dnf=sudo dnf install -y zsh-autosuggestions" \
    "install_pacman=sudo pacman -S --noconfirm zsh-autosuggestions" \
    "uninstall_brew=brew uninstall zsh-autosuggestions" \
    "uninstall_apt=sudo apt-get remove -y zsh-autosuggestions" \
    "shells=zsh" \
    "install_requires_sudo=true"

catalog_register "zsh_syntax_highlighting" \
    "name=zsh-syntax-highlighting" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Syntax highlighting for zsh" \
    "check=test -d \$(brew --prefix 2>/dev/null)/share/zsh-syntax-highlighting || test -d /usr/share/zsh-syntax-highlighting" \
    "install_brew_macos=brew install zsh-syntax-highlighting" \
    "install_brew_linux=brew install zsh-syntax-highlighting" \
    "install_apt=sudo apt-get install -y zsh-syntax-highlighting" \
    "install_dnf=sudo dnf install -y zsh-syntax-highlighting" \
    "install_pacman=sudo pacman -S --noconfirm zsh-syntax-highlighting" \
    "uninstall_brew=brew uninstall zsh-syntax-highlighting" \
    "uninstall_apt=sudo apt-get remove -y zsh-syntax-highlighting" \
    "shells=zsh" \
    "install_requires_sudo=true"

catalog_register "z" \
    "name=z (jump around)" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Tracks frequent dirs for quick cd" \
    "check=test -f \$(brew --prefix 2>/dev/null)/etc/profile.d/z.sh || command -v z" \
    "install_brew_macos=brew install z" \
    "install_brew_linux=brew install z" \
    "install_script=install_z_manual" \
    "uninstall_brew=brew uninstall z" \
    "shells=zsh" \
    "install_requires_sudo=false"

catalog_register "fzf" \
    "name=fzf" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Fuzzy finder" \
    "check=command -v fzf" \
    "install_brew_macos=brew install fzf" \
    "install_brew_linux=brew install fzf" \
    "install_apt=sudo apt-get install -y fzf" \
    "install_dnf=sudo dnf install -y fzf" \
    "install_pacman=sudo pacman -S --noconfirm fzf" \
    "uninstall_brew=brew uninstall fzf" \
    "uninstall_apt=sudo apt-get remove -y fzf" \
    "uninstall_dnf=sudo dnf remove -y fzf" \
    "uninstall_pacman=sudo pacman -R --noconfirm fzf" \
    "shells=zsh" \
    "install_requires_sudo=true"

catalog_register "zoxide" \
    "name=zoxide" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Smarter cd" \
    "check=command -v zoxide" \
    "install_brew_macos=brew install zoxide" \
    "install_brew_linux=brew install zoxide" \
    "install_apt=sudo apt-get install -y zoxide || curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" \
    "install_dnf=sudo dnf install -y zoxide" \
    "install_pacman=sudo pacman -S --noconfirm zoxide" \
    "uninstall_brew=brew uninstall zoxide" \
    "uninstall_apt=sudo apt-get remove -y zoxide" \
    "shells=zsh" \
    "install_requires_sudo=true"

catalog_register "bat" \
    "name=bat" \
    "category=shell-configs" \
    "platforms=macos,linux" \
    "description=Better cat with syntax highlighting" \
    "check=command -v bat || command -v batcat" \
    "install_brew_macos=brew install bat" \
    "install_brew_linux=brew install bat" \
    "install_apt=sudo apt-get install -y bat" \
    "install_dnf=sudo dnf install -y bat" \
    "install_pacman=sudo pacman -S --noconfirm bat" \
    "uninstall_brew=brew uninstall bat" \
    "uninstall_apt=sudo apt-get remove -y bat" \
    "shells=zsh" \
    "install_requires_sudo=true"

install_oh_my_zsh() {
    local cmd='export RUNZSH=no CHSH=no; sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    if dry_run_is_active; then
        dry_run_add_step "Oh My Zsh" "$cmd" "$HOME/.oh-my-zsh" "clones to ~/.oh-my-zsh" "false" ""
        return 0
    fi
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        prompt_info "Oh My Zsh already installed."
        return 0
    fi
    export RUNZSH=no CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    state_log_install "oh_my_zsh" "Oh My Zsh" "install" "$cmd" "$HOME/.oh-my-zsh" "" "" "" ""
}

uninstall_oh_my_zsh() {
    local cmd="rm -rf \$HOME/.oh-my-zsh"
    if dry_run_is_active; then
        dry_run_add_step "Undo: Oh My Zsh" "$cmd" "$HOME/.oh-my-zsh" "" "false" ""
        return 0
    fi
    rm -rf "$HOME/.oh-my-zsh"
}

install_nvm_official() {
    local cmd='curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh" && nvm install --lts && nvm alias default lts/*'
    if dry_run_is_active; then
        dry_run_add_step "NVM + Node LTS" "$cmd" "$HOME/.nvm" "installs Node LTS" "false" ""
        return 0
    fi
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
    state_log_install "nvm" "NVM + Node LTS" "install" "$cmd" "$HOME/.nvm" "" "" "" ""
}

uninstall_nvm_official() {
    local cmd="rm -rf \$HOME/.nvm \$HOME/.npm"
    if dry_run_is_active; then
        dry_run_add_step "Undo: NVM" "$cmd" "$HOME/.nvm" "" "false" ""
        return 0
    fi
    rm -rf "$HOME/.nvm" "$HOME/.npm"
    if command -v brew &>/dev/null && brew list nvm &>/dev/null; then
        brew uninstall nvm || true
    fi
}

install_z_manual() {
    local cmd='git clone https://github.com/rupa/z.git ~/.z-jump && echo "# >>> dotfiles-setup >>>\n. \$HOME/.z-jump/z.sh\n# <<< dotfiles-setup <<<" >> ~/.zshrc'
    if dry_run_is_active; then
        dry_run_add_step "z" "$cmd" "$HOME/.z-jump" "appends to ~/.zshrc" "false" ""
        return 0
    fi
    if [[ ! -d "$HOME/.z-jump" ]]; then
        git clone https://github.com/rupa/z.git "$HOME/.z-jump"
    fi
    state_log_install "z" "z (jump around)" "install" "$cmd" "$HOME/.z-jump" "" "" "" ""
}
