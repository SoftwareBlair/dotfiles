#!/bin/bash
# Developer Machine Setup Wizard — macOS + Linux
set -uo pipefail
# Note: not using set -e — prompt confirmations return 1 for "no"

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

# Flags
DRY_RUN=""
YES_MODE=""
UNDO_MODE=""
UNDO_SELECT=""
PKG_MGR_FLAG=""
PRESET_FLAG=""
PLAN_FILE=""
EXPORT_PLAN=""
RUN_COMMAND=""
WIZARD_MODE="" # full | add | custom

usage() {
    cat <<'EOF'
Developer Machine Setup Wizard (macOS + Linux)

Usage:
  ./setup.sh [options]
  ./setup.sh -c <command>

Options:
  -h, --help              Show this help
  -y, --yes               Non-interactive (uses personal preset by default)
  -n, --dry-run           Preview commands and paths; make no changes
  --undo                  Reverse actions recorded in the install log
  --select                With --undo: choose which logged items to undo
  --pkgmgr <name>         Package manager: brew | apt | dnf | pacman
  --preset <name>         minimal | personal | full | custom
  --plan <file>           Apply selections from a saved plan file
  --export-plan <file>    After selections, write a plan file (default: ~/.dotfiles-setup/last-plan.env)
  -c <command>            Run a single helper command

Helpers (-c):
  move_dotfiles
  remove_git_origin_remote
  symlink_dotfile <path>
  unlink_dotfile <path>
  uninstall_nvm
  revert_setup            Same as --undo

Examples:
  ./setup.sh
  ./setup.sh --preset personal --dry-run
  ./setup.sh -y --preset minimal --pkgmgr apt
  ./setup.sh --plan ~/.dotfiles-setup/last-plan.env
  ./setup.sh --undo --dry-run

Presets:
  personal   SFMono, Warp, Zed, zsh, Starship, eza, NVM, plugins, …
  minimal    zsh + Starship + eza
  full       Everything available for this OS / package manager
  custom     Pick each category interactively

State:
  Install log:  ~/.dotfiles-setup/install-log.jsonl
  Features:     ~/.dotfiles-setup/shell-features.zsh
  Prefs / plan: ~/.dotfiles-setup.conf , last-plan.env
  Backups:      ~/.dotfiles-setup/backups/

Dotfiles may live anywhere — DOTFILES_DIR is detected from this repo path
(or set in prefs). Moving to ~/dotfiles is optional.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -y|--yes)
                YES_MODE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            --undo)
                UNDO_MODE=1
                shift
                ;;
            --select)
                UNDO_SELECT=true
                shift
                ;;
            --pkgmgr)
                PKG_MGR_FLAG="${2:-}"
                shift 2
                ;;
            --preset)
                PRESET_FLAG="${2:-}"
                shift 2
                ;;
            --plan)
                PLAN_FILE="${2:-}"
                shift 2
                ;;
            --export-plan)
                shift
                if [[ $# -gt 0 && "$1" != -* ]]; then
                    EXPORT_PLAN="$1"
                    shift
                else
                    EXPORT_PLAN="$HOME/.dotfiles-setup/last-plan.env"
                fi
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

ensure_dotfiles_location() {
    # Allow repo to live anywhere; optionally offer move to ~/dotfiles
    prompt_info "Dotfiles directory: $DOTFILES_DIR"

    if [[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]]; then
        return 0
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        prompt_info "Using $DOTFILES_DIR as-is (-y mode; not moving)."
        return 0
    fi

    local choice
    choice="$(prompt_choose_one "Dotfiles are at $DOTFILES_DIR (not ~/dotfiles). What next?" \
        "Continue with this location (recommended)" \
        "Move to ~/dotfiles" \
        "Cancel")"
    case "$choice" in
        Move*)
            move_dotfiles
            DOTFILES_DIR="$HOME/dotfiles"
            ;;
        Cancel*)
            exit 1
            ;;
        *)
            prompt_info "Continuing with DOTFILES_DIR=$DOTFILES_DIR"
            ;;
    esac
}

maybe_resume_menu() {
    local count
    count="$(state_log_count)"
    if [[ "$count" -eq 0 ]] || [[ -n "${YES_MODE:-}" ]] || [[ -n "${PLAN_FILE:-}" ]] || [[ -n "${PRESET_FLAG:-}" ]]; then
        WIZARD_MODE="full"
        return 0
    fi

    prompt_style "── Previous setup detected ──"
    prompt_info "Install log has $count action(s) in $INSTALL_LOG"

    local choice
    choice="$(prompt_choose_one "How do you want to continue?" \
        "Full wizard (choose preset / categories again)" \
        "Add more tools (custom pick, keep existing installs)" \
        "Undo previous setup" \
        "Cancel")"
    case "$choice" in
        Add*) WIZARD_MODE="add"; PRESET_FLAG="custom" ;;
        Undo*)
            run_undo "false"
            exit 0
            ;;
        Cancel*)
            exit 0
            ;;
        *) WIZARD_MODE="full" ;;
    esac
}

