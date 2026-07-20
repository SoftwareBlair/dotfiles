#!/bin/bash
# Generate shell configs into $HOME from selected packages + themes

GENERATED_DIR="${GENERATED_DIR:-$HOME/.dotfiles-setup/generated}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$DOTFILES_DIR/templates}"
THEME_STARSHIP="${THEME_STARSHIP:-stock}"

# Map selection id → generated module filename (without .zsh)
# Empty = orchestrator only / no module file
generate_module_name() {
    case "$1" in
        zsh_aliases) echo "aliases" ;;
        oh_my_zsh) echo "oh-my-zsh" ;;
        starship|nvm|zsh_autosuggestions|zsh_syntax_highlighting|z|eza) echo "$1" ;;
        zsh) echo "" ;;  # orchestrator only
        *) echo "" ;;
    esac
}

# True if id needs a package install (vs generate-only)
generate_needs_install() {
    case "$1" in
        zsh_aliases) return 1 ;;
        *) return 0 ;;
    esac
}

generate_templates_root() {
    echo "${TEMPLATES_DIR:-$DOTFILES_DIR/templates}"
}

# Write one file with backup + state log
_generate_write_file() {
    local target="$1"
    local content="$2"
    local name="${3:-generate $(basename "$target")}"

    if dry_run_is_active 2>/dev/null; then
        dry_run_add_step "$name" "write $target" "$target" "backup if exists" "false" ""
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    local backup=""
    if [[ -e "$target" || -L "$target" ]]; then
        if declare -f state_backup_path >/dev/null 2>&1; then
            backup="$(state_backup_path "$target")"
        fi
    fi
    printf '%s\n' "$content" > "$target"
    if declare -f state_log_install >/dev/null 2>&1; then
        state_log_install "gen-$(basename "$target")" "$name" "config" \
            "write $target" "$target" "$backup" "" "" ""
    fi
    if declare -f report_config >/dev/null 2>&1; then
        report_config "Generated $target"
    fi
}

# Copy template file to target
_generate_copy_template() {
    local src="$1"
    local dest="$2"
    local name="${3:-generate $(basename "$dest")}"
    [[ -f "$src" ]] || return 1

    if dry_run_is_active 2>/dev/null; then
        dry_run_add_step "$name" "cp $src → $dest" "$dest" "" "false" ""
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    local backup=""
    if [[ -e "$dest" || -L "$dest" ]]; then
        if declare -f state_backup_path >/dev/null 2>&1; then
            backup="$(state_backup_path "$dest")"
        fi
    fi
    cp "$src" "$dest"
    if declare -f state_log_install >/dev/null 2>&1; then
        state_log_install "gen-$(basename "$dest")" "$name" "config" \
            "cp $src $dest" "$dest" "$backup" "" "" ""
    fi
    if declare -f report_config >/dev/null 2>&1; then
        report_config "Generated $dest"
    fi
}

# Build MODULE_SOURCES block for zshrc from selected module files
_generate_module_sources() {
    local mods=("$@")
    local m line=""
    for m in "${mods[@]}"; do
        [[ -z "$m" ]] && continue
        line="${line}[[ -f \"\$GEN/${m}.zsh\" ]] && source \"\$GEN/${m}.zsh\"
"
    done
    printf '%s' "$line"
}

