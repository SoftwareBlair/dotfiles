#!/bin/bash
# Stack selection helpers — package defaults come from profiles/<GitHubUser>.toml

PRESET_NAME=""
PRESET_IDS=""

# Fallback if a profile has not been loaded yet (tests / early help).
MY_SETUP="${MY_SETUP:-}"
MY_SETUP_MACOS="${MY_SETUP_MACOS:-}"
MY_SETUP_OPTIONAL="${MY_SETUP_OPTIONAL:-}"
HELP_INCLUDES_EDITORS="${HELP_INCLUDES_EDITORS:-Cursor, Zed}"
HELP_INCLUDES_TERMINAL="${HELP_INCLUDES_TERMINAL:-Starship · eza}"
HELP_INCLUDES_SHELL="${HELP_INCLUDES_SHELL:-zsh + plugins}"

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

# Apply the full default stack for the loaded profile (used by -y / non-interactive).
apply_my_setup() {
    PRESET_NAME="${PROFILE_ID:-mine}"
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

# Apply an explicit ID list (space-separated), e.g. from the Go TUI via SETUP_SELECTION_IDS.
apply_selection_ids() {
    local ids="$1"
    installer_clear_selections
    SELECTED_SHELL=""
    PRESET_NAME="${PROFILE_ID:-mine}"
    local id
    for id in $ids; do
        [[ -z "$id" ]] && continue
        catalog_available "$id" || continue
        installer_add_selection "$id"
        if [[ "$(catalog_get "$id" category)" == "shells" ]]; then
            SELECTED_SHELL="$id"
        fi
    done
    PRESET_IDS="${SELECTED_IDS[*]}"
    [[ ${#SELECTED_IDS[@]} -gt 0 ]]
}

# Interactive multi-select from the profile stack (defaults pre-selected).
# -y keeps the full default set without prompting.
# SETUP_SELECTION_IDS (space-separated) applies a precomputed selection (TUI / tests).
pick_my_setup() {
    if [[ -n "${SETUP_SELECTION_IDS:-}" ]]; then
        apply_selection_ids "$SETUP_SELECTION_IDS"
        return $?
    fi

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
    if [[ -n "${PROFILE_ID:-}" ]]; then
        prompt_info "Defaults from @${PROFILE_ID} are pre-selected — add or remove as you like."
    else
        prompt_info "Defaults from the selected profile are pre-selected — add or remove as you like."
    fi

    local picked=""
    picked="$(prompt_choose_many "Select packages to install" "${labels[@]}")"

    if [[ -z "$(echo "$picked" | sed '/^$/d')" ]]; then
        prompt_warn "Nothing selected — cancelled."
        return 1
    fi

    installer_clear_selections
    SELECTED_SHELL=""
    PRESET_NAME="${PROFILE_ID:-mine}"

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
    if [[ -n "${PROFILE_ID:-}" ]]; then
        echo "  Profile: ${PROFILE_NAME:-$PROFILE_ID} (@${PROFILE_ID})"
    fi
    echo "  Selected packages:"
    for id in "${SELECTED_IDS[@]}"; do
        echo "    • $(catalog_get "$id" name)"
    done
    local links=""
    local p
    for p in "${SYMLINK_TARGETS[@]:-}"; do
        links="$links $p"
    done
    links="${links# }"
    [[ -n "$links" ]] && echo "    • symlink $links (as applicable)"
    if [[ " ${SELECTED_IDS[*]} " == *" starship "* ]] \
        || [[ " ${SELECTED_IDS[*]} " == *" zsh_autosuggestions "* ]] \
        || [[ " ${SELECTED_IDS[*]} " == *" zsh_syntax_highlighting "* ]]; then
        echo "    • Starship / zsh plugins via profile configs (when selected)"
    fi
}
