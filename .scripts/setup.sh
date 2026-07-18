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

# Flags
DRY_RUN=""
YES_MODE=""
UNDO_MODE=""
UNDO_SELECT=""
PKG_MGR_FLAG=""
RUN_COMMAND=""

usage() {
    cat <<'EOF'
Developer Machine Setup Wizard (macOS + Linux)

Usage:
  ./setup.sh [options]
  ./setup.sh -c <command>

Options:
  -h, --help          Show this help
  -y, --yes           Non-interactive: accept defaults / select all available items
  -n, --dry-run       Preview commands and paths; make no changes
  --undo              Reverse actions recorded in the install log
  --select            With --undo: choose which logged items to undo
  --pkgmgr <name>     Package manager: brew | apt | dnf | pacman
  -c <command>        Run a single helper command

Helpers (-c):
  move_dotfiles
  remove_git_origin_remote
  symlink_dotfile <path>
  unlink_dotfile <path>
  uninstall_nvm
  revert_setup        Same as --undo

Examples:
  ./setup.sh
  ./setup.sh --dry-run
  ./setup.sh -y --dry-run --pkgmgr apt
  ./setup.sh --undo
  ./setup.sh --undo --dry-run
  ./setup.sh -c move_dotfiles

State:
  Install log: ~/.dotfiles-setup/install-log.jsonl
  Backups:     ~/.dotfiles-setup/backups/
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
            -c)
                RUN_COMMAND="${2:-}"
                shift 2
                # Remaining args for the command
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

choose_package_manager() {
    if [[ -n "$PKG_MGR_FLAG" ]]; then
        PKG_MGR="$PKG_MGR_FLAG"
        return 0
    fi

    load_pkgmgr_pref
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
    save_pkgmgr_pref "$PKG_MGR"
}

collect_category() {
    local category="$1"
    local header="$2"
    local filter_shells="${3:-}"  # optional: comma list of shells to filter shell-configs

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

# Single-select for shells (zsh | fish), allow skip
collect_shell() {
    local labels=()
    local id
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        catalog_available "$id" || continue
        labels+=("$(catalog_label "$id")")
    done < <(catalog_ids_by_category "shells")

    # Non-interactive: prefer zsh when available
    if [[ -n "${YES_MODE:-}" ]]; then
        for id in $(catalog_ids_by_category "shells"); do
            if [[ "$id" == "zsh" ]] && catalog_available "$id"; then
                installer_add_selection "zsh"
                SELECTED_SHELL="zsh"
                return 0
            fi
        done
        if [[ ${#labels[@]} -gt 0 ]]; then
            local cid
            cid="$(catalog_id_from_label "${labels[0]}")" || true
            if [[ -n "${cid:-}" ]]; then
                installer_add_selection "$cid"
                SELECTED_SHELL="$cid"
            fi
        fi
        return 0
    fi

    labels=("Skip — keep current shell" "${labels[@]}")
    local choice
    choice="$(prompt_choose_one "Choose a shell (bash is not offered — already default on most Linux / zsh on modern macOS)" "${labels[@]}")"
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
    local options=()
    options+=(".zshrc")
    options+=(".config")
    [[ " ${SELECTED_IDS[*]} " == *" warp "* ]] && options+=(".warp")
    [[ " ${SELECTED_IDS[*]} " == *" zed "* ]] && options+=(".config/zed")
    [[ " ${SELECTED_IDS[*]} " == *" fish "* || "$SELECTED_SHELL" == "fish" ]] && options+=(".config/fish")

    if ! prompt_confirm "Symlink dotfiles from $DOTFILES_DIR?" "true"; then
        SYMLINK_TARGETS=()
        return 0
    fi

    local picked
    picked="$(prompt_choose_many "Select paths to symlink" "${options[@]}")"
    SYMLINK_TARGETS=()
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -n "$p" ]] && SYMLINK_TARGETS+=("$p")
    done <<< "$picked"
}

run_wizard() {
    init_platform
    state_init
    ensure_gum || prompt_warn "gum not available — using basic prompts."
    load_catalogs

    prompt_welcome "Developer Machine Setup" "$(platform_label)"

    if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" ]]; then
        prompt_error "Dotfiles are not in \$HOME/dotfiles (currently: $DOTFILES_DIR)."
        if prompt_confirm "Run move_dotfiles now?"; then
            move_dotfiles
            DOTFILES_DIR="$HOME/dotfiles"
        else
            prompt_info "Run: ./setup.sh -c move_dotfiles"
            exit 1
        fi
    fi

    choose_package_manager
    prompt_info "Package manager: $PKG_MGR"
    ensure_pkgmgr "$PKG_MGR"

    dry_run_begin_plan
    installer_clear_selections
    SELECTED_SHELL=""
    SYMLINK_TARGETS=()

    install_prerequisites

    prompt_style "── Fonts ──"
    collect_category "fonts" "Select coding fonts (space to toggle / multi-select)"

    prompt_style "── Developer Software ──"
    collect_category "dev-tools" "Select developer software"

    prompt_style "── Shell ──"
    collect_shell

    prompt_style "── Shell Configuration ──"
    local shell_filter=""
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        shell_filter="$SELECTED_SHELL"
    else
        shell_filter="zsh,fish"
    fi
    collect_category "shell-configs" "Select shell tools & configs" "$shell_filter"

    configure_git_interactive
    collect_symlinks

    # Summary
    echo ""
    prompt_style "── Summary ──"
    local id
    for id in "${SELECTED_IDS[@]}"; do
        echo "  • $(catalog_get "$id" name)"
    done
    for p in "${SYMLINK_TARGETS[@]:-}"; do
        echo "  • symlink $p"
    done
    echo "  Package manager: $PKG_MGR"
    dry_run_is_active && echo "  Mode: DRY RUN" || true

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
        installer_plan_selections
        for p in "${SYMLINK_TARGETS[@]:-}"; do
            symlink_dotfile_safe "$p"
        done
        if [[ -n "${SELECTED_SHELL:-}" ]]; then
            maybe_chsh "$SELECTED_SHELL"
        fi
        dry_run_print_plan "Install Plan"
        DRY_RUN="$was_dry"

        if dry_run_is_active; then
            prompt_info "Dry run complete — no changes made."
            exit 0
        fi

        if ! prompt_confirm "Proceed with install?"; then
            prompt_warn "Cancelled after preview."
            exit 0
        fi
    fi

    # Real install
    DRY_RUN=""
    installer_run_selections
    for p in "${SYMLINK_TARGETS[@]:-}"; do
        symlink_dotfile_safe "$p"
    done
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        maybe_chsh "$SELECTED_SHELL"
    fi

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
        load_pkgmgr_pref
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
