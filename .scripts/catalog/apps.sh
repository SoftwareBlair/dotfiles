#!/bin/bash
# Productivity / chat / media apps (opt-in)

catalog_register "onepassword" \
    "name=1Password" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=1Password password manager" \
    "check=test -d /Applications/1Password.app || command -v 1password" \
    "install_brew_macos=brew install --cask 1password" \
    "install_brew_linux=brew install --cask 1password" \
    "uninstall_brew=brew uninstall --cask 1password" \
    "pkg_brew_cask=1password" \
    "install_dest_macos=/Applications/1Password.app" \
    "install_requires_sudo=false"

catalog_register "onepassword_cli" \
    "name=1Password CLI" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=1Password command-line tool (op)" \
    "check=command -v op" \
    "install_brew_macos=brew install --cask 1password-cli" \
    "install_brew_linux=brew install --cask 1password-cli" \
    "uninstall_brew=brew uninstall --cask 1password-cli" \
    "pkg_brew_cask=1password-cli" \
    "install_requires_sudo=false"

catalog_register "discord" \
    "name=Discord" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=Discord chat" \
    "check=test -d /Applications/Discord.app || command -v discord" \
    "install_brew_macos=brew install --cask discord" \
    "install_brew_linux=brew install --cask discord" \
    "uninstall_brew=brew uninstall --cask discord" \
    "pkg_brew_cask=discord" \
    "install_dest_macos=/Applications/Discord.app" \
    "install_requires_sudo=false"

catalog_register "slack" \
    "name=Slack" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=Slack messaging" \
    "check=test -d /Applications/Slack.app || command -v slack" \
    "install_brew_macos=brew install --cask slack" \
    "install_brew_linux=brew install --cask slack" \
    "uninstall_brew=brew uninstall --cask slack" \
    "pkg_brew_cask=slack" \
    "install_dest_macos=/Applications/Slack.app" \
    "install_requires_sudo=false"

catalog_register "signal" \
    "name=Signal" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=Signal Private Messenger" \
    "check=test -d /Applications/Signal.app || command -v signal-desktop" \
    "install_brew_macos=brew install --cask signal" \
    "install_brew_linux=brew install --cask signal" \
    "uninstall_brew=brew uninstall --cask signal" \
    "pkg_brew_cask=signal" \
    "install_dest_macos=/Applications/Signal.app" \
    "install_requires_sudo=false"

catalog_register "vlc" \
    "name=VLC" \
    "category=apps" \
    "platforms=macos,linux" \
    "description=VLC media player" \
    "check=test -d /Applications/VLC.app || command -v vlc" \
    "install_brew_macos=brew install --cask vlc" \
    "install_brew_linux=brew install --cask vlc" \
    "uninstall_brew=brew uninstall --cask vlc" \
    "pkg_brew_cask=vlc" \
    "install_dest_macos=/Applications/VLC.app" \
    "install_requires_sudo=false"