choose_package_manager() {
    if [[ -n "$PKG_MGR_FLAG" ]]; then
        PKG_MGR="$PKG_MGR_FLAG"
        return 0
    fi

    load_setup_prefs
    local options=()
    while IFS= read -r m; do
        [[ -n "$m" ]] && options+=("$m")
    done < <(available_pkgmgrs)

    if [[ ${#options[@]} -eq 0 ]]; then
        prompt_error "No supported package managers detected."
        exit 1
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        PKG_MGR="${PKG_MGR:-${options[0]}}"
        return 0
    fi

    local labels=()
    local m
    for m in "${options[@]}"; do
        case "$m" in
            brew) labels+=("Homebrew (brew)") ;;
            apt) labels+=("apt (Debian/Ubuntu)") ;;
            dnf) labels+=("dnf (Fedora/RHEL)") ;;
            pacman) labels+=("pacman (Arch)") ;;
            *) labels+=("$m") ;;
        esac
    done

    local choice
    choice="$(prompt_choose_one "How would you like to install packages?" "${labels[@]}")"
    case "$choice" in
        Homebrew*) PKG_MGR="brew" ;;
        apt*) PKG_MGR="apt" ;;
        dnf*) PKG_MGR="dnf" ;;
        pacman*) PKG_MGR="pacman" ;;
        *) PKG_MGR="${options[0]}" ;;
    esac
}

