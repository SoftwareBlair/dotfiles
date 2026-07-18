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

# Refresh package metadata once per run (before outdated checks)
PKGMGR_REFRESHED=""

pkgmgr_refresh_metadata() {
    [[ -n "${PKGMGR_REFRESHED:-}" ]] && return 0
    PKGMGR_REFRESHED=1

    case "${PKG_MGR:-}" in
        brew)
            if ! command -v brew &>/dev/null; then
                return 0
            fi
            if dry_run_is_active; then
                return 0
            fi
            prompt_info "Refreshing Homebrew formulae/casks…"
            brew update --quiet 2>/dev/null || brew update || true
            ;;
        apt)
            if dry_run_is_active; then
                return 0
            fi
            prompt_info "Refreshing apt package lists…"
            sudo apt-get update -qq 2>/dev/null || sudo apt-get update || true
            ;;
        dnf)
            # dnf check-update refreshes metadata as needed
            ;;
        pacman)
            if dry_run_is_active; then
                return 0
            fi
            prompt_info "Refreshing pacman sync database…"
            sudo pacman -Sy --noconfirm 2>/dev/null || true
            ;;
    esac
}

# kind: cask | formula | native
# Returns 0 when an update is available for pkg
pkgmgr_package_outdated() {
    local kind="$1"
    local pkg="$2"
    [[ -z "$pkg" ]] && return 1

    case "${PKG_MGR:-}" in
        brew)
            command -v brew &>/dev/null || return 1
            if [[ "$kind" == "cask" ]]; then
                brew list --cask "$pkg" &>/dev/null || return 1
                brew outdated --cask --quiet "$pkg" 2>/dev/null | grep -qx "$pkg"
            else
                brew list --formula "$pkg" &>/dev/null || return 1
                brew outdated --formula --quiet "$pkg" 2>/dev/null | grep -qx "$pkg"
            fi
            ;;
        apt)
            dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || return 1
            local installed candidate
            installed="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Installed:/ {print $2; exit}')"
            candidate="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
            [[ -n "$installed" && -n "$candidate" ]] || return 1
            [[ "$installed" != "(none)" && "$candidate" != "(none)" ]] || return 1
            [[ "$installed" != "$candidate" ]]
            ;;
        dnf)
            rpm -q "$pkg" &>/dev/null || return 1
            # dnf check-update: 100 = updates available, 0 = none, 1 = error
            dnf check-update "$pkg" &>/dev/null
            local ec=$?
            [[ "$ec" -eq 100 ]]
            ;;
        pacman)
            pacman -Q "$pkg" &>/dev/null || return 1
            pacman -Qu "$pkg" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Setup Cursor apt repo (https://downloads.cursor.com/aptrepo)
setup_cursor_apt_repo() {
    local cmd='sudo apt-get install -y curl gpg && sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://downloads.cursor.com/keys/anysphere.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/cursor.gpg > /dev/null && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main" | sudo tee /etc/apt/sources.list.d/cursor.list > /dev/null && sudo apt-get update'
    if dry_run_is_active; then
        dry_run_add_step "Cursor apt repo" "$cmd" "/etc/apt/sources.list.d/cursor.list" "adds Cursor apt repo" "true" ""
        return 0
    fi
    eval "$cmd"
    state_log_install "cursor-apt-repo" "Cursor apt repo" "repo" "$cmd" \
        "/etc/apt/sources.list.d/cursor.list" "/etc/apt/sources.list.d/cursor.list" "" "" ""
}

setup_cursor_dnf_repo() {
    local cmd='sudo sh -c '"'"'echo -e "[cursor]\nname=Cursor\nbaseurl=https://downloads.cursor.com/yumrepo\nenabled=1\ngpgcheck=1\ngpgkey=https://downloads.cursor.com/keys/anysphere.asc" > /etc/yum.repos.d/cursor.repo'"'"''
    if dry_run_is_active; then
        dry_run_add_step "Cursor dnf repo" "$cmd" "/etc/yum.repos.d/cursor.repo" "adds Cursor dnf repo" "true" ""
        return 0
    fi
    eval "$cmd"
    state_log_install "cursor-dnf-repo" "Cursor dnf repo" "repo" "$cmd" \
        "/etc/yum.repos.d/cursor.repo" "/etc/yum.repos.d/cursor.repo" "" "" ""
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
