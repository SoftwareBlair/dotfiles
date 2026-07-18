#!/bin/bash
# Developer software catalog — tools used by MY_SETUP

catalog_register "cursor" \
    "name=Cursor" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Default AI code editor" \
    "check=command -v cursor || test -d /Applications/Cursor.app" \
    "install_brew_macos=brew install --cask cursor" \
    "install_brew_linux=brew install --cask cursor" \
    "install_apt=setup_cursor_apt_repo && sudo apt-get install -y cursor" \
    "install_dnf=setup_cursor_dnf_repo && sudo dnf install -y cursor" \
    "uninstall_brew=brew uninstall --cask cursor" \
    "uninstall_apt=sudo apt-get remove -y cursor" \
    "uninstall_dnf=sudo dnf remove -y cursor" \
    "install_dest_macos=/Applications/Cursor.app" \
    "install_dest_linux=/usr/bin/cursor" \
    "install_side_effects=may add Cursor apt/dnf repo" \
    "install_requires_sudo=true"

catalog_register "vscode" \
    "name=VS Code" \
    "category=dev-tools" \
    "platforms=macos,linux" \
    "description=Popular code editor (optional)" \
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
    "upgrade_script=curl -f https://zed.dev/install.sh | sh" \
    "upgrade_offer=always" \
    "install_dest_macos=/Applications/Zed.app" \
    "install_dest_linux=~/.local/bin/zed" \
    "install_requires_sudo=false"

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
