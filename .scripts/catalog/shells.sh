#!/bin/bash
# Shell catalog — zsh and fish only (no bash)

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

catalog_register "fish" \
    "name=fish" \
    "category=shells" \
    "platforms=macos,linux" \
    "description=Friendly interactive shell" \
    "check=command -v fish" \
    "install_brew_macos=brew install fish" \
    "install_brew_linux=brew install fish" \
    "install_apt=sudo apt-get install -y fish" \
    "install_dnf=sudo dnf install -y fish" \
    "install_pacman=sudo pacman -S --noconfirm fish" \
    "uninstall_brew=brew uninstall fish" \
    "uninstall_apt=sudo apt-get remove -y fish" \
    "uninstall_dnf=sudo dnf remove -y fish" \
    "uninstall_pacman=sudo pacman -R --noconfirm fish" \
    "install_dest=fish in PATH" \
    "post_chsh=true" \
    "post_symlink=.config/fish" \
    "install_requires_sudo=true"