# Remove previously generated modules not in the current selection
_generate_prune_modules() {
    local keep=("$@")
    local f base keep_list=" ${keep[*]} "
    [[ -d "$GENERATED_DIR" ]] || return 0
    for f in "$GENERATED_DIR"/*.zsh; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f" .zsh)"
        if [[ "$keep_list" != *" $base "* ]]; then
            if dry_run_is_active 2>/dev/null; then
                dry_run_add_step "Prune module $base" "rm $f" "$f" "" "false" ""
            else
                rm -f "$f"
            fi
        fi
    done
}

# Main entry: generate configs for SELECTED_IDS + themes
# Uses: SELECTED_IDS, THEME_STARSHIP, DOTFILES_DIR, GENERATED_DIR
generate_configs() {
    local root
    root="$(generate_templates_root)"
    GENERATED_DIR="${HOME}/.dotfiles-setup/generated"

    local id mod modules=()
    local has_starship=0 has_omz=0 has_aliases=0 has_eza=0

    for id in "${SELECTED_IDS[@]:-}"; do
        [[ -z "$id" ]] && continue
        case "$id" in
            starship) has_starship=1 ;;
            oh_my_zsh) has_omz=1 ;;
            zsh_aliases) has_aliases=1 ;;
            eza) has_eza=1 ;;
        esac
        mod="$(generate_module_name "$id")"
        [[ -n "$mod" ]] && modules+=("$mod")
    done

    # If eza selected but aliases also selected, skip separate eza module (aliases covers it)
    if [[ "$has_aliases" -eq 1 && "$has_eza" -eq 1 ]]; then
        local filtered=()
        for mod in "${modules[@]}"; do
            [[ "$mod" == "eza" ]] && continue
            filtered+=("$mod")
        done
        modules=("${filtered[@]}")
    fi

    _generate_prune_modules "${modules[@]}"

    if ! dry_run_is_active 2>/dev/null; then
        mkdir -p "$GENERATED_DIR" 2>/dev/null || true
    fi

    for mod in "${modules[@]}"; do
        local tmpl="$root/zsh/modules/${mod}.zsh.tmpl"
        if [[ -f "$tmpl" ]]; then
            _generate_copy_template "$tmpl" "$GENERATED_DIR/${mod}.zsh" "Generate module $mod"
        fi
    done

    # Orchestrators
    local zshrc_tmpl="$root/zsh/zshrc.tmpl"
    local zshenv_tmpl="$root/zsh/zshenv.tmpl"
    local sources
    sources="$(_generate_module_sources "${modules[@]}")"

    if [[ -f "$zshrc_tmpl" ]]; then
        local zshrc_body
        zshrc_body="$(cat "$zshrc_tmpl")"
        zshrc_body="${zshrc_body//\{\{MODULE_SOURCES\}\}/$sources}"
        _generate_write_file "$HOME/.zshrc" "$zshrc_body" "Generate ~/.zshrc"
    fi
    if [[ -f "$zshenv_tmpl" ]]; then
        _generate_copy_template "$zshenv_tmpl" "$HOME/.zshenv" "Generate ~/.zshenv"
    fi

    # Starship theme
    if [[ "$has_starship" -eq 1 ]]; then
        local theme="${THEME_STARSHIP:-stock}"
        local theme_file="$root/themes/${theme}/starship.toml"
        [[ -f "$theme_file" ]] || theme_file="$root/themes/stock/starship.toml"
        if [[ -f "$theme_file" ]]; then
            _generate_copy_template "$theme_file" "$HOME/.config/starship.toml" "Generate starship.toml ($theme)"
        fi
    fi

    # shell-features
    if declare -f write_shell_features >/dev/null 2>&1; then
        SHELL_PROFILE_MODE="starship"
        [[ "$has_starship" -eq 1 ]] || SHELL_PROFILE_MODE="plain"
        write_shell_features_generated "$has_starship" "$has_omz"
    fi

    if declare -f prompt_success >/dev/null 2>&1; then
        prompt_success "Generated shell configs → ~/.zshrc + $GENERATED_DIR"
    fi
}

# Features file for generated setup (STARSHIP_CONFIG → ~/.config/starship.toml)
write_shell_features_generated() {
    local enable_starship="${1:-0}"
    local enable_omz="${2:-0}"
    local features_file="${STATE_DIR:-$HOME/.dotfiles-setup}/shell-features.zsh"

    if dry_run_is_active 2>/dev/null; then
        dry_run_add_step "Write shell features" \
            "write $features_file (starship=$enable_starship omz=$enable_omz)" \
            "$features_file" "" "false" ""
        return 0
    fi

    state_init 2>/dev/null || mkdir -p "$(dirname "$features_file")"
    cat > "$features_file" <<EOF
# Generated by setup — do not edit by hand (re-run setup to change)
export DOTFILES_GENERATED_DIR="${HOME}/.dotfiles-setup/generated"
export STARSHIP_CONFIG="\${STARSHIP_CONFIG:-\$HOME/.config/starship.toml}"
export DOTFILES_ENABLE_STARSHIP=${enable_starship}
export DOTFILES_ENABLE_OMZ=${enable_omz}
export DOTFILES_SHELL_PROFILE="${SHELL_PROFILE_MODE:-starship}"
export DOTFILES_SETUP_SCHEMA=2
EOF

    if declare -f state_log_install >/dev/null 2>&1; then
        state_log_install "shell-features" "Shell features file" "config" \
            "write $features_file" "$features_file" "" "" "" ""
    fi
}
