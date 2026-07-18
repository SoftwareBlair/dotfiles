#!/bin/bash
# Reverse actions from the install log

run_undo() {
    local select_mode="${1:-false}"

    state_init
    local count
    count="$(state_log_count)"
    if [[ "$count" -eq 0 ]]; then
        prompt_warn "Nothing to undo — install log is empty ($INSTALL_LOG)."
        return 0
    fi

    prompt_welcome "Undo Setup" "$(platform_label) · $count logged action(s)"

    # Load log lines into array (newest first for reverse order)
    local lines=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] && lines+=("$line")
    done < "$INSTALL_LOG"

    local selected_lines=()
    if [[ "$select_mode" == "true" && -z "${YES_MODE:-}" ]]; then
        local labels=()
        local i
        for i in "${!lines[@]}"; do
            local id name action
            id="$(state_json_field "${lines[$i]}" id)"
            name="$(state_json_field "${lines[$i]}" name)"
            action="$(state_json_field "${lines[$i]}" action)"
            labels+=("$name [$action] ($id)")
        done
        local picked
        picked="$(prompt_choose_many "Select items to undo" "${labels[@]}")"
        while IFS= read -r label || [[ -n "$label" ]]; do
            [[ -z "$label" ]] && continue
            for i in "${!labels[@]}"; do
                if [[ "${labels[$i]}" == "$label" ]]; then
                    selected_lines+=("${lines[$i]}")
                fi
            done
        done <<< "$picked"
    else
        selected_lines=("${lines[@]}")
    fi

    if [[ ${#selected_lines[@]} -eq 0 ]]; then
        prompt_warn "No items selected."
        return 0
    fi

    # Reverse chronological (newest first) — log is append-only so reverse array
    local reverse=()
    local idx
    for ((idx=${#selected_lines[@]}-1; idx>=0; idx--)); do
        reverse+=("${selected_lines[$idx]}")
    done

    dry_run_begin_plan
    local undo_ids=""
    local entry
    for entry in "${reverse[@]}"; do
        local id name action commands dest side_effects symlink_target backup pkgmgr_saved
        id="$(state_json_field "$entry" id)"
        name="$(state_json_field "$entry" name)"
        action="$(state_json_field "$entry" action)"
        commands="$(state_json_field "$entry" commands)"
        dest="$(state_json_field "$entry" dest)"
        side_effects="$(state_json_field "$entry" side_effects)"
        symlink_target="$(state_json_field "$entry" symlink_target)"
        backup="$(state_json_field "$entry" replaced_backup)"
        pkgmgr_saved="$(state_json_field "$entry" pkgmgr)"

        undo_ids="$undo_ids $id"

        case "$action" in
            symlink)
                local undo_cmd="unlink \"$symlink_target\""
                [[ -n "$backup" ]] && undo_cmd="$undo_cmd && mv \"$backup\" \"$symlink_target\""
                dry_run_add_step "Undo: $name" "$undo_cmd" "$symlink_target" "restore backup if present" "false" ""
                ;;
            chsh)
                local prev
                prev="$(echo "$side_effects" | sed -n 's/.*previous=\([^ ]*\).*/\1/p')"
                if [[ -n "$prev" ]]; then
                    dry_run_add_step "Undo: $name" "chsh -s $prev" "$prev" "" "true" ""
                else
                    dry_run_add_step "Undo: $name" "(manual) restore previous shell" "" "" "false" "no previous shell recorded"
                fi
                ;;
            repo)
                dry_run_add_step "Undo: $name" "sudo rm -f $side_effects" "$side_effects" "remove repo file owned by setup" "true" ""
                ;;
            config)
                if [[ "$id" == "brew-shellenv" ]]; then
                    dry_run_add_step "Undo: $name" \
                        "remove # >>> dotfiles-setup >>> block from ~/.zprofile" \
                        "$HOME/.zprofile" "" "false" ""
                elif [[ "$id" == "secrets-zprofile" ]]; then
                    dry_run_add_step "Undo: $name" \
                        "remove # >>> dotfiles-secrets >>> block from ~/.zprofile" \
                        "$HOME/.zprofile" "" "false" ""
                else
                    dry_run_add_step "Undo: $name" "(review) $commands" "$dest" "" "false" ""
                fi
                ;;
            upgrade)
                dry_run_add_step "Undo: $name" "" "$dest" "" "false" \
                    "upgrade — not reversed (package stays installed)"
                ;;
            install)
                # Prefer catalog uninstall; fall back to heuristics
                local uninstall_cmd=""
                if [[ -n "$(catalog_get "$id" name 2>/dev/null)" ]]; then
                    local saved_mgr="$PKG_MGR"
                    [[ -n "$pkgmgr_saved" ]] && PKG_MGR="$pkgmgr_saved"
                    uninstall_cmd="$(catalog_resolve_uninstall_cmd "$id")"
                    PKG_MGR="$saved_mgr"
                fi
                if [[ -z "$uninstall_cmd" ]]; then
                    # Heuristic from install command
                    if [[ "$commands" == brew\ install\ --cask* ]]; then
                        uninstall_cmd="$(echo "$commands" | sed 's/brew install --cask/brew uninstall --cask/')"
                    elif [[ "$commands" == brew\ install* ]]; then
                        uninstall_cmd="$(echo "$commands" | sed 's/brew install/brew uninstall/')"
                    elif [[ "$commands" == *apt-get\ install* ]]; then
                        uninstall_cmd="$(echo "$commands" | sed 's/apt-get install -y/apt-get remove -y/' | sed 's/apt-get install/apt-get remove -y/')"
                    elif [[ "$id" == "nvm" || "$name" == *"NVM"* ]]; then
                        uninstall_cmd="rm -rf \$HOME/.nvm \$HOME/.npm"
                    elif [[ "$id" == "oh_my_zsh" ]]; then
                        uninstall_cmd="rm -rf \$HOME/.oh-my-zsh"
                    else
                        uninstall_cmd="(manual) reverse: $commands"
                    fi
                fi
                dry_run_add_step "Undo: $name" "$uninstall_cmd" "$dest" "$side_effects" "true" ""
                ;;
            *)
                dry_run_add_step "Undo: $name" "(manual) $commands" "$dest" "" "false" ""
                ;;
        esac
    done

    dry_run_print_plan "Undo Plan"

    if dry_run_is_active; then
        return 0
    fi

    echo ""
    prompt_error "This will reverse ${#reverse[@]} action(s) recorded by setup."
    prompt_warn "Only setup-owned installs/symlinks/repos are removed. ~/.gitconfig is never deleted."
    if ! prompt_confirm "Proceed with undo?" "false"; then
        prompt_warn "Undo cancelled."
        return 0
    fi
    if ! prompt_confirm "Are you sure? This cannot be easily re-done without reinstalling." "false"; then
        prompt_warn "Undo cancelled."
        return 0
    fi

    # Optionally uninstall Homebrew
    local remove_brew=false
    if grep -q '"id":"homebrew"' "$INSTALL_LOG" 2>/dev/null; then
        if prompt_confirm "Also uninstall Homebrew?" "false"; then
            remove_brew=true
        fi
    fi

    local entry
    for entry in "${reverse[@]}"; do
        local id name action commands dest side_effects symlink_target backup pkgmgr_saved
        id="$(state_json_field "$entry" id)"
        name="$(state_json_field "$entry" name)"
        action="$(state_json_field "$entry" action)"
        commands="$(state_json_field "$entry" commands)"
        dest="$(state_json_field "$entry" dest)"
        side_effects="$(state_json_field "$entry" side_effects)"
        symlink_target="$(state_json_field "$entry" symlink_target)"
        backup="$(state_json_field "$entry" replaced_backup)"
        pkgmgr_saved="$(state_json_field "$entry" pkgmgr)"

        prompt_style "Undoing: $name"
        case "$action" in
            symlink)
                if [[ -L "$symlink_target" ]]; then
                    unlink "$symlink_target" 2>/dev/null || true
                fi
                if [[ -n "$backup" && -e "$backup" ]]; then
                    mv "$backup" "$symlink_target"
                    prompt_info "Restored backup to $symlink_target"
                fi
                ;;
            chsh)
                local prev
                prev="$(echo "$side_effects" | sed -n 's/.*previous=\([^ ]*\).*/\1/p')"
                if [[ -n "$prev" ]]; then
                    chsh -s "$prev" || prompt_warn "Run manually: chsh -s $prev"
                fi
                ;;
            repo)
                if [[ -n "$side_effects" ]]; then
                    sudo rm -f $side_effects 2>/dev/null || true
                fi
                ;;
            config)
                if [[ "$id" == "brew-shellenv" && -f "$HOME/.zprofile" ]]; then
                    # Remove marked block
                    sed -i.bak '/# >>> dotfiles-setup >>>/,/# <<< dotfiles-setup <<</d' "$HOME/.zprofile" 2>/dev/null || \
                        sed -i '' '/# >>> dotfiles-setup >>>/,/# <<< dotfiles-setup <<</d' "$HOME/.zprofile" 2>/dev/null || true
                elif [[ "$id" == "secrets-zprofile" && -f "$HOME/.zprofile" ]]; then
                    sed -i.bak '/# >>> dotfiles-secrets >>>/,/# <<< dotfiles-secrets <<</d' "$HOME/.zprofile" 2>/dev/null || \
                        sed -i '' '/# >>> dotfiles-secrets >>>/,/# <<< dotfiles-secrets <<</d' "$HOME/.zprofile" 2>/dev/null || true
                fi
                ;;
            upgrade)
                prompt_info "Skipping undo for upgrade of $name (package stays installed)."
                continue
                ;;
            install)
                if [[ "$id" == "homebrew" && "$remove_brew" != "true" ]]; then
                    prompt_info "Keeping Homebrew (not removing)."
                    continue
                fi
                local uninstall_cmd=""
                local saved_mgr="$PKG_MGR"
                [[ -n "$pkgmgr_saved" ]] && PKG_MGR="$pkgmgr_saved"
                uninstall_cmd="$(catalog_resolve_uninstall_cmd "$id")"
                PKG_MGR="$saved_mgr"
                if [[ -n "$uninstall_cmd" && "$uninstall_cmd" != "(manual)"* ]]; then
                    bash -c "$uninstall_cmd" || true
                elif [[ "$id" == "nvm" ]]; then
                    rm -rf "$HOME/.nvm" "$HOME/.npm"
                elif [[ "$id" == "oh_my_zsh" ]]; then
                    rm -rf "$HOME/.oh-my-zsh"
                elif [[ "$id" == "homebrew" ]]; then
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true
                else
                    prompt_warn "No automatic uninstall for $name — skipped."
                fi
                ;;
        esac
        prompt_success "✓ Undid $name"
    done

    state_remove_ids "$undo_ids"
    prompt_success "Undo complete."
    prompt_info "Optional manual cleanup: ~/.gitconfig, Xcode CLT (macOS)."
}

# Backward-compatible wrapper
revert_setup() {
    run_undo "false"
}
