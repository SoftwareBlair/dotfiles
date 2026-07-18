#!/bin/bash
# Package manager backends: brew, apt, dnf, pacman

ensure_brew_shellenv() {
    if command -v brew &>/dev/null; then
        eval "$(brew shellenv)"
        return 0
    fi
    # Common install locations
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        return 0
    fi
    if [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
        return 0
    fi
    return 1
}

ensure_pkgmgr() {
    local mgr="${1:-$PKG_MGR}"
    case "$mgr" in
        brew)
            if ensure_brew_shellenv; then
                return 0
            fi
            if dry_run_is_active; then
                dry_run_add_step "Homebrew" \
                    '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
                    "$( [[ "$PLATFORM" == "macos" ]] && echo /opt/homebrew || echo /home/linuxbrew/.linuxbrew )" \
                    "adds brew shellenv to ~/.zprofile" \
                    "true" ""
                return 0
            fi
            prompt_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            ensure_brew_shellenv || return 1
            local brew_prefix
            brew_prefix="$(brew --prefix)"
            local marker_start="# >>> dotfiles-setup >>>"
            local marker_end="# <<< dotfiles-setup <<<"
            if ! grep -q "$marker_start" "$HOME/.zprofile" 2>/dev/null; then
                {
                    echo ""
                    echo "$marker_start"
                    echo "eval \"\$($brew_prefix/bin/brew shellenv)\""
                    echo "$marker_end"
                } >> "$HOME/.zprofile"
                state_log_install "brew-shellenv" "Homebrew shellenv" "config" \
                    "append brew shellenv to ~/.zprofile" "$HOME/.zprofile" \
                    "$HOME/.zprofile" "" "" ""
            fi
            state_log_install "homebrew" "Homebrew" "install" \
                "Homebrew install script" "$brew_prefix" "" "" "" ""
            ;;
        apt)
            command -v apt-get &>/dev/null || { prompt_error "apt-get not found"; return 1; }
            ;;
        dnf)
            command -v dnf &>/dev/null || { prompt_error "dnf not found"; return 1; }
            ;;
        pacman)
            command -v pacman &>/dev/null || { prompt_error "pacman not found"; return 1; }
            ;;
        *)
            prompt_error "Unknown package manager: $mgr"
            return 1
            ;;
    esac
}

pkgmgr_install() {
    local packages="$1"
    local requires_sudo="${2:-true}"
    local name="${3:-$packages}"
    local dest="${4:-}"
    local side_effects="${5:-}"

    local cmd=""
    case "$PKG_MGR" in
        brew) cmd="brew install $packages" ; requires_sudo="false" ;;
        apt) cmd="sudo apt-get install -y $packages" ;;
        dnf) cmd="sudo dnf install -y $packages" ;;
        pacman) cmd="sudo pacman -S --noconfirm $packages" ;;
        *) prompt_error "No package manager selected"; return 1 ;;
    esac

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$dest" "$side_effects" "$requires_sudo" ""
        return 0
    fi

    if ! eval "$cmd"; then
        prompt_error "Failed to install: $packages"
        return 1
    fi
    state_log_install "$(echo "$packages" | awk '{print $1}')" "$name" "install" \
        "$cmd" "$dest" "$side_effects" "" "" ""
}

pkgmgr_install_cask() {
    local cask="$1"
    local name="${2:-$cask}"
    local dest="${3:-}"
    local cmd="brew install --cask $cask"

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$dest" "" "false" ""
        return 0
    fi

    if ! eval "$cmd"; then
        prompt_error "Failed to install cask: $cask"
        return 1
    fi
    state_log_install "$cask" "$name" "install" "$cmd" "$dest" "" "" "" ""
}

