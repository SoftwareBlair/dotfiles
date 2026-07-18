#!/bin/bash
# Your usual setup — aligned with improvements-while-using (+ SFMono, Zed)

# Core tools you rely on every machine
MY_SETUP="sfmono_nerd starship eza warp zed zsh nvm zsh_autosuggestions zsh_syntax_highlighting z"

# macOS-only extras from your improvements branch
MY_SETUP_MACOS="raycast"

# Optional but commonly used with your git/editor flow
MY_SETUP_OPTIONAL="vscode"

PRESET_NAME="mine"
PRESET_IDS=""

my_setup_ids() {
    local ids="$MY_SETUP"
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        ids="$ids $MY_SETUP_MACOS"
    fi
    # Include optional items that are available
    local id
    for id in $MY_SETUP_OPTIONAL; do
        if catalog_available "$id" 2>/dev/null; then
            ids="$ids $id"
        fi
    done
    echo "$ids"
}

# Apply into SELECTED_IDS / SELECTED_SHELL
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

print_my_setup_summary() {
    local id
    echo "  Your usual setup:"
    for id in "${SELECTED_IDS[@]}"; do
        echo "    • $(catalog_get "$id" name)"
    done
    echo "    • symlink .zshrc .zshenv .config .warp .config/zed (as applicable)"
    echo "    • Starship + zsh plugins via this repo’s configs"
}

# Kept for any leftover callers
choose_preset() {
    apply_my_setup
}

apply_preset_selections() {
    apply_my_setup
}

preset_ids_for() {
    my_setup_ids
}

suggest_dependencies() { echo ""; }
prompt_dependency_hints() { return 0; }
