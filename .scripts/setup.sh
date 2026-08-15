#!/bin/bash
# New machine setup - brew-first, bash + gum
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
source "$SCRIPTS_DIR/lib/profiles.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/presets.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/configure.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/generate.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/migrate.sh"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/lib/wizard-export.sh"

DRY_RUN=""
YES_MODE=""
UNDO_MODE=""
UNDO_SELECT=""
RESET_MODE=""
PKG_MGR_FLAG=""
RUN_COMMAND=""
FORCE_TUI=""
FORCE_BASH=""
PROFILE_FLAG=""

usage() {
    local b="${BCyan:-}" d="${BrBlack:-}" o="${Off:-}"
    local w="${BWhite:-}" g="${Green:-}"

    echo ""
    echo -e "${b}New machine setup${o}  ${d}macOS + Linux · Homebrew${o}"
    echo -e "${d}────────────────────────────────────────${o}"
    echo -e "  Interactive gum wizard: ensure brew → zsh + Starship → pick apps → install."
    echo ""
    echo -e "  ${w}Includes${o}"
    echo -e "    ${d}shell${o}     ${HELP_INCLUDES_SHELL}"
    echo -e "    ${d}editors${o}   ${HELP_INCLUDES_EDITORS}"
    echo -e "    ${d}apps${o}      browsers, 1Password, chat, Docker, CLI tools (opt-in)"
    echo ""
    echo -e "  ${w}Usage${o}"
    echo -e "    ${g}./setup.sh${o}                   Gum wizard (bash)"
    echo -e "    ${g}./setup.sh -y${o}                Non-interactive (shell + default apps)"
    echo -e "    ${g}./setup.sh -n${o}                Dry-run (plan only, zero file writes)"
    echo -e "    ${g}./setup.sh -y -n${o}             Non-interactive dry-run"
    echo -e "    ${g}./setup.sh --undo${o}            Reverse all logged installs/configs"
    echo -e "    ${g}./setup.sh --undo -n${o}         Preview undo"
    echo -e "    ${g}./setup.sh --undo --select${o}   Choose what to reverse"
    echo -e "    ${g}./setup.sh --reset${o}           Full reverse + remove ~/.dotfiles-setup"
    echo -e "    ${g}./setup.sh --tui${o}             Optional experimental Go TUI"
    echo -e "    ${g}./setup.sh -c${o} ${d}<helper>${o}       export_wizard_catalog · ..."
    echo ""
    echo -e "  ${w}Defaults${o}"
    echo -e "    ${d}pkgmgr${o}    Homebrew only (installed on Linux if missing)"
    echo -e "    ${d}configs${o}   Generated into \$HOME (modular zsh + stock Starship)"
    echo -e "    ${d}updates${o}   Prompt to upgrade when already installed & outdated"
    echo ""
    echo -e "  ${w}More${o}"
    echo -e "    ${d}docs${o}      docs/ · README.md"
    echo -e "    ${d}state${o}     ~/.dotfiles-setup/"
    echo ""
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -y|--yes) YES_MODE=1; shift ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            --tui) FORCE_TUI=1; shift ;;
            --bash) FORCE_BASH=1; shift ;;
            --undo) UNDO_MODE=1; shift ;;
            --reset) RESET_MODE=1; UNDO_MODE=1; shift ;;
            --select) UNDO_SELECT=true; shift ;;
            --profile)
                PROFILE_FLAG="${2:-}"
                if [[ -z "$PROFILE_FLAG" ]]; then
                    echo "Missing value for --profile" >&2
                    exit 1
                fi
                shift 2
                ;;
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

# Brew-first: always Homebrew
default_pkgmgr() {
    echo "brew"
}

pick_pkgmgr() {
    if [[ -n "$PKG_MGR_FLAG" && "$PKG_MGR_FLAG" != "brew" ]]; then
        prompt_warn "This wizard is brew-first; ignoring --pkgmgr $PKG_MGR_FLAG"
    fi
    PKG_MGR="brew"
}

