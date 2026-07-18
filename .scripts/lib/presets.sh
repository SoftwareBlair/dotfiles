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
    echo "    • symlink .zshrc .zshenv .config .warp (as applicable)"
    echo "    • Starship + zsh plugins via this repo’s configs"
}
