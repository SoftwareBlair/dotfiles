#!/bin/bash
# Catalog-driven install executor

SELECTED_IDS=()

installer_add_selection() {
    local id="$1"
    SELECTED_IDS+=("$id")
}

installer_clear_selections() {
    SELECTED_IDS=()
}

installer_is_installed() {
    local id="$1"
    local check
    check="$(catalog_get "$id" check)"
    [[ -z "$check" ]] && return 1
    eval "$check" &>/dev/null
}

# Build dry-run plan steps for selected IDs (caller should dry_run_begin_plan first)
installer_plan_selections() {
    local id
    for id in "${SELECTED_IDS[@]}"; do
        local name cmd dest side_effects requires_sudo
        name="$(catalog_get "$id" name)"
        if installer_is_installed "$id"; then
            dry_run_add_step "$name" "" "$(catalog_install_dest "$id")" "" "false" \
                "already present — would skip"
            continue
        fi
        cmd="$(catalog_resolve_install_cmd "$id")"
        dest="$(catalog_install_dest "$id")"
        side_effects="$(catalog_get "$id" install_side_effects)"
        requires_sudo="$(catalog_get "$id" install_requires_sudo)"
        [[ -z "$requires_sudo" ]] && requires_sudo="false"
        if [[ -z "$cmd" ]]; then
            dry_run_add_step "$name" "(no recipe for $PKG_MGR on $PLATFORM)" "" "" "false" \
                "unsupported combination — would skip"
            continue
        fi
        dry_run_add_step "$name" "$cmd" "$dest" "$side_effects" "$requires_sudo" ""
    done
}

installer_run_selections() {
    local id
    local failed=0
    for id in "${SELECTED_IDS[@]}"; do
        local name cmd
        name="$(catalog_get "$id" name)"

        if installer_is_installed "$id"; then
            prompt_info "$name is already installed — skipping."
            report_skip "$name (already installed)" 2>/dev/null || true
            continue
        fi

        cmd="$(catalog_resolve_install_cmd "$id")"
        if [[ -z "$cmd" ]]; then
            prompt_warn "No install recipe for $name with $PKG_MGR on $PLATFORM — skipping."
            report_skip "$name (no recipe)" 2>/dev/null || true
            continue
        fi

        prompt_style "Installing $name..."
        if dry_run_is_active; then
            dry_run_exec "$name" "$cmd" "$(catalog_install_dest "$id")" \
                "$(catalog_get "$id" install_side_effects)" \
                "$(catalog_get "$id" install_requires_sudo)"
            continue
        fi

        if prompt_spin "Installing $name..." bash -c "$cmd"; then
            # Log if custom script didn't already
            if ! grep -q "\"id\":\"$id\"" "$INSTALL_LOG" 2>/dev/null; then
                state_log_install "$id" "$name" "install" "$cmd" \
                    "$(catalog_install_dest "$id")" \
                    "$(catalog_get "$id" install_side_effects)" "" "" ""
            fi
            prompt_success "✓ $name installed"
            report_ok "$name" 2>/dev/null || true

            # Optional post symlink
            local post_symlink
            post_symlink="$(catalog_get "$id" post_symlink)"
            if [[ -n "$post_symlink" && -e "$DOTFILES_DIR/$post_symlink" ]]; then
                if declare -f install_dotfile_path >/dev/null 2>&1; then
                    install_dotfile_path "$post_symlink"
                else
                    symlink_dotfile_safe "$post_symlink"
                fi
            fi
        else
            prompt_error "✗ Failed to install $name"
            report_fail "$name" 2>/dev/null || true
            failed=$((failed + 1))
            if [[ -z "${YES_MODE:-}" ]]; then
                if ! prompt_confirm "Continue with remaining items?"; then
                    return 1
                fi
            fi
        fi
    done
    return $failed
}

# Safe symlink with backup + state log
symlink_dotfile_safe() {
    local rel="$1"
    local source="$DOTFILES_DIR/$rel"
    local target="$HOME/$rel"
    local name="Symlink $rel"

    # For nested paths like .config/zed, ensure parent exists
    mkdir -p "$(dirname "$target")"

    local cmd="ln -sfn \"$source\" \"$target\""

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$target" "backup existing if present" "false" ""
        return 0
    fi

    local backup=""
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            local current
            current="$(readlink "$target")"
            if [[ "$current" == "$source" ]]; then
                prompt_info "$rel already symlinked."
                return 0
            fi
        fi
        backup="$(state_backup_path "$target")"
    fi

    ln -sfn "$source" "$target"
    state_log_install "symlink-${rel//\//-}" "$name" "symlink" "$cmd" \
        "$target" "" "$source" "$target" "$backup"
    prompt_success "Linked $rel"
}