# Ensure git + curl exist (via brew)
ensure_core_prereqs() {
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    [[ ${#missing[@]} -eq 0 ]] && return 0

    prompt_warn "Missing required tools: ${missing[*]}"
    local install=false
    if [[ -n "${YES_MODE:-}" ]]; then
        install=true
    elif prompt_confirm "Install missing tools via brew?" "true"; then
        install=true
    fi
    if [[ "$install" != "true" ]]; then
        prompt_error "git and curl are required. Aborting."
        return 1
    fi

    local pkg cmd
    for pkg in "${missing[@]}"; do
        cmd="brew install $pkg"
        if dry_run_is_active; then
            dry_run_add_step "Install $pkg" "$cmd" "" "" "false" ""
            continue
        fi
        prompt_style "Installing $pkg..."
        bash -c "$cmd" || {
            prompt_error "Failed to install $pkg"
            return 1
        }
    done
    return 0
}

run_setup() {
    # state_init is a no-op during dry-run (must not create ~/.dotfiles-setup).
    state_init
    load_setup_prefs
    ensure_gum

    case "${PLATFORM:-}" in
        macos|linux) ;;
        *)
            prompt_error "Unsupported platform: ${PLATFORM:-unknown} (need macOS or Linux)"
            exit 1
            ;;
    esac

    prompt_welcome "New machine setup" "$(platform_label)"
    prompt_info "Tool root: $DOTFILES_DIR"
    dry_run_is_active && prompt_info "Dry-run: same prompts as a real run; nothing will be installed or written (including ~/.dotfiles-setup)."

    local count
    count="$(state_log_count)"
    if [[ "$count" -gt 0 && -z "${YES_MODE:-}" ]]; then
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
    prompt_info "Package manager: brew (Homebrew)"

    if dry_run_is_active; then
        dry_run_begin_plan
    fi

    ensure_pkgmgr brew || exit 1
    ensure_core_prereqs || exit 1

    # Optional light migrate (unmanaged zshrc) - no profile step
    if [[ -z "${YES_MODE:-}" ]]; then
        pick_migrate
        migrate_apply
    else
        MIGRATE_ACTION="none"
    fi

    THEME_STARSHIP="${THEME_STARSHIP:-stock}"
    if [[ -n "${SETUP_THEMES:-}" ]]; then
        local pair
        for pair in $SETUP_THEMES; do
            case "$pair" in
                starship=*) THEME_STARSHIP="${pair#starship=}" ;;
            esac
        done
    fi

    if ! pick_my_setup; then
        exit 1
    fi

    echo ""
    print_my_setup_summary
    echo "  Configs: generate into \$HOME"
    echo "  Starship theme: ${THEME_STARSHIP:-stock}"
    [[ -n "${MIGRATE_ACTION:-}" && "$MIGRATE_ACTION" != "none" ]] && echo "  Migrate: $MIGRATE_ACTION"
    dry_run_is_active && echo "  Mode: DRY RUN"

    if [[ -z "${YES_MODE:-}" ]]; then
        if dry_run_is_active; then
            if ! prompt_confirm "Continue dry-run with this plan?" "true"; then
                prompt_warn "Cancelled."
                exit 0
            fi
        else
            local next
            next="$(prompt_choose_one "What next?" \
                "Install now  [default]" \
                "Preview plan (dry-run)" \
                "Cancel")"
            case "$next" in
                Cancel*)
                    prompt_warn "Cancelled."
                    exit 0
                    ;;
                Preview*)
                    DRY_RUN=1
                    dry_run_begin_plan
                    ;;
            esac
        fi
    fi

    INSTALL_REPORT_OK=()
    INSTALL_REPORT_SKIP=()
    INSTALL_REPORT_FAIL=()
    INSTALL_REPORT_CONFIG=()

    install_prerequisites
    installer_run_selections
    generate_configs
    offer_secrets_zprofile
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        maybe_chsh "$SELECTED_SHELL"
    fi

    if dry_run_is_active; then
        dry_run_print_plan "New machine setup plan"
        prompt_info "Dry run complete - no changes made."
        exit 0
    fi

    save_setup_prefs
    print_final_report
    prompt_welcome "Done" "Restart your terminal"
}

maybe_run_tui() {
    # Only when explicitly requested - gum bash is the default path
    [[ -n "${FORCE_TUI:-}" ]] || return 1
    [[ -n "${FORCE_BASH:-}" || -n "${YES_MODE:-}" || -n "${UNDO_MODE:-}" || -n "${RUN_COMMAND:-}" ]] && return 1

    local tui_dir="$SCRIPTS_DIR/tui"
    local tui_bin=""
    if [[ -x "$SCRIPTS_DIR/bin/dotfiles-setup" ]]; then
        tui_bin="$SCRIPTS_DIR/bin/dotfiles-setup"
    elif [[ -x "$tui_dir/dotfiles-setup" ]]; then
        tui_bin="$tui_dir/dotfiles-setup"
    elif command -v go >/dev/null 2>&1 && [[ -f "$tui_dir/go.mod" ]]; then
        (cd "$tui_dir" && go build -o dotfiles-setup .) || return 1
        tui_bin="$tui_dir/dotfiles-setup"
    else
        echo "TUI binary missing. Build with: (cd .scripts/tui && go build -o ../bin/dotfiles-setup .)" >&2
        return 1
    fi

    local args=()
    [[ -n "${DRY_RUN:-}" ]] && args+=(--dry-run)
    [[ -n "${PKG_MGR_FLAG:-}" ]] && args+=(--pkgmgr "$PKG_MGR_FLAG")
    [[ -n "${PROFILE_FLAG:-}" ]] && args+=(--profile "$PROFILE_FLAG")
    exec "$tui_bin" "${args[@]}"
}

# --- main ---
parse_args "$@"
init_platform
load_catalogs

if [[ -n "$UNDO_MODE" ]]; then
    ensure_gum
    PKG_MGR="${PKG_MGR_FLAG:-brew}"
    ensure_brew_shellenv || true
    if [[ -n "$RESET_MODE" ]]; then
        run_reset
    else
        run_undo "${UNDO_SELECT:-false}" "false"
    fi
    exit 0
fi

if [[ -n "$RUN_COMMAND" ]]; then
    if [[ "$RUN_COMMAND" == "export_wizard_catalog" ]]; then
        PKG_MGR="${PKG_MGR_FLAG:-brew}"
        export_wizard_catalog
        exit $?
    fi
    ensure_gum
    case "$RUN_COMMAND" in
        revert_setup) run_undo "false" "false" ;;
        run_reset) run_reset ;;
        symlink_dotfile|unlink_dotfile) "$RUN_COMMAND" "${RUN_COMMAND_ARGS[@]:-}" ;;
        *) "$RUN_COMMAND" ;;
    esac
    prompt_success "Command complete!"
    exit 0
fi

maybe_run_tui || run_setup
