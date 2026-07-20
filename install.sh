#!/usr/bin/env bash
# One-liner bootstrap for SoftwareBlair/dotfiles
#
# Recommended (keeps your terminal stdin free for the wizard):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
#
# Or download then run:
#   curl -fsSL …/install.sh -o /tmp/install-dotfiles.sh && bash /tmp/install-dotfiles.sh
#
# Env knobs (CLI flags below override when set):
#   DOTFILES_REPO   GitHub owner/name          (default: SoftwareBlair/dotfiles)
#   DOTFILES_REF    branch or tag              (default: main)
#   DOTFILES_DIR    install location           (default: ~/dotfiles)
#   DOTFILES_BASH=1 force classic bash prompts
#   DOTFILES_DRY_RUN=1  pass -n to setup
#   DOTFILES_YES=1      pass -y to setup
#   DOTFILES_PKGMGR     pass --pkgmgr <name>
#   DOTFILES_PROFILE    pass --profile <GitHubUser> (e.g. SoftwareBlair)
#   DOTFILES_SKIP_TUI=1 skip downloading the TUI binary
set -uo pipefail

REPO="${DOTFILES_REPO:-SoftwareBlair/dotfiles}"
REF="${DOTFILES_REF:-main}"
DEST="${DOTFILES_DIR:-$HOME/dotfiles}"
RELEASE_REPO="${DOTFILES_RELEASE_REPO:-$REPO}"

info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'warning: %s\n' "$*" >&2; }
die()   { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Install the dotfiles-setup CLI and run the new-machine wizard.

Usage:
  install.sh [options]

Options:
  -h, --help         Show this help and exit
  -n, --dry-run      Plan only (pass -n to setup)
  -y, --yes          Non-interactive (profile defaults)
  --bash             Force classic bash prompts (skip TUI)
  --profile <id>     Profile id (default | SoftwareBlair | …)
  --pkgmgr <name>    brew | apt | dnf | pacman

Environment:
  DOTFILES_REPO, DOTFILES_REF, DOTFILES_DIR, DOTFILES_BASH,
  DOTFILES_DRY_RUN, DOTFILES_YES, DOTFILES_PKGMGR, DOTFILES_PROFILE,
  DOTFILES_SKIP_TUI

Also available via Homebrew (see docs/install.md):
  brew tap SoftwareBlair/dotfiles
  brew install dotfiles-setup

Recommended one-liner:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
EOF
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

detect_target() {
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *) die "unsupported OS: $(uname -s)" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) die "unsupported architecture: $(uname -m)" ;;
    esac
    echo "${os}-${arch}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -n|--dry-run)
                DOTFILES_DRY_RUN=1
                shift
                ;;
            -y|--yes)
                DOTFILES_YES=1
                shift
                ;;
            --bash)
                DOTFILES_BASH=1
                shift
                ;;
            --profile)
                [[ $# -ge 2 ]] || die "--profile requires a value"
                DOTFILES_PROFILE="$2"
                shift 2
                ;;
            --pkgmgr)
                [[ $# -ge 2 ]] || die "--pkgmgr requires a value"
                DOTFILES_PKGMGR="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "unknown option: $1 (try --help)"
                ;;
            *)
                die "unexpected argument: $1 (try --help)"
                ;;
        esac
    done
}

# Fetch repo into $DEST (reuse if it already looks like this project)
ensure_repo() {
    if [[ -f "$DEST/.scripts/setup.sh" ]]; then
        info "Using existing repo at $DEST"
        return 0
    fi

    if [[ -e "$DEST" ]] && [[ ! -f "$DEST/.scripts/setup.sh" ]]; then
        die "$DEST exists but does not look like the dotfiles repo"
    fi

    info "Installing dotfiles → $DEST (ref: $REF)"

    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 --branch "$REF" "https://github.com/${REPO}.git" "$DEST" \
            || die "git clone failed"
        return 0
    fi

    need_cmd curl
    need_cmd tar
    local tmp tarball
    tmp="$(mktemp -d)"
    tarball="${tmp}/dotfiles.tar.gz"
    info "git not found — downloading tarball"
    curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" -o "$tarball" \
        || curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" -o "$tarball" \
        || die "failed to download repo archive for ref $REF"
    mkdir -p "$DEST"
    tar -xzf "$tarball" -C "$tmp"
    # archive root is owner-repo-ref/
    local extracted
    extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$extracted" ]] || die "unexpected archive layout"
    # Move contents into DEST
    shopt -s dotglob
    mv "$extracted"/* "$DEST"/
    shopt -u dotglob
    rm -rf "$tmp"
}

# Download prebuilt TUI from GitHub Releases into .scripts/bin/ and ~/.local/bin/
maybe_download_tui() {
    [[ -n "${DOTFILES_SKIP_TUI:-}" || -n "${DOTFILES_BASH:-}" ]] && return 0

    need_cmd curl
    local target asset url dest_dir dest path_bin
    target="$(detect_target)"
    asset="dotfiles-setup-${target}"
    dest_dir="${DEST}/.scripts/bin"
    dest="${dest_dir}/dotfiles-setup"
    path_bin="${HOME}/.local/bin/dotfiles-setup"
    mkdir -p "$dest_dir" "${HOME}/.local/bin"

    url="https://github.com/${RELEASE_REPO}/releases/latest/download/${asset}"
    info "Fetching TUI binary (${asset})"
    if curl -fsSL "$url" -o "${dest}.tmp"; then
        mv "${dest}.tmp" "$dest"
        chmod +x "$dest"
        cp "$dest" "$path_bin"
        chmod +x "$path_bin"
        info "TUI ready → $dest"
        info "Also installed → $path_bin (ensure ~/.local/bin is on PATH)"
        return 0
    fi

    rm -f "${dest}.tmp" "$dest"
    warn "No prebuilt TUI for ${target} (or download failed) — using bash prompts"
}

run_setup() {
    local setup="${DEST}/.scripts/setup.sh"
    [[ -x "$setup" || -f "$setup" ]] || die "setup.sh not found at $setup"
    chmod +x "$setup" 2>/dev/null || true

    local args=()
    if [[ -n "${DOTFILES_BASH:-}" || -n "${DOTFILES_SKIP_TUI:-}" ]]; then
        args+=(--bash)
    elif [[ -x "${DEST}/.scripts/bin/dotfiles-setup" || -x "${DEST}/.scripts/tui/dotfiles-setup" ]]; then
        args+=(--tui)
    else
        args+=(--bash)
    fi
    [[ -n "${DOTFILES_DRY_RUN:-}" ]] && args+=(-n)
    [[ -n "${DOTFILES_YES:-}" ]] && args+=(-y)
    [[ -n "${DOTFILES_PROFILE:-}" ]] && args+=(--profile "$DOTFILES_PROFILE")
    [[ -n "${DOTFILES_PKGMGR:-}" ]] && args+=(--pkgmgr "$DOTFILES_PKGMGR")

    info "Starting setup: $setup ${args[*]}"
    # Prefer /dev/tty so piped installers still get interactive input
    if [[ -r /dev/tty ]]; then
        exec "$setup" "${args[@]}" </dev/tty
    fi
    exec "$setup" "${args[@]}"
}

main() {
    parse_args "$@"
    need_cmd uname
    ensure_repo
    maybe_download_tui
    run_setup
}

main "$@"
