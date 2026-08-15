#!/usr/bin/env bash
# One-liner bootstrap for SoftwareBlair/dotfiles (brew-first gum wizard)
#
# Recommended:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
#
# Dry-run (zero home config writes; temp clone cleaned up if we created it):
#   /bin/bash -c "$(curl -fsSL …/install.sh)" -- -n
#
# Env: DOTFILES_REPO, DOTFILES_REF, DOTFILES_DIR, DOTFILES_DRY_RUN, DOTFILES_YES
set -uo pipefail

REPO="${DOTFILES_REPO:-SoftwareBlair/dotfiles}"
REF="${DOTFILES_REF:-main}"
DEST="${DOTFILES_DIR:-$HOME/dotfiles}"
RELEASE_REPO="${DOTFILES_RELEASE_REPO:-$REPO}"
CREATED_DEST=""

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
  -n, --dry-run      Plan only — zero config writes (temp clone cleaned up)
  -y, --yes          Non-interactive (shell + default apps)

Environment:
  DOTFILES_REPO, DOTFILES_REF, DOTFILES_DIR,
  DOTFILES_DRY_RUN, DOTFILES_YES

Recommended:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"

Dry-run:
  /bin/bash -c "$(curl -fsSL …/install.sh)" -- -n

Reverse a previous install (from the clone):
  ~/dotfiles/.scripts/setup.sh --reset
EOF
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -n|--dry-run) DOTFILES_DRY_RUN=1; shift ;;
            -y|--yes) DOTFILES_YES=1; shift ;;
            --bash|--tui)
                shift
                ;;
            --profile|--pkgmgr)
                shift 2 || shift
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

clone_into() {
    local dest="$1"
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 --branch "$REF" "https://github.com/${REPO}.git" "$dest" \
            || die "git clone failed"
        return 0
    fi
    need_cmd curl
    need_cmd tar
    local tmp tarball extracted
    tmp="$(mktemp -d)"
    tarball="${tmp}/dotfiles.tar.gz"
    curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" -o "$tarball" \
        || curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" -o "$tarball" \
        || die "failed to download repo archive for ref $REF"
    mkdir -p "$dest"
    tar -xzf "$tarball" -C "$tmp"
    extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$extracted" ]] || die "unexpected archive layout"
    shopt -s dotglob
    mv "$extracted"/* "$dest"/
    shopt -u dotglob
    rm -rf "$tmp"
}

ensure_repo() {
    if [[ -f "$DEST/.scripts/setup.sh" ]]; then
        info "Using existing repo at $DEST"
        CREATED_DEST=""
        return 0
    fi

    if [[ -e "$DEST" ]] && [[ ! -f "$DEST/.scripts/setup.sh" ]]; then
        die "$DEST exists but does not look like the dotfiles repo"
    fi

    # Dry-run: clone to a temp dir so we do not leave ~/dotfiles behind
    if [[ -n "${DOTFILES_DRY_RUN:-}" && -z "${DOTFILES_DIR:-}" ]]; then
        DEST="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-dryrun.XXXXXX")"
        CREATED_DEST=1
        info "Dry-run: cloning into temporary $DEST (will be removed)"
    else
        info "Installing dotfiles → $DEST (ref: $REF)"
        CREATED_DEST=1
    fi

    clone_into "$DEST"
}

run_setup() {
    local setup="${DEST}/.scripts/setup.sh"
    [[ -f "$setup" ]] || die "setup.sh not found at $setup"
    chmod +x "$setup" 2>/dev/null || true

    local args=(--bash)
    [[ -n "${DOTFILES_DRY_RUN:-}" ]] && args+=(-n)
    [[ -n "${DOTFILES_YES:-}" ]] && args+=(-y)

    info "Starting setup: $setup ${args[*]}"
    local ec=0
    if [[ -r /dev/tty ]]; then
        "$setup" "${args[@]}" </dev/tty || ec=$?
    else
        "$setup" "${args[@]}" || ec=$?
    fi

    if [[ -n "$CREATED_DEST" && -n "${DOTFILES_DRY_RUN:-}" && -z "${DOTFILES_DIR:-}" ]]; then
        info "Dry-run: removing temporary clone $DEST"
        rm -rf "$DEST"
    fi
    return "$ec"
}

main() {
    parse_args "$@"
    need_cmd uname
    case "$(uname -s)" in
        Darwin|Linux) ;;
        *) die "unsupported OS: $(uname -s) (need macOS or Linux)" ;;
    esac
    ensure_repo
    # Never download TUI during dry-run (would write under DEST / ~/.local/bin)
    if [[ -z "${DOTFILES_DRY_RUN:-}" ]]; then
        :
        # optional TUI download skipped by default for brew-first gum path
    fi
    run_setup
}

main "$@"
