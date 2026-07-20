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

# Upgrade already-installed items that have updates available
installer_offer_updates() {
    local outdated_ids=()
    local id name upgrade_cmd
    local any_installed=false

    for id in "${SELECTED_IDS[@]}"; do
        [[ "$(catalog_get "$id" generate_only)" == "true" ]] && continue
        if installer_is_installed "$id"; then
            any_installed=true
            break
        fi
    done
    [[ "$any_installed" == "true" ]] || return 0

    pkgmgr_refresh_metadata

    for id in "${SELECTED_IDS[@]}"; do
        [[ "$(catalog_get "$id" generate_only)" == "true" ]] && continue
        installer_is_installed "$id" || continue
        if catalog_has_update "$id"; then
            outdated_ids+=("$id")
        elif catalog_pkg_spec "$id" &>/dev/null; then
            name="$(catalog_get "$id" name)"
            prompt_info "$name is already installed — up to date."
            report_skip "$name (up to date)" 2>/dev/null || true
        else
            name="$(catalog_get "$id" name)"
            prompt_info "$name is already installed — skipping."
            report_skip "$name (already installed)" 2>/dev/null || true
        fi
    done

    [[ ${#outdated_ids[@]} -gt 0 ]] || return 0

    echo ""
    prompt_style "Updates available (${#outdated_ids[@]}):"
    for id in "${outdated_ids[@]}"; do
        echo "  • $(catalog_get "$id" name)"
    done

    if ! prompt_confirm "Update these packages now?" "true"; then
        for id in "${outdated_ids[@]}"; do
            name="$(catalog_get "$id" name)"
            prompt_warn "Keeping current $name."
            report_skip "$name (update declined)" 2>/dev/null || true
        done
        return 0
    fi

    local failed=0
    for id in "${outdated_ids[@]}"; do
        name="$(catalog_get "$id" name)"
        upgrade_cmd="$(catalog_resolve_upgrade_cmd "$id")"
        if [[ -z "$upgrade_cmd" ]]; then
            prompt_warn "No upgrade recipe for $name — skipping."
            report_skip "$name (no upgrade recipe)" 2>/dev/null || true
            continue
        fi

        prompt_style "Updating $name..."
        if dry_run_is_active; then
            dry_run_exec "Update $name" "$upgrade_cmd" "$(catalog_install_dest "$id")" \
                "$(catalog_get "$id" install_side_effects)" \
                "$(catalog_get "$id" install_requires_sudo)"
            report_ok "$name (would update)" 2>/dev/null || true
            continue
        fi

        if prompt_spin "Updating $name..." bash -c "$upgrade_cmd"; then
            state_log_install "$id" "$name" "upgrade" "$upgrade_cmd" \
                "$(catalog_install_dest "$id")" \
                "$(catalog_get "$id" install_side_effects)" "" "" ""
            prompt_success "✓ $name updated"
            report_ok "$name (updated)" 2>/dev/null || true
        else
            prompt_error "✗ Failed to update $name"
            report_fail "$name (update)" 2>/dev/null || true
            failed=$((failed + 1))
            if [[ -z "${YES_MODE:-}" ]]; then
                if ! prompt_confirm "Continue with remaining items?"; then
                    return 1
                fi
            fi
        fi
    done
    return "$failed"
}

installer_run_selections() {
    local id
    local failed=0

    # Offer upgrades for anything already present before installing the rest
    installer_offer_updates || failed=$?

    for id in "${SELECTED_IDS[@]}"; do
        # Generate-only modules (e.g. zsh_aliases) — no package install
        if [[ "$(catalog_get "$id" generate_only)" == "true" ]]; then
            report_skip "$(catalog_get "$id" name) (generate-only)" 2>/dev/null || true
            continue
        fi

        local name cmd
        name="$(catalog_get "$id" name)"

        if installer_is_installed "$id"; then
            # Already handled by installer_offer_updates (updated, declined, or up to date)
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
            local post_symlink post_src
            post_symlink="$(catalog_get "$id" post_symlink)"
            post_src="$DOTFILES_DIR/$post_symlink"
            if declare -f profile_config_source >/dev/null 2>&1; then
                post_src="$(profile_config_source "$post_symlink")"
            fi
            if [[ -n "$post_symlink" && -e "$post_src" ]]; then
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
    if declare -f profile_config_source >/dev/null 2>&1; then
        source="$(profile_config_source "$rel")"
    fi
    local target="$HOME/$rel"
    local name="Symlink $rel"

    local cmd="ln -sfn \"$source\" \"$target\""

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$target" "backup existing if present" "false" ""
        return 0
    fi

    # For nested paths like .config/zed, ensure parent exists
    mkdir -p "$(dirname "$target")"

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

maybe_chsh() {
    local shell_id="$1"
    local shell_path
    shell_path="$(command -v "$shell_id" 2>/dev/null || true)"
    [[ -z "$shell_path" ]] && return 0

    if [[ "$SHELL" == "$shell_path" ]]; then
        return 0
    fi

    if ! prompt_confirm "Set $shell_id as your default shell?"; then
        return 0
    fi

    if dry_run_is_active; then
        dry_run_add_step "Set default shell to $shell_id" \
            "chsh -s $shell_path" "$shell_path" "previous shell: $SHELL" "true" ""
        return 0
    fi

    local prev="$SHELL"
    if chsh -s "$shell_path"; then
        state_log_install "chsh-$shell_id" "Default shell → $shell_id" "chsh" \
            "chsh -s $shell_path" "$shell_path" "previous=$prev" "" "" ""
        prompt_success "Default shell set to $shell_id (restart terminal)."
    else
        prompt_warn "Could not change shell automatically. Run: chsh -s $shell_path"
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
            if prompt_confirm "Install build essentials / curl / git?" "true"; then
                if dry_run_is_active; then
                    dry_run_add_step "Build tools" "$cmd" "" "" "true" ""
                else
                    prompt_spin "Installing build tools..." bash -c "$cmd"
                    state_log_install "build-tools" "Build tools" "install" "$cmd" "" "" "" "" ""
                fi
            fi
        fi
    fi
}
