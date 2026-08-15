#!/bin/bash
# Browser casks (opt-in in the app picker)

catalog_register "chrome" \
    "name=Google Chrome" \
    "category=browsers" \
    "platforms=macos,linux" \
    "description=Google Chrome browser" \
    "check=command -v google-chrome || command -v google-chrome-stable || test -d '/Applications/Google Chrome.app'" \
    "install_brew_macos=brew install --cask google-chrome" \
    "install_brew_linux=brew install --cask google-chrome" \
    "uninstall_brew=brew uninstall --cask google-chrome" \
    "pkg_brew_cask=google-chrome" \
    "install_dest_macos=/Applications/Google Chrome.app" \
    "install_requires_sudo=false"

catalog_register "firefox" \
    "name=Firefox" \
    "category=browsers" \
    "platforms=macos,linux" \
    "description=Mozilla Firefox browser" \
    "check=command -v firefox || test -d /Applications/Firefox.app" \
    "install_brew_macos=brew install --cask firefox" \
    "install_brew_linux=brew install --cask firefox" \
    "uninstall_brew=brew uninstall --cask firefox" \
    "pkg_brew_cask=firefox" \
    "install_dest_macos=/Applications/Firefox.app" \
    "install_requires_sudo=false"

catalog_register "zen" \
    "name=Zen Browser" \
    "category=browsers" \
    "platforms=macos,linux" \
    "description=Gecko-based Zen Browser" \
    "check=command -v zen || test -d /Applications/Zen.app" \
    "install_brew_macos=brew install --cask zen" \
    "install_brew_linux=brew install --cask zen" \
    "uninstall_brew=brew uninstall --cask zen" \
    "pkg_brew_cask=zen" \
    "install_dest_macos=/Applications/Zen.app" \
    "install_requires_sudo=false"

catalog_register "helium" \
    "name=Helium" \
    "category=browsers" \
    "platforms=macos,linux" \
    "description=Chromium-based Helium browser" \
    "check=test -d /Applications/Helium.app || command -v helium" \
    "install_brew_macos=brew install --cask helium-browser" \
    "install_brew_linux=brew install --cask helium-browser" \
    "uninstall_brew=brew uninstall --cask helium-browser" \
    "pkg_brew_cask=helium-browser" \
    "install_dest_macos=/Applications/Helium.app" \
    "install_requires_sudo=false"
