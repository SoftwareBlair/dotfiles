#!/bin/bash
# Setup my usual machine
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/helpers.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/../.zsh/colors.zsh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/dry-run.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/prompts.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/state.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/pkgmgr.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/catalog.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/installer.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/undo.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/presets.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/configure.sh"

DRY_RUN=""
YES_MODE=""
UNDO_MODE=""
UNDO_SELECT=""
PKG_MGR_FLAG=""
RUN_COMMAND=""

usage() {
    cat <<'EOF'
Setup my usual machine (macOS + Linux)

Installs the same stack you use on improvements-while-using:
  SFMono Nerd Font, Starship, eza, Warp, Cursor (default editor), Zed,
  zsh plugins, NVM, Raycast (macOS), VS Code when available —
  then links this repo’s configs.

Usage:
  ./setup.sh                 Interactive: confirm, then install
  ./setup.sh -y              Non-interactive install
  ./setup.sh -n              Dry-run (show plan, change nothing)
  ./setup.sh -y -n           Non-interactive dry-run
  ./setup.sh --undo          Undo logged installs + symlinks
  ./setup.sh --undo -n       Preview undo
  ./setup.sh --undo --select Pick which logged actions to reverse
  ./setup.sh --pkgmgr brew|apt|dnf|pacman
  ./setup.sh -c <helper>     move_dotfiles | revert_setup |
                             symlink_dotfile | unlink_dotfile | …

Defaults:
  • Package manager: Homebrew (Mac workflow; works on Linux too)
  • Editor: Cursor (VS Code optional when available)
  • Shell profile: Starship + this repo’s .zshrc
  • Dotfiles: symlink from this repo (any path; ~/dotfiles not required)
  • Already installed: offer upgrade when the package manager has an update

Customize stack: edit MY_SETUP in .scripts/lib/presets.sh
State: ~/.dotfiles-setup/  (install log, features, backups)
See README.md for full docs.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -y|--yes) YES_MODE=1; shift ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            --undo) UNDO_MODE=1; shift ;;
            --select) UNDO_SELECT=true; shift ;;
            --pkgmgr) PKG_MGR_FLAG="${2:-}"; shift 2 ;;
            # Ignored legacy flags (kept so old docs/scripts don’t break)
            --preset|--plan|--export-plan)
                shift
                [[ $# -gt 0 && "$1" != -* ]] && shift
                ;;
            -c)
                RUN_COMMAND="${2:-}"
                shift 2
                RUN_COMMAND_ARGS=("$@")
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

pick_pkgmgr() {
    if [[ -n "$PKG_MGR_FLAG" ]]; then
        PKG_MGR="$PKG_MGR_FLAG"
        return 0
    fi
    load_setup_prefs
    # Prefer Homebrew for reliability / parity with your Mac improvements setup
    if [[ -n "${YES_MODE:-}" ]]; then
        PKG_MGR="${PKG_MGR:-brew}"
        return 0
    fi
    local options=("Homebrew (brew)  [default]")
    if [[ "$PLATFORM" == "linux" ]]; then
        command -v apt-get &>/dev/null && options+=("apt — Debian/Ubuntu system packages")
        command -v dnf &>/dev/null && options+=("dnf — Fedora/RHEL system packages")
        command -v pacman &>/dev/null && options+=("pacman — Arch system packages")
    fi
    if [[ ${#options[@]} -eq 1 ]]; then
        PKG_MGR="brew"
        return 0
    fi
    local choice
    choice="$(prompt_choose_one "Package manager" "${options[@]}")"
    case "$choice" in
        apt*) PKG_MGR="apt" ;;
        dnf*) PKG_MGR="dnf" ;;
        pacman*) PKG_MGR="pacman" ;;
        *) PKG_MGR="brew" ;;
    esac
}

set_default_symlinks() {
    SYMLINK_TARGETS=(".zshrc" ".zshenv" ".config")
    [[ " ${SELECTED_IDS[*]} " == *" warp "* ]] && SYMLINK_TARGETS+=(".warp")
    [[ " ${SELECTED_IDS[*]} " == *" zed "* ]] && SYMLINK_TARGETS+=(".config/zed")
    # starship.toml is inside .config — also link explicitly if .config is a dir merge case
    LINK_MODE="symlink"
    SHELL_PROFILE_MODE="starship"
}

