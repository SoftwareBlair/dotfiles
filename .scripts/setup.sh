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
PKG_MGR_FLAG=""
RUN_COMMAND=""
FORCE_TUI=""
FORCE_BASH=""
PROFILE_FLAG=""

usage() {
    local b="${BCyan:-}" d="${BrBlack:-}" o="${Off:-}"
    local w="${BWhite:-}" g="${Green:-}"

    echo ""
    echo -e "${b}New machine setup${o}  ${d}macOS + Linux${o}"
    echo -e "${d}────────────────────────────────────────${o}"
    echo -e "  Installs a selected stack (defaults from your usual setup), then links this repo’s configs."
    echo ""
    echo -e "  ${w}Includes${o}"
    echo -e "    ${d}editors${o}   ${HELP_INCLUDES_EDITORS:-Cursor, Zed}"
    echo -e "    ${d}terminal${o}  ${HELP_INCLUDES_TERMINAL:-Warp · SFMono · Starship · eza}"
    echo -e "    ${d}shell${o}     ${HELP_INCLUDES_SHELL:-zsh + plugins · NVM}"
    echo ""
    echo -e "  ${w}Usage${o}"
    echo -e "    ${g}./setup.sh${o}                   TUI wizard (falls back to bash prompts)"
    echo -e "    ${g}./setup.sh --tui${o}             Force Go Bubble Tea TUI"
    echo -e "    ${g}./setup.sh --bash${o}            Force classic bash prompts"
    echo -e "    ${g}./setup.sh -y${o}                Non-interactive (full default stack)"
    echo -e "    ${g}./setup.sh -n${o}                Dry-run (same prompts, no changes)"
    echo -e "    ${g}./setup.sh -y -n${o}             Non-interactive dry-run"
    echo -e "    ${g}./setup.sh --undo${o}            Reverse logged actions"
    echo -e "    ${g}./setup.sh --undo -n${o}         Preview undo"
    echo -e "    ${g}./setup.sh --undo --select${o}   Choose what to reverse"
    echo -e "    ${g}./setup.sh --profile${o} ${d}<user>${o}  GitHub username profile (e.g. SoftwareBlair)"
    echo -e "    ${g}./setup.sh --pkgmgr${o} ${d}<name>${o}   brew · apt · dnf · pacman"
    echo -e "    ${g}./setup.sh -c${o} ${d}<helper>${o}       export_wizard_catalog · move_dotfiles · …"
    echo ""
    echo -e "  ${w}Defaults${o}"
    echo -e "    ${d}profile${o}   ${DEFAULT_PROFILE:-default} (see profiles/*.toml)"
    echo -e "    ${d}pkgmgr${o}    Homebrew (system manager on Linux if brew missing)"
    echo -e "    ${d}configs${o}   Generated into \$HOME (modular zsh + themes)"
    echo -e "    ${d}updates${o}   Offer upgrade when already installed"
    echo ""
    echo -e "  ${w}More${o}"
    echo -e "    ${d}profiles${o}  profiles/<GitHubUser>.toml — contribute your setup"
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

# Ensure git + curl exist (offer install via PKG_MGR)
ensure_core_prereqs() {
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    [[ ${#missing[@]} -eq 0 ]] && return 0

    prompt_warn "Missing required tools: ${missing[*]}"
    local install=false
    if [[ -n "${YES_MODE:-}" ]]; then
        install=true
    elif prompt_confirm "Install missing tools via ${PKG_MGR:-brew}?" "true"; then
        install=true
    fi
    if [[ "$install" != "true" ]]; then
        prompt_error "git and curl are required. Aborting."
        return 1
    fi

    local pkg cmd
    for pkg in "${missing[@]}"; do
        case "${PKG_MGR:-brew}" in
            brew) cmd="brew install $pkg" ;;
            apt) cmd="sudo apt-get install -y $pkg" ;;
            dnf) cmd="sudo dnf install -y $pkg" ;;
            pacman) cmd="sudo pacman -S --noconfirm $pkg" ;;
            *) cmd="brew install $pkg" ;;
        esac
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
    prompt_info "Package manager: $PKG_MGR"

    if dry_run_is_active; then
        dry_run_begin_plan
    fi

    ensure_pkgmgr "$PKG_MGR"
    ensure_core_prereqs || exit 1

    pick_migrate
    migrate_apply

    if ! pick_profile; then
        exit 1
    fi
    if [[ -n "${PROFILE_DESCRIPTION:-}" ]]; then
        prompt_info "Profile: $PROFILE_DESCRIPTION"
    fi

    # Themes from env (TUI) override profile
    if [[ -n "${SETUP_THEMES:-}" ]]; then
        # format: starship=blair
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
    echo "  Package manager: $PKG_MGR"
    echo "  Configs: generate into \$HOME"
    echo "  Starship theme: ${THEME_STARSHIP:-stock}"
    [[ -n "${MIGRATE_ACTION:-}" && "$MIGRATE_ACTION" != "none" ]] && echo "  Migrate: $MIGRATE_ACTION"
    dry_run_is_active && echo "  Mode: DRY RUN"

    if [[ -z "${YES_MODE:-}" ]]; then
        local confirm_msg="Install packages and generate configs now?"
        dry_run_is_active && confirm_msg="Continue dry-run with this plan?"
        if ! prompt_confirm "$confirm_msg" "true"; then
            if dry_run_is_active; then
                prompt_warn "Cancelled."
                exit 0
            fi
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
        prompt_info "Dry run complete — no changes made."
        exit 0
    fi

    save_setup_prefs
    print_final_report
    prompt_welcome "Done" "Restart your terminal"
}

