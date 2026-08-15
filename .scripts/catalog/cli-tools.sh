#!/bin/bash
# CLI / language tooling (brew formulas & casks)

catalog_register "gh" \
    "name=GitHub CLI" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=GitHub command-line tool (gh)" \
    "check=command -v gh" \
    "install_brew_macos=brew install gh" \
    "install_brew_linux=brew install gh" \
    "uninstall_brew=brew uninstall gh" \
    "pkg_brew=gh" \
    "install_dest=/opt/homebrew/bin/gh" \
    "install_requires_sudo=false"

catalog_register "wget" \
    "name=wget" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Non-interactive network downloader" \
    "check=command -v wget" \
    "install_brew_macos=brew install wget" \
    "install_brew_linux=brew install wget" \
    "uninstall_brew=brew uninstall wget" \
    "pkg_brew=wget" \
    "install_requires_sudo=false"

catalog_register "curl_brew" \
    "name=curl (Homebrew)" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Homebrew curl (system curl often already exists)" \
    "check=brew list curl &>/dev/null" \
    "install_brew_macos=brew install curl" \
    "install_brew_linux=brew install curl" \
    "uninstall_brew=brew uninstall curl" \
    "pkg_brew=curl" \
    "install_requires_sudo=false"

catalog_register "docker" \
    "name=Docker" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Docker Desktop / engine via Homebrew" \
    "check=command -v docker || test -d /Applications/Docker.app" \
    "install_brew_macos=brew install --cask docker" \
    "install_brew_linux=brew install --cask docker" \
    "uninstall_brew=brew uninstall --cask docker" \
    "pkg_brew_cask=docker" \
    "install_dest_macos=/Applications/Docker.app" \
    "install_requires_sudo=false"

catalog_register "python" \
    "name=Python" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Homebrew Python 3" \
    "check=brew list python &>/dev/null || brew list python@3 &>/dev/null" \
    "install_brew_macos=brew install python" \
    "install_brew_linux=brew install python" \
    "uninstall_brew=brew uninstall python" \
    "pkg_brew=python" \
    "install_requires_sudo=false"

catalog_register "go" \
    "name=Go" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Go programming language" \
    "check=command -v go" \
    "install_brew_macos=brew install go" \
    "install_brew_linux=brew install go" \
    "uninstall_brew=brew uninstall go" \
    "pkg_brew=go" \
    "install_requires_sudo=false"

catalog_register "pnpm" \
    "name=pnpm" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Fast Node package manager" \
    "check=command -v pnpm" \
    "install_brew_macos=brew install pnpm" \
    "install_brew_linux=brew install pnpm" \
    "uninstall_brew=brew uninstall pnpm" \
    "pkg_brew=pnpm" \
    "install_requires_sudo=false"

catalog_register "yarn" \
    "name=Yarn" \
    "category=cli-tools" \
    "platforms=macos,linux" \
    "description=Node package manager (Yarn)" \
    "check=command -v yarn" \
    "install_brew_macos=brew install yarn" \
    "install_brew_linux=brew install yarn" \
    "uninstall_brew=brew uninstall yarn" \
    "pkg_brew=yarn" \
    "install_requires_sudo=false"