run_setup() {
    init_platform
    state_init
    load_setup_prefs
    ensure_gum || prompt_warn "Using basic prompts (gum not available)."
    load_catalogs

    prompt_welcome "New machine setup" "$(platform_label)"
    prompt_info "Dotfiles: $DOTFILES_DIR"
    prompt_info "Stack: SFMono, Cursor, Warp, Zed, Starship, eza, …"

    if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" && -z "${YES_MODE:-}" ]]; then
        if prompt_confirm "Move repo to ~/dotfiles? (optional — works from any path)" "false"; then
            move_dotfiles
            DOTFILES_DIR="$HOME/dotfiles"
        fi
    fi

    # Resume shortcut
    local count
    count="$(state_log_count)"
    if [[ "$count" -gt 0 && -z "${YES_MODE:-}" && -z "$DRY_RUN" ]]; then
        local resume
        resume="$(prompt_choose_one "Previous setup found ($count actions). What next?" \
            "Re-run my usual setup  [default]" \
            "Undo previous setup" \
            "Cancel")"
        case "$resume" in
            Undo*) run_undo "false"; exit 0 ;;
            Cancel*) exit 0 ;;
        esac
    fi

    pick_pkgmgr
    prompt_info "Package manager: $PKG_MGR"

    # Start the plan early so brew bootstrap / prereqs are included
    if dry_run_is_active; then
        dry_run_begin_plan
    fi

    ensure_pkgmgr "$PKG_MGR"

    apply_my_setup
    set_default_symlinks

    echo ""
    print_my_setup_summary
    echo "  Package manager: $PKG_MGR"
    echo "  Link mode: symlink"
    dry_run_is_active && echo "  Mode: DRY RUN"

    if [[ -z "${YES_MODE:-}" ]]; then
        if dry_run_is_active; then
            :
        elif ! prompt_confirm "Install this setup now?" "true"; then
            local next
            next="$(prompt_choose_one "What next?" \
                "Preview plan (dry-run)  [default]" \
                "Cancel")"
            if [[ "$next" == Cancel* ]]; then
                prompt_warn "Cancelled."
                exit 0
            fi
            DRY_RUN=1
            dry_run_begin_plan
            # Re-record brew bootstrap if it would still be needed
            if [[ "$PKG_MGR" == "brew" ]] && ! ensure_brew_shellenv; then
                ensure_pkgmgr "$PKG_MGR"
            fi
        fi
    fi

    # Build / show plan
    if dry_run_is_active; then
        install_prerequisites
        installer_plan_selections
        local p
        for p in "${SYMLINK_TARGETS[@]}"; do
            install_dotfile_path "$p"
        done
        write_shell_features
        configure_starship
        offer_secrets_zprofile
        [[ -n "${SELECTED_SHELL:-}" ]] && maybe_chsh "$SELECTED_SHELL"
        dry_run_print_plan "My setup plan"
        prompt_info "Dry run complete — no changes made."
        save_setup_prefs
        exit 0
    fi

    # Install
    INSTALL_REPORT_OK=()
    INSTALL_REPORT_SKIP=()
    INSTALL_REPORT_FAIL=()
    INSTALL_REPORT_CONFIG=()

    install_prerequisites
    installer_run_selections
    local p
    for p in "${SYMLINK_TARGETS[@]}"; do
        install_dotfile_path "$p"
    done
    write_shell_features
    configure_starship
    configure_oh_my_zsh_profile
    offer_secrets_zprofile
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        maybe_chsh "$SELECTED_SHELL"
    fi

    save_setup_prefs
    print_final_report
    prompt_welcome "Done" "Restart your terminal"
}

# --- main ---
parse_args "$@"
init_platform
load_catalogs

if [[ -n "$UNDO_MODE" ]]; then
    ensure_gum || true
    if [[ -n "$PKG_MGR_FLAG" ]]; then
        PKG_MGR="$PKG_MGR_FLAG"
    else
        load_setup_prefs
        PKG_MGR="${PKG_MGR:-brew}"
        ensure_brew_shellenv || true
    fi
    run_undo "${UNDO_SELECT:-false}"
    exit 0
fi

if [[ -n "$RUN_COMMAND" ]]; then
    ensure_gum || true
    case "$RUN_COMMAND" in
        revert_setup) run_undo "false" ;;
        symlink_dotfile|unlink_dotfile) "$RUN_COMMAND" "${RUN_COMMAND_ARGS[@]:-}" ;;
        *) "$RUN_COMMAND" ;;
    esac
    prompt_success "Command complete!"
    exit 0
fi

run_setup