maybe_run_tui() {
    # Non-interactive / undo / -c / explicit --bash → stay in bash
    [[ -n "${FORCE_BASH:-}" || -n "${YES_MODE:-}" || -n "${UNDO_MODE:-}" || -n "${RUN_COMMAND:-}" ]] && return 1
    [[ -n "${DOTFILES_NO_TUI:-}" ]] && return 1

    local tui_dir="$SCRIPTS_DIR/tui"
    local tui_bin=""
    # Prefer release/install.sh binary, then local build
    if [[ -x "$SCRIPTS_DIR/bin/dotfiles-setup" ]]; then
        tui_bin="$SCRIPTS_DIR/bin/dotfiles-setup"
    elif [[ -x "$tui_dir/dotfiles-setup" ]]; then
        tui_bin="$tui_dir/dotfiles-setup"
    elif [[ -n "${FORCE_TUI:-}" ]] && command -v go >/dev/null 2>&1 && [[ -f "$tui_dir/go.mod" ]]; then
        (cd "$tui_dir" && go build -o dotfiles-setup .) || return 1
        tui_bin="$tui_dir/dotfiles-setup"
    else
        [[ -n "${FORCE_TUI:-}" ]] && echo "TUI binary missing. Install via install.sh or: (cd .scripts/tui && go build -o dotfiles-setup .)" >&2
        return 1
    fi

    # Prefer TUI when binary exists (or --tui), and stdin/stdout are TTYs
    if [[ -z "${FORCE_TUI:-}" && ! ( -t 0 && -t 1 ) ]]; then
        # Still allow when /dev/tty is available (curl|bash -c installers)
        if [[ ! -r /dev/tty ]]; then
            return 1
        fi
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
    # JSON export should stay quiet (no gum / success banner)
    if [[ "$RUN_COMMAND" == "export_wizard_catalog" ]]; then
        if [[ -n "$PKG_MGR_FLAG" ]]; then
            PKG_MGR="$PKG_MGR_FLAG"
        else
            PKG_MGR="$(default_pkgmgr)"
        fi
        # PROFILE_FLAG / SETUP_PROFILE / DOTFILES_PROFILE honored inside export
        export_wizard_catalog
        exit $?
    fi
    ensure_gum
    case "$RUN_COMMAND" in
        revert_setup) run_undo "false" ;;
        symlink_dotfile|unlink_dotfile) "$RUN_COMMAND" "${RUN_COMMAND_ARGS[@]:-}" ;;
        *) "$RUN_COMMAND" ;;
    esac
    prompt_success "Command complete!"
    exit 0
fi

maybe_run_tui || run_setup