collect_category() {
    local category="$1"
    local header="$2"
    local filter_shells="${3:-}"

    local labels=()
    local id
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        catalog_available "$id" || continue
        if [[ "$category" == "shell-configs" && -n "$filter_shells" ]]; then
            local shells_for
            shells_for="$(catalog_get "$id" shells)"
            if [[ -n "$shells_for" ]]; then
                local ok=false
                local s
                IFS=',' read -r -a wanted <<< "$filter_shells"
                for s in "${wanted[@]}"; do
                    [[ ",$shells_for," == *",$s,"* ]] && ok=true
                done
                [[ "$ok" == "true" ]] || continue
            fi
        fi
        labels+=("$(catalog_label "$id")")
    done < <(catalog_ids_by_category "$category")

    if [[ ${#labels[@]} -eq 0 ]]; then
        prompt_warn "No $category options available for $PLATFORM / $PKG_MGR."
        return 0
    fi

    local picked
    picked="$(prompt_choose_many "$header" "${labels[@]}")"
    while IFS= read -r label || [[ -n "$label" ]]; do
        [[ -z "$label" ]] && continue
        local cid
        cid="$(catalog_id_from_label "$label")" || continue
        installer_add_selection "$cid"
    done <<< "$picked"
}

collect_shell() {
    local labels=()
    local id
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        catalog_available "$id" || continue
        labels+=("$(catalog_label "$id")")
    done < <(catalog_ids_by_category "shells")

    if [[ -n "${YES_MODE:-}" ]]; then
        for id in $(catalog_ids_by_category "shells"); do
            if [[ "$id" == "zsh" ]] && catalog_available "$id"; then
                installer_add_selection "zsh"
                SELECTED_SHELL="zsh"
                return 0
            fi
        done
        return 0
    fi

    labels=("Skip — keep current shell" "${labels[@]}")
    local choice
    choice="$(prompt_choose_one "Choose a shell (zsh only for now)" "${labels[@]}")"
    if [[ "$choice" == Skip* ]]; then
        SELECTED_SHELL=""
        return 0
    fi
    local cid
    cid="$(catalog_id_from_label "$choice")" || return 0
    installer_add_selection "$cid"
    SELECTED_SHELL="$cid"
}

collect_symlinks() {
    choose_link_mode

    local defaults=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && defaults+=("$line")
    done < <(smart_symlink_defaults)

    if [[ ${#defaults[@]} -eq 0 ]]; then
        SYMLINK_TARGETS=()
        return 0
    fi

    local verb="Symlink"
    [[ "$LINK_MODE" == "copy" ]] && verb="Copy"

    if [[ -n "${YES_MODE:-}" ]]; then
        SYMLINK_TARGETS=("${defaults[@]}")
        prompt_info "$verb defaults: ${SYMLINK_TARGETS[*]}"
        return 0
    fi

    if ! prompt_confirm "$verb dotfiles from $DOTFILES_DIR into \$HOME?" "true"; then
        SYMLINK_TARGETS=()
        return 0
    fi

    local picked
    picked="$(prompt_choose_many "Select paths to $verb (suggested from your selections)" "${defaults[@]}")"
    SYMLINK_TARGETS=()
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -n "$p" ]] && SYMLINK_TARGETS+=("$p")
    done <<< "$picked"
}

run_category_pickers() {
    prompt_style "── Fonts ──"
    collect_category "fonts" "Select coding fonts"

    prompt_style "── Developer Software ──"
    collect_category "dev-tools" "Select developer software"

    prompt_style "── Shell ──"
    collect_shell

    prompt_style "── Shell Configuration ──"
    local shell_filter="zsh"
    [[ -n "${SELECTED_SHELL:-}" ]] && shell_filter="$SELECTED_SHELL"
    collect_category "shell-configs" "Select shell tools & configs" "$shell_filter"
}

run_wizard() {
    init_platform
    state_init
    load_setup_prefs
    ensure_gum || prompt_warn "gum not available — using basic prompts."
    load_catalogs

    prompt_welcome "Developer Machine Setup" "$(platform_label)"
    ensure_dotfiles_location
    maybe_resume_menu

    choose_package_manager
    prompt_info "Package manager: $PKG_MGR"
    ensure_pkgmgr "$PKG_MGR"

    dry_run_begin_plan
    installer_clear_selections
    SELECTED_SHELL=""
    SYMLINK_TARGETS=()
    INSTALL_REPORT_OK=()
    INSTALL_REPORT_SKIP=()
    INSTALL_REPORT_FAIL=()
    INSTALL_REPORT_CONFIG=()

    if [[ -n "$PLAN_FILE" ]]; then
        load_plan_file "$PLAN_FILE"
    else
        choose_preset
        if [[ "$PRESET_NAME" == "custom" ]]; then
            run_category_pickers
        else
            prompt_info "Preset: $PRESET_NAME"
            apply_preset_selections
            # Still allow shell pick if preset didn't include one
            if [[ -z "${SELECTED_SHELL:-}" && -z "${YES_MODE:-}" ]]; then
                prompt_style "── Shell ──"
                collect_shell
            fi
        fi
    fi

    prompt_dependency_hints
    resolve_shell_profile_conflict
    configure_git_interactive
    collect_symlinks

    # Summary
    echo ""
    prompt_style "── Summary ──"
    echo "  Preset: ${PRESET_NAME:-custom}"
    echo "  Profile: ${SHELL_PROFILE_MODE:-none}"
    echo "  Link mode: $LINK_MODE"
    echo "  Dotfiles: $DOTFILES_DIR"
    local id
    for id in "${SELECTED_IDS[@]}"; do
        echo "  • $(catalog_get "$id" name)"
    done
    for p in "${SYMLINK_TARGETS[@]:-}"; do
        echo "  • $LINK_MODE $p"
    done
    echo "  Package manager: $PKG_MGR"
    dry_run_is_active && echo "  Mode: DRY RUN" || true

    if [[ -n "${EXPORT_PLAN:-}" ]] || [[ -z "${YES_MODE:-}" ]]; then
        local plan_out="${EXPORT_PLAN:-$STATE_DIR/last-plan.env}"
        if [[ -n "${EXPORT_PLAN:-}" ]] || prompt_confirm "Save this plan for later (--plan)?" "true"; then
            export_plan_file "$plan_out"
        fi
    fi

    local action="Install now"
    if [[ -z "${YES_MODE:-}" ]]; then
        if dry_run_is_active; then
            action="Preview plan"
        else
            action="$(prompt_choose_one "What next?" "Preview install plan" "Install now" "Cancel")"
        fi
    elif dry_run_is_active; then
        action="Preview plan"
    fi

    if [[ "$action" == "Cancel" ]]; then
        prompt_warn "Cancelled."
        exit 0
    fi

    if [[ "$action" == "Preview install plan" || "$action" == "Preview plan" ]] || dry_run_is_active; then
        local was_dry="$DRY_RUN"
        DRY_RUN=1
        install_prerequisites
        installer_plan_selections
        for p in "${SYMLINK_TARGETS[@]:-}"; do
            install_dotfile_path "$p"
        done
        write_shell_features
        configure_starship
        configure_oh_my_zsh_profile
        if [[ -n "${SELECTED_SHELL:-}" ]]; then
            maybe_chsh "$SELECTED_SHELL"
        fi
        dry_run_print_plan "Install Plan"
        DRY_RUN="$was_dry"

        if dry_run_is_active; then
            prompt_info "Dry run complete — no changes made."
            save_setup_prefs
            exit 0
        fi

        if ! prompt_confirm "Proceed with install?"; then
            prompt_warn "Cancelled after preview."
            exit 0
        fi
    fi

    # Real install
    DRY_RUN=""
    install_prerequisites
    installer_run_selections
    for p in "${SYMLINK_TARGETS[@]:-}"; do
        install_dotfile_path "$p"
    done
    write_shell_features
    configure_starship
    configure_oh_my_zsh_profile
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        maybe_chsh "$SELECTED_SHELL"
    fi

    save_setup_prefs
    export_plan_file "$STATE_DIR/last-plan.env"
    print_final_report
    prompt_welcome "Setup complete!" "Restart your terminal to apply changes"
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
        revert_setup)
            run_undo "false"
            ;;
        symlink_dotfile|unlink_dotfile)
            "$RUN_COMMAND" "${RUN_COMMAND_ARGS[@]:-}"
            ;;
        *)
            "$RUN_COMMAND"
            ;;
    esac
    echo ""
    prompt_success "Command complete!"
    exit 0
fi

run_wizard