configure_git_interactive() {
    # Skip git identity prompts in non-interactive mode
    if [[ -n "${YES_MODE:-}" ]]; then
        prompt_info "Skipping interactive git config (-y mode)."
        return 0
    fi

    if ! prompt_confirm "Configure common Git settings?"; then
        prompt_warn "Skipping git config."
        return 0
    fi

    if [[ -f "$HOME/.gitconfig" ]]; then
        if prompt_confirm "Git config already exists. Overwrite identity settings?"; then
            prompt_info "Updating git config..."
        else
            prompt_warn "Skipping git config overwrite."
            return 0
        fi
    fi

    local git_name git_email
    git_name="$(prompt_input "Your name" "")"
    git_email="$(prompt_input "Your email" "")"

    if dry_run_is_active; then
        dry_run_add_step "Git config" \
            "git config --global user.name/email + defaults" \
            "$HOME/.gitconfig" "does not delete existing .gitconfig on undo" "false" ""
        return 0
    fi

    [[ -n "$git_name" ]] && git config --global user.name "$git_name"
    [[ -n "$git_email" ]] && git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global alias.hist 'log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'

    if prompt_confirm "Set Cursor as preferred Git editor?" "true"; then
        if command -v cursor &>/dev/null; then
            git config --global core.editor "cursor --wait"
        elif command -v code &>/dev/null; then
            git config --global core.editor "code --wait"
            prompt_info "Cursor not found; using VS Code for core.editor."
        else
            prompt_warn "Cursor/VS Code not found; skipping editor setting."
        fi
    fi

    if prompt_confirm "Set rebasing as default pull strategy?" "false"; then
        git config --global pull.rebase true
    fi

    prompt_success "Git configured (identity is not auto-removed by --undo)."
}

maybe_chsh() {
    local shell_id="$1"
    local shell_path
    shell_path="$(command -v "$shell_id" 2>/dev/null || true)"
    [[ -z "$shell_path" ]] && return 0

    if [[ "$SHELL" == "$shell_path" ]]; then
        return 0
    fi

    if dry_run_is_active; then
        dry_run_add_step "Set default shell to $shell_id" \
            "chsh -s $shell_path" "$shell_path" "previous shell: $SHELL" "true" ""
        return 0
    fi

    if prompt_confirm "Set $shell_id as your default shell?"; then
        local prev="$SHELL"
        if chsh -s "$shell_path"; then
            state_log_install "chsh-$shell_id" "Default shell → $shell_id" "chsh" \
                "chsh -s $shell_path" "$shell_path" "previous=$prev" "" "" ""
            prompt_success "Default shell set to $shell_id (restart terminal)."
        else
            prompt_warn "Could not change shell automatically. Run: chsh -s $shell_path"
        fi
    fi
}

install_prerequisites() {
    if [[ "$PLATFORM" == "macos" ]]; then
        prompt_style "Prerequisites: Xcode Command Line Tools"
        if xcode-select -p &>/dev/null; then
            prompt_info "Xcode Command Line Tools already installed."
            if [[ -z "${YES_MODE:-}" ]] && prompt_confirm "Check for software updates?" "false"; then
                if dry_run_is_active; then
                    dry_run_add_step "macOS softwareupdate" "softwareupdate -ia --verbose" "" "" "true" ""
                else
                    softwareupdate -ia --verbose || true
                fi
            fi
        else
            local cmd="xcode-select --install"
            if dry_run_is_active; then
                dry_run_add_step "Xcode Command Line Tools" "$cmd" "" "GUI installer may open" "true" ""
            else
                prompt_info "Installing Xcode Command Line Tools..."
                xcode-select --install || true
                state_log_install "xcode-clt" "Xcode Command Line Tools" "install" \
                    "$cmd" "" "manual GUI install" "" "" ""
            fi
        fi
    else
        prompt_style "Prerequisites: build tools"
        local cmd=""
        case "$PKG_MGR" in
            brew) cmd="brew install gcc make" ;;
            apt) cmd="sudo apt-get update && sudo apt-get install -y build-essential curl git unzip" ;;
            dnf) cmd="sudo dnf groupinstall -y \"Development Tools\" && sudo dnf install -y curl git unzip" ;;
            pacman) cmd="sudo pacman -S --noconfirm base-devel curl git unzip" ;;
        esac
        if [[ -n "$cmd" ]]; then
            if dry_run_is_active; then
                dry_run_add_step "Build tools" "$cmd" "" "" "true" ""
            else
                if prompt_confirm "Install build essentials / curl / git?" "true"; then
                    prompt_spin "Installing build tools..." bash -c "$cmd"
                    state_log_install "build-tools" "Build tools" "install" "$cmd" "" "" "" "" ""
                fi
            fi
        fi
    fi
}
