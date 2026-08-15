#!/bin/bash
# OS / distro / arch detection and platform helpers

detect_platform() {
    case "$(uname -s)" in
        Darwin) PLATFORM="macos" ;;
        Linux)  PLATFORM="linux" ;;
        *)
            echo "Unsupported OS: $(uname -s). Only macOS and Linux are supported." >&2
            exit 1
            ;;
    esac
}

detect_distro() {
    DISTRO="unknown"
    DISTRO_FAMILY="unknown"
    if [[ "$PLATFORM" == "macos" ]]; then
        DISTRO="macos"
        DISTRO_FAMILY="macos"
        return
    fi
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        case "${ID_LIKE:-$ID}" in
            *debian*|*ubuntu*) DISTRO_FAMILY="debian" ;;
            *fedora*|*rhel*|*centos*) DISTRO_FAMILY="fedora" ;;
            *arch*) DISTRO_FAMILY="arch" ;;
            *)
                case "$ID" in
                    debian|ubuntu|pop|linuxmint) DISTRO_FAMILY="debian" ;;
                    fedora|rhel|centos|rocky|almalinux) DISTRO_FAMILY="fedora" ;;
                    arch|manjaro|endeavouros) DISTRO_FAMILY="arch" ;;
                    *) DISTRO_FAMILY="unknown" ;;
                esac
                ;;
        esac
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) ARCH="$(uname -m)" ;;
    esac
}

font_dir() {
    if [[ "$PLATFORM" == "macos" ]]; then
        echo "$HOME/Library/Fonts"
    else
        echo "$HOME/.local/share/fonts"
    fi
}

available_pkgmgrs() {
    local mgrs=()
    mgrs+=("brew")
    if [[ "$PLATFORM" == "linux" ]]; then
        [[ "$DISTRO_FAMILY" == "debian" ]] && command -v apt-get &>/dev/null && mgrs+=("apt")
        [[ "$DISTRO_FAMILY" == "fedora" ]] && command -v dnf &>/dev/null && mgrs+=("dnf")
        [[ "$DISTRO_FAMILY" == "arch" ]] && command -v pacman &>/dev/null && mgrs+=("pacman")
    fi
    printf '%s\n' "${mgrs[@]}"
}

platform_label() {
    if [[ "$PLATFORM" == "macos" ]]; then
        echo "macOS · ${ARCH}"
    else
        echo "Linux · ${DISTRO} · ${ARCH}"
    fi
}

init_platform() {
    detect_platform
    detect_distro
    detect_arch
    STATE_DIR="${STATE_DIR:-$HOME/.dotfiles-setup}"
    INSTALL_LOG="${INSTALL_LOG:-$STATE_DIR/install-log.jsonl}"
    BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups}"
    SETUP_CONF="${SETUP_CONF:-$HOME/.dotfiles-setup.conf}"
}

platform_supports() {
    local platforms="$1"
    [[ -z "$platforms" ]] && return 0
    [[ ",$platforms," == *",$PLATFORM,"* ]] && return 0
    return 1
}
