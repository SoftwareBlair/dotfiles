#!/bin/bash
# Shell configuration tools used by MY_SETUP

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
    "upgrade_apt=curl -sS https://starship.rs/install.sh | sh -s -- -y" \
    "upgrade_offer=always" \
    "install_dest=starship in PATH" \
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
    "upgrade_script=upgrade_nvm_lts" \
    "upgrade_offer=always" \
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
    "check=test -f \$(brew --prefix 2>/dev/null)/etc/profile.d/z.sh || test -f \$HOME/.z-jump/z.sh || command -v z" \
    "install_brew_macos=brew install z" \
    "install_brew_linux=brew install z" \
    "install_script=install_z_manual" \
    "uninstall_brew=brew uninstall z" \
    "shells=zsh" \
    "install_requires_sudo=false"

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

upgrade_nvm_lts() {
    local cmd='export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm install --lts; nvm alias default lts/*'
    if dry_run_is_active; then
        dry_run_add_step "Update NVM Node LTS" "$cmd" "$HOME/.nvm" "" "false" ""
        return 0
    fi
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        install_nvm_official
        return $?
    fi
    . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
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
    local cmd='git clone https://github.com/rupa/z.git ~/.z-jump'
    if dry_run_is_active; then
        dry_run_add_step "z" "$cmd" "$HOME/.z-jump" "" "false" ""
        return 0
    fi
    if [[ ! -d "$HOME/.z-jump" ]]; then
        git clone https://github.com/rupa/z.git "$HOME/.z-jump"
    fi
    state_log_install "z" "z (jump around)" "install" "$cmd" "$HOME/.z-jump" "" "" "" ""
}
