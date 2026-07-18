#!/bin/bash
# Shell catalog — zsh only for now (no bash, no fish)

catalog_register "zsh" \
    "name=zsh" \
    "category=shells" \
    "platforms=macos,linux" \
    "description=Powerful interactive shell (default on modern macOS)" \
    "check=command -v zsh" \
    "install_brew_macos=brew install zsh" \
    "install_brew_linux=brew install zsh" \
    "install_apt=sudo apt-get install -y zsh" \
    "install_dnf=sudo dnf install -y zsh" \
    "install_pacman=sudo pacman -S --noconfirm zsh" \
    "uninstall_brew=brew uninstall zsh" \
    "uninstall_apt=sudo apt-get remove -y zsh" \
    "uninstall_dnf=sudo dnf remove -y zsh" \
    "uninstall_pacman=sudo pacman -R --noconfirm zsh" \
    "install_dest=/bin/zsh or brew prefix" \
    "post_chsh=true" \
    "install_requires_sudo=true"
