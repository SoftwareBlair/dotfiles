#!/bin/bash
# Brew-first stack selection: fixed shell + interactive app picker

PRESET_NAME=""
PRESET_IDS=""

# Core shell — always installed (no Oh My Zsh)
SHELL_IDS="${SHELL_IDS:-zsh starship zsh_autosuggestions zsh_syntax_highlighting eza z zsh_aliases}"

# App/tools picker — [default] ids are pre-selected in gum
# nvm folded into apps (pre-selected); browsers/chat/cli mostly opt-in
APP_DEFAULT_IDS="${APP_DEFAULT_IDS:-cursor warp nvm}"
APP_OPTIONAL_IDS="${APP_OPTIONAL_IDS:-vscode zed raycast sfmono_nerd chrome firefox zen helium onepassword onepassword_cli discord slack signal vlc gh wget curl_brew docker python go pnpm yarn}"

HELP_INCLUDES_EDITORS="${HELP_INCLUDES_EDITORS:-Cursor, VS Code, Zed}"
HELP_INCLUDES_TERMINAL="${HELP_INCLUDES_TERMINAL:-Warp · Starship · eza}"
HELP_INCLUDES_SHELL="${HELP_INCLUDES_SHELL:-zsh + Starship (no Oh My Zsh)}"

# Backward-compat aliases used by older helpers / docs
MY_SETUP="${MY_SETUP:-$SHELL_IDS $APP_DEFAULT_IDS}"
MY_SETUP_MACOS="${MY_SETUP_MACOS:-raycast}"
MY_SETUP_OPTIONAL="${MY_SETUP_OPTIONAL:-$APP_OPTIONAL_IDS}"

shell_ids_available() {
    local id
    for id in $SHELL_IDS; do
        catalog_available "$id" 2>/dev/null || continue
        echo "$id"
    done
}

# Used by wizard-export / profiles tooling
my_setup_ids() {
    local ids="" id
    for id in $(shell_ids_available); do
        ids+="$id "
    done
    for id in $APP_DEFAULT_IDS; do
        catalog_available "$id" 2>/dev/null || continue
        ids+="$id "
    done
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        catalog_available raycast 2>/dev/null && ids+="raycast "
    fi
    echo "$ids"
}

app_ids_all() {
    local id seen=" "
    for id in $APP_DEFAULT_IDS $APP_OPTIONAL_IDS; do
        [[ "$seen" == *" $id "* ]] && continue
        seen+=" $id "
        catalog_available "$id" 2>/dev/null || continue
        # Never offer Oh My Zsh in this flow
        [[ "$id" == "oh_my_zsh" ]] && continue
        echo "$id"
    done
}

apply_shell_stack() {
    local id
    SELECTED_SHELL=""
    for id in $(shell_ids_available); do
        installer_add_selection "$id"
        if [[ "$(catalog_get "$id" category)" == "shells" ]]; then
            SELECTED_SHELL="$id"
        fi
    done
}

apply_app_ids() {
    local ids="$1"
    local id
    for id in $ids; do
        [[ -z "$id" ]] && continue
        [[ "$id" == "oh_my_zsh" ]] && continue
        catalog_available "$id" || continue
        installer_add_selection "$id"
    done
}

apply_selection_ids() {
    local ids="$1"
    installer_clear_selections
    SELECTED_SHELL=""
    PRESET_NAME="brew-first"
    local id
    for id in $ids; do
        [[ -z "$id" ]] && continue
        [[ "$id" == "oh_my_zsh" ]] && continue
        catalog_available "$id" || continue
        installer_add_selection "$id"
        if [[ "$(catalog_get "$id" category)" == "shells" ]]; then
            SELECTED_SHELL="$id"
        fi
    done
    PRESET_IDS="${SELECTED_IDS[*]}"
    [[ ${#SELECTED_IDS[@]} -gt 0 ]]
}

# Full default stack (shell + default apps) for -y
apply_default_stack() {
    installer_clear_selections
    PRESET_NAME="brew-first"
    apply_shell_stack
    apply_app_ids "$APP_DEFAULT_IDS"
    # macOS extras that are defaults
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        catalog_available raycast 2>/dev/null && installer_add_selection raycast
    fi
    PRESET_IDS="${SELECTED_IDS[*]}"
    [[ ${#SELECTED_IDS[@]} -gt 0 ]]
}

pick_apps() {
    local labels=()
    local id
    # Mark defaults for gum pre-selection via catalog_is_default / [default] labels
    DEFAULT_CATALOG_IDS="$APP_DEFAULT_IDS"
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        DEFAULT_CATALOG_IDS+=" raycast"
    fi
    export DEFAULT_CATALOG_IDS

    for id in $(app_ids_all); do
        labels+=("$(catalog_label "$id")")
    done

    if [[ ${#labels[@]} -eq 0 ]]; then
        prompt_warn "No optional apps available for brew on ${PLATFORM:-?}."
        return 0
    fi

    echo ""
    prompt_style "Choose apps & tools"
    prompt_info "Shell stack is already selected. Toggle apps below (space / enter)."

    local picked=""
    picked="$(prompt_choose_many "Select apps to install via Homebrew" "${labels[@]}")"

    local label picked_id
    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        picked_id="$(catalog_id_from_label "$label")" || {
            prompt_warn "Could not resolve selection: $label"
            continue
        }
        installer_add_selection "$picked_id"
    done <<< "$picked"
    return 0
}

pick_my_setup() {
    if [[ -n "${SETUP_SELECTION_IDS:-}" ]]; then
        apply_selection_ids "$SETUP_SELECTION_IDS"
        return $?
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        apply_default_stack
        return $?
    fi

    installer_clear_selections
    PRESET_NAME="brew-first"
    apply_shell_stack

    if [[ ${#SELECTED_IDS[@]} -eq 0 ]]; then
        prompt_error "No shell packages available for brew on ${PLATFORM:-?}."
        return 1
    fi

    pick_apps
    PRESET_IDS="${SELECTED_IDS[*]}"
    return 0
}

print_my_setup_summary() {
    local id cat
    echo "  Package manager: brew"
    echo "  Shell (fixed):"
    for id in "${SELECTED_IDS[@]}"; do
        cat="$(catalog_get "$id" category)"
        case "$cat" in
            shells|shell-configs)
                if [[ "$(catalog_get "$id" generate_only)" == "true" ]]; then
                    echo "    • $(catalog_get "$id" name)  [generate]"
                else
                    echo "    • $(catalog_get "$id" name)"
                fi
                ;;
        esac
    done
    echo "  Apps & tools:"
    local any_app=0
    for id in "${SELECTED_IDS[@]}"; do
        cat="$(catalog_get "$id" category)"
        case "$cat" in
            shells|shell-configs) continue ;;
        esac
        any_app=1
        echo "    • $(catalog_get "$id" name)  [$cat]"
    done
    [[ "$any_app" -eq 0 ]] && echo "    (none)"
    echo "    • generate ~/.zshrc + modules under ~/.dotfiles-setup/generated/"
}
