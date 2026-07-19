#!/bin/bash
# Your usual setup — single source of truth for the default stack

# Core tools you rely on every machine (Cursor is the default editor)
MY_SETUP="sfmono_nerd starship eza warp cursor zed zsh nvm zsh_autosuggestions zsh_syntax_highlighting z"

# macOS-only extras
MY_SETUP_MACOS="raycast"

# Optional extras when a recipe is available for this OS / pkgmgr
MY_SETUP_OPTIONAL="vscode"

# Help-screen groupings (keep in sync with MY_SETUP*)
HELP_INCLUDES_EDITORS="Cursor (default), Zed · VS Code optional"
HELP_INCLUDES_TERMINAL="Warp · SFMono · Starship · eza"
HELP_INCLUDES_SHELL="zsh + plugins · NVM · Raycast (macOS)"

PRESET_NAME="mine"
PRESET_IDS=""

my_setup_ids() {
    local ids="$MY_SETUP"
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        ids="$ids $MY_SETUP_MACOS"
    fi
    local id
    for id in $MY_SETUP_OPTIONAL; do
        if catalog_available "$id" 2>/dev/null; then
            ids="$ids $id"
        fi
    done
    echo "$ids"
}

# Apply the full default stack (used by -y / non-interactive).
apply_my_setup() {
    PRESET_NAME="mine"
    PRESET_IDS="$(my_setup_ids)"
    installer_clear_selections
    SELECTED_SHELL=""
    local id
    for id in $PRESET_IDS; do
        catalog_available "$id" || continue
        installer_add_selection "$id"
        if [[ "$(catalog_get "$id" category)" == "shells" ]]; then
            SELECTED_SHELL="$id"
        fi
    done
}

# Interactive multi-select from the usual stack (defaults pre-selected).
# -y keeps the full default set without prompting.
pick_my_setup() {
    if [[ -n "${YES_MODE:-}" ]]; then
        apply_my_setup
        return 0
    fi

    local labels=()
    local id
    for id in $(my_setup_ids); do
        catalog_available "$id" || continue
        labels+=("$(catalog_label "$id")")
    done

    if [[ ${#labels[@]} -eq 0 ]]; then
        prompt_error "No packages available for ${PKG_MGR:-?} on ${PLATFORM:-?}."
        return 1
    fi

    echo ""
    prompt_style "Choose packages"
    prompt_info "Defaults from your usual stack are pre-selected — add or remove as you like."

    local picked=""
    picked="$(prompt_choose_many "Select packages to install" "${labels[@]}")"

    if [[ -z "$(echo "$picked" | sed '/^$/d')" ]]; then
        prompt_warn "Nothing selected — cancelled."
        return 1
    fi

    installer_clear_selections
    SELECTED_SHELL=""
    PRESET_NAME="mine"

    local label picked_id
    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        picked_id="$(catalog_id_from_label "$label")" || {
            prompt_warn "Could not resolve selection: $label"
            continue
        }
        installer_add_selection "$picked_id"
        if [[ "$(catalog_get "$picked_id" category)" == "shells" ]]; then
            SELECTED_SHELL="$picked_id"
        fi
    done <<< "$picked"

    if [[ ${#SELECTED_IDS[@]} -eq 0 ]]; then
        prompt_warn "Nothing selected — cancelled."
        return 1
    fi

    PRESET_IDS="${SELECTED_IDS[*]}"
    return 0
}

print_my_setup_summary() {
    local id
    echo "  Selected packages:"
    for id in "${SELECTED_IDS[@]}"; do
        echo "    • $(catalog_get "$id" name)"
    done
    local links=".zshrc .zshenv .config"
    [[ " ${SYMLINK_TARGETS[*]:-} " == *" .warp "* ]] && links="$links .warp"
    echo "    • symlink $links (as applicable)"
    if [[ " ${SELECTED_IDS[*]} " == *" starship "* ]] \
        || [[ " ${SELECTED_IDS[*]} " == *" zsh_autosuggestions "* ]] \
        || [[ " ${SELECTED_IDS[*]} " == *" zsh_syntax_highlighting "* ]]; then
        echo "    • Starship / zsh plugins via this repo’s configs (when selected)"
    fi
}
