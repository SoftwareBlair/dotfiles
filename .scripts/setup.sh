#!/bin/bash
# New machine setup
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
    local b="${BCyan:-}" d="${BrBlack:-}" o="${Off:-}"
    local w="${BWhite:-}" g="${Green:-}"

    echo ""
    echo -e "${b}New machine setup${o}  ${d}macOS + Linux${o}"
    echo -e "${d}────────────────────────────────────────${o}"
    echo -e "  Installs preferred stack, then links this repo’s configs."
    echo ""
    echo -e "  ${w}Includes${o}"
    echo -e "    ${d}editors${o}   ${HELP_INCLUDES_EDITORS:-Cursor, Zed}"
    echo -e "    ${d}terminal${o}  ${HELP_INCLUDES_TERMINAL:-Warp · SFMono · Starship · eza}"
    echo -e "    ${d}shell${o}     ${HELP_INCLUDES_SHELL:-zsh + plugins · NVM}"
    echo ""
    echo -e "  ${w}Usage${o}"
    echo -e "    ${g}./setup.sh${o}                   Confirm, then install"
    echo -e "    ${g}./setup.sh -y${o}                Non-interactive"
    echo -e "    ${g}./setup.sh -n${o}                Dry-run (preview only)"
    echo -e "    ${g}./setup.sh -y -n${o}             Non-interactive dry-run"
    echo -e "    ${g}./setup.sh --undo${o}            Reverse logged actions"
    echo -e "    ${g}./setup.sh --undo -n${o}         Preview undo"
    echo -e "    ${g}./setup.sh --undo --select${o}   Choose what to reverse"
    echo -e "    ${g}./setup.sh --pkgmgr${o} ${d}<name>${o}   brew · apt · dnf · pacman"
    echo -e "    ${g}./setup.sh -c${o} ${d}<helper>${o}       move_dotfiles · revert_setup · …"
    echo ""
    echo -e "  ${w}Defaults${o}"
    echo -e "    ${d}pkgmgr${o}    Homebrew (system manager on Linux if brew missing)"
    echo -e "    ${d}editor${o}    Cursor"
    echo -e "    ${d}prompt${o}    Starship + this repo’s .zshrc"
    echo -e "    ${d}dotfiles${o}  Symlink (repo can live anywhere)"
    echo -e "    ${d}updates${o}   Offer upgrade when already installed"
    echo ""
    echo -e "  ${w}More${o}"
    echo -e "    ${d}stack${o}     edit MY_SETUP in .scripts/lib/presets.sh"
    echo -e "    ${d}state${o}     ~/.dotfiles-setup/"
    echo -e "    ${d}docs${o}      README.md"
    echo ""
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -y|--yes) YES_MODE=1; shift ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            --undo) UNDO_MODE=1; shift ;;
            --select) UNDO_SELECT=true; shift ;;
            --pkgmgr)
                PKG_MGR_FLAG="${2:-}"
                if [[ -z "$PKG_MGR_FLAG" ]]; then
                    echo "Missing value for --pkgmgr" >&2
                    exit 1
                fi
                shift 2
                ;;
            -c)
                RUN_COMMAND="${2:-}"
                if [[ -z "$RUN_COMMAND" ]]; then
                    echo "Missing value for -c" >&2
                    exit 1
                fi
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

# Prefer brew when present; otherwise the native Linux manager
default_pkgmgr() {
    if ensure_brew_shellenv 2>/dev/null || command -v brew &>/dev/null; then
        echo "brew"
        return
    fi
    if [[ "${PLATFORM:-}" == "linux" ]]; then
        command -v apt-get &>/dev/null && { echo "apt"; return; }
        command -v dnf &>/dev/null && { echo "dnf"; return; }
        command -v pacman &>/dev/null && { echo "pacman"; return; }
    fi
    echo "brew"
}

pick_pkgmgr() {
    if [[ -n "$PKG_MGR_FLAG" ]]; then
        PKG_MGR="$PKG_MGR_FLAG"
        return 0
    fi
    load_setup_prefs
    if [[ -n "${YES_MODE:-}" ]]; then
        PKG_MGR="${PKG_MGR:-$(default_pkgmgr)}"
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
    # .config covers starship.toml and .config/zed — no nested duplicate
    SYMLINK_TARGETS=(".zshrc" ".zshenv" ".config")
    [[ " ${SELECTED_IDS[*]} " == *" warp "* ]] && SYMLINK_TARGETS+=(".warp")
    LINK_MODE="symlink"
    SHELL_PROFILE_MODE="starship"
}

run_setup() {
    state_init
    load_setup_prefs
    ensure_gum || prompt_warn "Using basic prompts (gum not available)."

    prompt_welcome "New machine setup" "$(platform_label)"
    prompt_info "Dotfiles: $DOTFILES_DIR"
    prompt_info "Stack: ${HELP_INCLUDES_TERMINAL:-SFMono, Starship, eza, …} · Cursor · Zed"

    if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" && -z "${YES_MODE:-}" ]]; then
        if prompt_confirm "Move repo to ~/dotfiles? (optional — works from any path)" "false"; then
            move_dotfiles
            DOTFILES_DIR="$HOME/dotfiles"
        fi
    fi

    local count
    count="$(state_log_count)"
    if [[ "$count" -gt 0 && -z "${YES_MODE:-}" && -z "$DRY_RUN" ]]; then
        local resume
        resume="$(prompt_choose_one "Previous setup found ($count actions). What next?" \
            "Re-run new machine setup  [default]" \
            "Undo previous setup" \
            "Cancel")"
        case "$resume" in
            Undo*) run_undo "false"; exit 0 ;;
            Cancel*) exit 0 ;;
        esac
    fi

    pick_pkgmgr
    prompt_info "Package manager: $PKG_MGR"

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
            if [[ "$PKG_MGR" == "brew" ]] && ! ensure_brew_shellenv; then
                ensure_pkgmgr "$PKG_MGR"
            fi
        fi
    fi

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
        dry_run_print_plan "New machine setup plan"
        prompt_info "Dry run complete — no changes made."
        save_setup_prefs
        exit 0
    fi

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
        PKG_MGR="${PKG_MGR:-$(default_pkgmgr)}"
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
