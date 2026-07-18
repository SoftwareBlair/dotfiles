#!/bin/bash
# Developer software catalog

catalog_register "vscode" \
    "name=VS Code" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Popular code editor" \
    "check=command -v code" \
    "install_brew_macos=brew install --cask visual-studio-code" \
    "install_brew_linux=brew install --cask visual-studio-code" \
    "install_apt=setup_vscode_apt_repo && sudo apt-get install -y code" \
    "install_dnf=sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && sudo sh -c 'echo -e \"[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/vscode.repo' && sudo dnf install -y code" \
    "install_pacman=sudo pacman -S --noconfirm code" \
    "uninstall_brew=brew uninstall --cask visual-studio-code" \
    "uninstall_apt=sudo apt-get remove -y code" \
    "uninstall_dnf=sudo dnf remove -y code" \
    "uninstall_pacman=sudo pacman -R --noconfirm code" \
    "install_dest_macos=/Applications/Visual Studio Code.app" \
    "install_dest_linux=/usr/bin/code" \
    "install_requires_sudo=true"

catalog_register "warp" \
    "name=Warp Terminal" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Modern GPU-accelerated terminal" \
    "check=command -v warp-terminal || command -v warp || test -d /Applications/Warp.app" \
    "install_brew_macos=brew install --cask warp" \
    "install_brew_linux=brew install --cask warp" \
    "install_apt=setup_warp_apt_repo && sudo apt-get install -y warp-terminal" \
    "install_dnf=setup_warp_dnf_repo && sudo dnf install -y warp-terminal" \
    "uninstall_brew=brew uninstall --cask warp" \
    "uninstall_apt=sudo apt-get remove -y warp-terminal" \
    "uninstall_dnf=sudo dnf remove -y warp-terminal" \
    "install_dest_macos=/Applications/Warp.app" \
    "install_dest_linux=/usr/bin/warp-terminal" \
    "install_side_effects=may add Warp apt/dnf repo" \
    "post_symlink=.warp" \
    "install_requires_sudo=true"

catalog_register "zed" \
    "name=Zed" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Fast modern editor" \
    "check=command -v zed || test -d /Applications/Zed.app" \
    "install_brew_macos=brew install --cask zed" \
    "install_brew_linux=brew install zed" \
    "install_script=curl -f https://zed.dev/install.sh | sh" \
    "uninstall_brew=brew uninstall --cask zed || brew uninstall zed" \
    "uninstall_script=rm -rf ~/.local/zed.app ~/.local/bin/zed" \
    "install_dest_macos=/Applications/Zed.app" \
    "install_dest_linux=~/.local/bin/zed" \
    "post_symlink=.config/zed" \
    "install_requires_sudo=false"

catalog_register "jetbrains_toolbox" \
    "name=JetBrains Toolbox" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Install and manage JetBrains IDEs" \
    "check=test -d /Applications/JetBrains\ Toolbox.app || command -v jetbrains-toolbox" \
    "install_brew_macos=brew install --cask jetbrains-toolbox" \
    "install_brew_linux=brew install --cask jetbrains-toolbox" \
    "install_script=install_jetbrains_toolbox" \
    "uninstall_brew=brew uninstall --cask jetbrains-toolbox" \
    "install_dest_macos=/Applications/JetBrains Toolbox.app" \
    "install_dest_linux=~/.local/share/JetBrains/Toolbox" \
    "install_requires_sudo=false"

catalog_register "github_cli" \
    "name=GitHub CLI" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=gh command-line tool" \
    "check=command -v gh" \
    "install_brew_macos=brew install gh" \
    "install_brew_linux=brew install gh" \
    "install_apt=sudo apt-get install -y gh" \
    "install_dnf=sudo dnf install -y gh" \
    "install_pacman=sudo pacman -S --noconfirm github-cli" \
    "uninstall_brew=brew uninstall gh" \
    "uninstall_apt=sudo apt-get remove -y gh" \
    "uninstall_dnf=sudo dnf remove -y gh" \
    "uninstall_pacman=sudo pacman -R --noconfirm github-cli" \
    "install_dest=gh in PATH" \
    "install_requires_sudo=true"