pkgmgr_uninstall() {
    local packages="$1"
    local name="${2:-$packages}"

    local cmd=""
    case "$PKG_MGR" in
        brew) cmd="brew uninstall $packages" ;;
        apt) cmd="sudo apt-get remove -y $packages" ;;
        dnf) cmd="sudo dnf remove -y $packages" ;;
        pacman) cmd="sudo pacman -R --noconfirm $packages" ;;
        *) prompt_error "No package manager selected"; return 1 ;;
    esac

    if dry_run_is_active; then
        dry_run_add_step "Undo: $name" "$cmd" "" "" "true" ""
        return 0
    fi

    eval "$cmd" || true
}

pkgmgr_uninstall_cask() {
    local cask="$1"
    local name="${2:-$cask}"
    local cmd="brew uninstall --cask $cask"

    if dry_run_is_active; then
        dry_run_add_step "Undo: $name" "$cmd" "" "" "false" ""
        return 0
    fi
    eval "$cmd" || true
}

pkgmgr_installed() {
    local check_cmd="$1"
    if [[ -z "$check_cmd" ]]; then
        return 1
    fi
    eval "$check_cmd" &>/dev/null
}

pkgmgr_upgrade() {
    local packages="$1"
    case "$PKG_MGR" in
        brew) brew upgrade $packages ;;
        apt) sudo apt-get install --only-upgrade -y $packages ;;
        dnf) sudo dnf upgrade -y $packages ;;
        pacman) sudo pacman -Syu --noconfirm $packages ;;
    esac
}

# Setup Microsoft VS Code apt repo
setup_vscode_apt_repo() {
    local cmd='wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg && sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c '"'"'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'"'"' && sudo apt-get update'
    if dry_run_is_active; then
        dry_run_add_step "VS Code apt repo" "$cmd" "/etc/apt/sources.list.d/vscode.list" "adds Microsoft apt repo" "true" ""
        return 0
    fi
    eval "$cmd"
    state_log_install "vscode-apt-repo" "VS Code apt repo" "repo" "$cmd" \
        "/etc/apt/sources.list.d/vscode.list" "/etc/apt/sources.list.d/vscode.list" "" "" ""
}

setup_warp_apt_repo() {
    local cmd='sudo apt-get install -y wget gpg && wget -qO- https://releases.warp.dev/linux/keys/warp.asc | gpg --dearmor > /tmp/warpdotdev.gpg && sudo install -D -o root -g root -m 644 /tmp/warpdotdev.gpg /etc/apt/keyrings/warpdotdev.gpg && sudo sh -c '"'"'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/warpdotdev.gpg] https://releases.warp.dev/linux/deb stable main" > /etc/apt/sources.list.d/warpdotdev.list'"'"' && sudo apt-get update'
    if dry_run_is_active; then
        dry_run_add_step "Warp apt repo" "$cmd" "/etc/apt/sources.list.d/warpdotdev.list" "adds Warp apt repo" "true" ""
        return 0
    fi
    eval "$cmd"
    state_log_install "warp-apt-repo" "Warp apt repo" "repo" "$cmd" \
        "/etc/apt/sources.list.d/warpdotdev.list" "/etc/apt/sources.list.d/warpdotdev.list" "" "" ""
}

setup_warp_dnf_repo() {
    local cmd='sudo rpm --import https://releases.warp.dev/linux/keys/warp.asc && sudo sh -c '"'"'echo -e "[warpdotdev]\nname=warpdotdev\nbaseurl=https://releases.warp.dev/linux/rpm/stable\nenabled=1\ngpgcheck=1\ngpgkey=https://releases.warp.dev/linux/keys/warp.asc" > /etc/yum.repos.d/warpdotdev.repo'"'"''
    if dry_run_is_active; then
        dry_run_add_step "Warp dnf repo" "$cmd" "/etc/yum.repos.d/warpdotdev.repo" "adds Warp dnf repo" "true" ""
        return 0
    fi
    eval "$cmd"
    state_log_install "warp-dnf-repo" "Warp dnf repo" "repo" "$cmd" \
        "/etc/yum.repos.d/warpdotdev.repo" "/etc/yum.repos.d/warpdotdev.repo" "" "" ""
}
