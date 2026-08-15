#!/usr/bin/env bash
# One-liner bootstrap for SoftwareBlair/dotfiles (brew-first gum wizard)
#
# Recommended:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
#
# Or download then run:
#   curl -fsSL .../install.sh -o /tmp/install-dotfiles.sh && bash /tmp/install-dotfiles.sh
#
# Env knobs (CLI flags below override when set):
#   DOTFILES_REPO   GitHub owner/name          (default: SoftwareBlair/dotfiles)
#   DOTFILES_REF    branch or tag              (default: main)
#   DOTFILES_DIR    install location           (default: ~/dotfiles)
#   DOTFILES_DRY_RUN=1  pass -n to setup
#   DOTFILES_YES=1      pass -y to setup
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
Install the repo and run the brew-first gum setup wizard.

Usage:
  install.sh [options]

Options:
  -h, --help         Show this help and exit
  -n, --dry-run      Plan only (pass -n to setup) - writes nothing
  -y, --yes          Non-interactive (shell + default apps)

Environment:
  DOTFILES_REPO, DOTFILES_REF, DOTFILES_DIR,
  DOTFILES_DRY_RUN, DOTFILES_YES

Recommended one-liner:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"

Dry-run:
  /bin/bash -c "$(curl -fsSL .../install.sh)" -- -n
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
            --bash|--tui|--profile|--pkgmgr)
                # Accepted for compatibility; brew-first gum path ignores TUI/profile/pkgmgr
                if [[ "$1" == "--profile" || "$1" == "--pkgmgr" ]]; then
                    shift 2 || shift
                else
                    shift
                fi
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
    info "git not found - downloading tarball"
    curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" -o "$tarball" \
        || curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" -o "$tarball" \
        || die "failed to download repo archive for ref $REF"
    mkdir -p "$DEST"
    tar -xzf "$tarball" -C "$tmp"
    local extracted
    extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$extracted" ]] || die "unexpected archive layout"
    shopt -s dotglob
    mv "$extracted"/* "$DEST"/
    shopt -u dotglob
    rm -rf "$tmp"
}

# Best-effort optional TUI binary (does not gate the gum wizard)
maybe_download_tui() {
    [[ -n "${DOTFILES_SKIP_TUI:-}" ]] && return 0
    need_cmd curl
    local target asset url dest_dir dest path_bin
    target="$(detect_target)"
    asset="dotfiles-setup-${target}"
    dest_dir="${DEST}/.scripts/bin"
    dest="${dest_dir}/dotfiles-setup"
    path_bin="${HOME}/.local/bin/dotfiles-setup"
    mkdir -p "$dest_dir" "${HOME}/.local/bin"

    url="https://github.com/${RELEASE_REPO}/releases/latest/download/${asset}"
    if curl -fsSL "$url" -o "${dest}.tmp" 2>/dev/null; then
        mv "${dest}.tmp" "$dest"
        chmod +x "$dest"
        cp "$dest" "$path_bin"
        chmod +x "$path_bin"
        info "Optional TUI binary → $path_bin (use setup.sh --tui)"
        return 0
    fi
    rm -f "${dest}.tmp"
}

run_setup() {
    local setup="${DEST}/.scripts/setup.sh"
    [[ -x "$setup" || -f "$setup" ]] || die "setup.sh not found at $setup"
    chmod +x "$setup" 2>/dev/null || true

    # Always bash/gum wizard - TUI is opt-in via setup.sh --tui after install
    local args=(--bash)
    [[ -n "${DOTFILES_DRY_RUN:-}" ]] && args+=(-n)
    [[ -n "${DOTFILES_YES:-}" ]] && args+=(-y)

    info "Starting setup: $setup ${args[*]}"
    if [[ -r /dev/tty ]]; then
        exec "$setup" "${args[@]}" </dev/tty
    fi
    exec "$setup" "${args[@]}"
}

main() {
    parse_args "$@"
    need_cmd uname
    case "$(uname -s)" in
        Darwin|Linux) ;;
        *) die "unsupported OS: $(uname -s) (need macOS or Linux)" ;;
    esac
    ensure_repo
    maybe_download_tui
    run_setup
}

main "$@"