catalog_register "git" \
    "name=Git" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Version control (skip if already present)" \
    "check=command -v git" \
    "install_brew_macos=brew install git" \
    "install_brew_linux=brew install git" \
    "install_apt=sudo apt-get install -y git" \
    "install_dnf=sudo dnf install -y git" \
    "install_pacman=sudo pacman -S --noconfirm git" \
    "uninstall_brew=brew uninstall git" \
    "uninstall_apt=sudo apt-get remove -y git" \
    "uninstall_dnf=sudo dnf remove -y git" \
    "uninstall_pacman=sudo pacman -R --noconfirm git" \
    "install_requires_sudo=true"

catalog_register "raycast" \
    "name=Raycast" \
    "category=dev-tools" \
    "platforms=macos" \
    "description=macOS launcher and productivity (macOS only)" \
    "check=test -d /Applications/Raycast.app" \
    "install_brew_macos=brew install --cask raycast" \
    "uninstall_brew=brew uninstall --cask raycast" \
    "install_dest_macos=/Applications/Raycast.app" \
    "install_requires_sudo=false"

install_jetbrains_toolbox() {
    local name="JetBrains Toolbox"
    local arch_url
    if [[ "$ARCH" == "arm64" ]]; then
        arch_url="https://data.services.jetbrains.com/products/download?code=TBA&platform=linuxARM64"
        [[ "$PLATFORM" == "macos" ]] && arch_url="https://data.services.jetbrains.com/products/download?code=TBA&platform=macM1"
    else
        arch_url="https://data.services.jetbrains.com/products/download?code=TBA&platform=linux"
        [[ "$PLATFORM" == "macos" ]] && arch_url="https://data.services.jetbrains.com/products/download?code=TBA&platform=mac"
    fi

    local cmd="curl -fsSL \"$arch_url\" -o /tmp/jetbrains-toolbox.tgz && tar -xzf /tmp/jetbrains-toolbox.tgz -C /tmp && TOOLBOX_DIR=\$(find /tmp -maxdepth 1 -type d -name 'jetbrains-toolbox-*' | head -1) && mkdir -p \"\$HOME/.local/share/JetBrains/Toolbox\" && cp -R \"\$TOOLBOX_DIR\"/* \"\$HOME/.local/share/JetBrains/Toolbox/\" && (\"\$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox\" &) || true"

    if [[ "$PLATFORM" == "macos" ]]; then
        cmd="open \"$arch_url\" || curl -fsSL \"$arch_url\" -o /tmp/jetbrains-toolbox.dmg"
    fi

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$(catalog_install_dest jetbrains_toolbox)" "" "false" ""
        return 0
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        prompt_info "Downloading JetBrains Toolbox..."
        curl -fsSL "$arch_url" -o /tmp/jetbrains-toolbox.dmg
        prompt_info "Open /tmp/jetbrains-toolbox.dmg to finish installing JetBrains Toolbox."
        open /tmp/jetbrains-toolbox.dmg 2>/dev/null || true
    else
        curl -fsSL "$arch_url" -o /tmp/jetbrains-toolbox.tgz
        tar -xzf /tmp/jetbrains-toolbox.tgz -C /tmp
        local toolbox_dir
        toolbox_dir="$(find /tmp -maxdepth 1 -type d -name 'jetbrains-toolbox-*' | head -1)"
        mkdir -p "$HOME/.local/share/JetBrains/Toolbox"
        cp -R "$toolbox_dir"/* "$HOME/.local/share/JetBrains/Toolbox/"
    fi
    state_log_install "jetbrains_toolbox" "$name" "install" "$cmd" \
        "$(catalog_install_dest jetbrains_toolbox)" "" "" "" ""
}
