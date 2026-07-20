#!/bin/bash
# Stack selection helpers — package defaults come from profiles/<GitHubUser>.toml

PRESET_NAME=""
PRESET_IDS=""

MY_SETUP="${MY_SETUP:-}"
MY_SETUP_MACOS="${MY_SETUP_MACOS:-}"
MY_SETUP_OPTIONAL="${MY_SETUP_OPTIONAL:-}"
HELP_INCLUDES_EDITORS="${HELP_INCLUDES_EDITORS:-}"
HELP_INCLUDES_TERMINAL="${HELP_INCLUDES_TERMINAL:-}"
HELP_INCLUDES_SHELL="${HELP_INCLUDES_SHELL:-}"

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

apply_my_setup() {
    PRESET_NAME="${PROFILE_ID:-default}"
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

apply_selection_ids() {
    local ids="$1"
    installer_clear_selections
    SELECTED_SHELL=""
    PRESET_NAME="${PROFILE_ID:-default}"
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

pick_my_setup() {
    # Profiles own the package set — no interactive package/module picker.
    if [[ -n "${SETUP_SELECTION_IDS:-}" ]]; then
        apply_selection_ids "$SETUP_SELECTION_IDS"
        return $?
    fi

    apply_my_setup
    if [[ ${#SELECTED_IDS[@]} -eq 0 ]]; then
        prompt_error "Profile @${PROFILE_ID:-?} has no packages available for ${PKG_MGR:-?} on ${PLATFORM:-?}."
        return 1
    fi
    return 0
}

print_my_setup_summary() {
    local id cat
    if [[ -n "${PROFILE_ID:-}" ]]; then
        echo "  Profile: ${PROFILE_NAME:-$PROFILE_ID} (@${PROFILE_ID})"
    fi
    echo "  Selected:"
    for id in "${SELECTED_IDS[@]}"; do
        cat="$(catalog_get "$id" category)"
        if [[ "$(catalog_get "$id" generate_only)" == "true" ]]; then
            echo "    • $(catalog_get "$id" name)  [generate]"
        else
            echo "    • $(catalog_get "$id" name)  [$cat]"
        fi
    done
    echo "    • generate ~/.zshrc + ~/.dotfiles-setup/generated/ (selected modules)"
}
