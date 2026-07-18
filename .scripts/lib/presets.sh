#!/bin/bash
# Curated install presets

# Preset IDs (space-separated catalog ids)
PRESET_MINIMAL="zsh starship eza"
PRESET_PERSONAL="sfmono_nerd jetbrainsmono_nerd vscode warp zed zsh starship eza nvm zsh_autosuggestions zsh_syntax_highlighting fzf zoxide"
PRESET_FULL="" # computed: all available for current platform/pkgmgr

PRESET_NAME=""
PRESET_IDS=""

preset_list_labels() {
    echo "Personal favorites (SFMono, Warp, Zed, zsh, Starship, eza, …)"
    echo "Minimal (zsh + Starship + eza)"
    echo "Full catalog (everything available)"
    echo "Custom (pick each category)"
    if [[ -n "${LAST_PRESET:-}" && "$LAST_PRESET" != "custom" ]]; then
        echo "Last used ($LAST_PRESET)"
    fi
}

preset_ids_for() {
    local name="$1"
    case "$name" in
        minimal) echo "$PRESET_MINIMAL" ;;
        personal) echo "$PRESET_PERSONAL" ;;
        full)
            local id all=""
            for id in $CATALOG_IDS; do
                catalog_available "$id" || continue
                all="${all:+$all }$id"
            done
            echo "$all"
            ;;
        last)
            echo "${LAST_SELECTION_IDS:-$PRESET_PERSONAL}"
            ;;
        *) echo "" ;;
    esac
}

choose_preset() {
    if [[ -n "${PRESET_FLAG:-}" ]]; then
        PRESET_NAME="$PRESET_FLAG"
        PRESET_IDS="$(preset_ids_for "$PRESET_NAME")"
        return 0
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        PRESET_NAME="${PRESET_NAME:-personal}"
        PRESET_IDS="$(preset_ids_for "$PRESET_NAME")"
        return 0
    fi

    local labels=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && labels+=("$line")
    done < <(preset_list_labels)

    local choice
    choice="$(prompt_choose_one "Choose a setup preset" "${labels[@]}")"

    case "$choice" in
        Personal*) PRESET_NAME="personal" ;;
        Minimal*) PRESET_NAME="minimal" ;;
        Full*) PRESET_NAME="full" ;;
        Last*) PRESET_NAME="last" ;;
        Custom*|*) PRESET_NAME="custom" ;;
    esac

    if [[ "$PRESET_NAME" == "custom" ]]; then
        PRESET_IDS=""
    else
        PRESET_IDS="$(preset_ids_for "$PRESET_NAME")"
    fi
}

# Apply preset IDs into SELECTED_IDS / SELECTED_SHELL (filter unavailable)
apply_preset_selections() {
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

# Dependency suggestions: returns extra ids that should be recommended
suggest_dependencies() {
    local id
    local suggestions=""
    for id in "${SELECTED_IDS[@]}"; do
        case "$id" in
            starship)
                # Suggest a nerd font if none selected
                local has_font=false
                local s
                for s in "${SELECTED_IDS[@]}"; do
                    [[ "$(catalog_get "$s" category)" == "fonts" ]] && has_font=true
                done
                if [[ "$has_font" == "false" ]]; then
                    suggestions="${suggestions:+$suggestions }sfmono_nerd"
                fi
                ;;
            oh_my_zsh)
                [[ " ${SELECTED_IDS[*]} " != *" zsh "* ]] && suggestions="${suggestions:+$suggestions }zsh"
                ;;
        esac
    done
    echo "$suggestions"
}

prompt_dependency_hints() {
    local deps
    deps="$(suggest_dependencies)"
    [[ -z "$deps" ]] && return 0

    local labels=()
    local id
    for id in $deps; do
        catalog_available "$id" || continue
        [[ " ${SELECTED_IDS[*]} " == *" $id "* ]] && continue
        labels+=("$(catalog_label "$id")")
    done
    [[ ${#labels[@]} -eq 0 ]] && return 0

    prompt_style "── Suggested add-ons ──"
    prompt_info "Based on your selections, these are recommended:"
    local picked
    if [[ -n "${YES_MODE:-}" ]]; then
        picked="$(printf '%s\n' "${labels[@]}")"
    else
        picked="$(prompt_choose_many "Add recommended items? (optional)" "${labels[@]}")"
    fi
    while IFS= read -r label || [[ -n "$label" ]]; do
        [[ -z "$label" ]] && continue
        local cid
        cid="$(catalog_id_from_label "$label")" || continue
        installer_add_selection "$cid"
    done <<< "$picked"
}
