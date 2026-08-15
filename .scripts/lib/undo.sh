#!/bin/bash
# Reverse actions from the install log (packages + generated configs)

# Restore a backup path over dest, or remove dest if no backup.
_undo_restore_or_remove() {
    local dest="$1"
    local backup="$2"
    [[ -z "$dest" ]] && return 0
    if [[ -n "$backup" && -e "$backup" ]]; then
        mkdir -p "$(dirname "$dest")" 2>/dev/null || true
        rm -rf "$dest" 2>/dev/null || true
        mv "$backup" "$dest"
        prompt_info "Restored backup → $dest"
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest" 2>/dev/null || true
        prompt_info "Removed $dest"
    fi
}

# Resolve backup path from log fields (new: replaced_backup; legacy: side_effects under backups/)
_undo_backup_path() {
    local backup="$1"
    local side_effects="$2"
    if [[ -n "$backup" ]]; then
        echo "$backup"
        return 0
    fi
    if [[ -n "$side_effects" && -e "$side_effects" ]]; then
        case "$side_effects" in
            */.dotfiles-setup/backups/*|*/backups/*)
                echo "$side_effects"
                return 0
                ;;
        esac
    fi
    echo ""
}

run_undo() {
    local select_mode="${1:-false}"
    local purge_state="${2:-false}"  # true = also remove ~/.dotfiles-setup after undo

    # Do not create state dir if missing — nothing to undo
    if [[ ! -f "$INSTALL_LOG" ]] || [[ ! -s "$INSTALL_LOG" ]]; then
        prompt_warn "Nothing to undo — install log is empty (${INSTALL_LOG:-~/.dotfiles-setup/install-log.jsonl})."
        return 0
    fi

    local count
    count="$(state_log_count)"
    prompt_welcome "Undo Setup" "$(platform_label) · $count logged action(s)"

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

    local reverse=()
    local idx
    for ((idx=${#selected_lines[@]}-1; idx>=0; idx--)); do
        reverse+=("${selected_lines[$idx]}")
    done

    dry_run_begin_plan
    local undo_ids=""
    local entry
    for entry in "${reverse[@]}"; do
        local id name action commands dest side_effects symlink_target backup pkgmgr_saved backup_path
        id="$(state_json_field "$entry" id)"
        name="$(state_json_field "$entry" name)"
        action="$(state_json_field "$entry" action)"
        commands="$(state_json_field "$entry" commands)"
        dest="$(state_json_field "$entry" dest)"
        side_effects="$(state_json_field "$entry" side_effects)"
        symlink_target="$(state_json_field "$entry" symlink_target)"
        backup="$(state_json_field "$entry" replaced_backup)"
        pkgmgr_saved="$(state_json_field "$entry" pkgmgr)"
        backup_path="$(_undo_backup_path "$backup" "$side_effects")"

        undo_ids="$undo_ids $id"

        case "$action" in
            symlink)
                local undo_cmd="unlink \"$symlink_target\""
                [[ -n "$backup_path" ]] && undo_cmd="$undo_cmd && mv \"$backup_path\" \"$symlink_target\""
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
                elif [[ -n "$backup_path" ]]; then
                    dry_run_add_step "Undo: $name" \
                        "restore $backup_path → $dest" "$dest" "restore pre-setup backup" "false" ""
                elif [[ -n "$dest" ]]; then
                    dry_run_add_step "Undo: $name" "rm -rf $dest" "$dest" "remove generated config" "false" ""
                else
                    dry_run_add_step "Undo: $name" "(review) $commands" "" "" "false" ""
                fi
                ;;
            upgrade)
                dry_run_add_step "Undo: $name" "" "$dest" "" "false" \
                    "upgrade - not reversed (package stays installed; use uninstall if needed)"
                ;;
            install)
                local uninstall_cmd=""
                if [[ -n "$(catalog_get "$id" name 2>/dev/null)" ]]; then
                    local saved_mgr="$PKG_MGR"
                    [[ -n "$pkgmgr_saved" ]] && PKG_MGR="$pkgmgr_saved"
                    uninstall_cmd="$(catalog_resolve_uninstall_cmd "$id")"
                    PKG_MGR="$saved_mgr"
                fi
                if [[ -z "$uninstall_cmd" ]]; then
                    if [[ "$commands" == brew\ install\ --cask* ]]; then
                        uninstall_cmd="$(echo "$commands" | sed 's/brew install --cask/brew uninstall --cask/')"
                    elif [[ "$commands" == brew\ install* ]]; then
                        uninstall_cmd="$(echo "$commands" | sed 's/brew install/brew uninstall/')"
                    elif [[ "$id" == "nvm" || "$name" == *"NVM"* ]]; then
                        uninstall_cmd="rm -rf \$HOME/.nvm \$HOME/.npm"
                    elif [[ "$id" == "oh_my_zsh" ]]; then
                        uninstall_cmd="rm -rf \$HOME/.oh-my-zsh"
                    else
                        uninstall_cmd="(manual) reverse: $commands"
                    fi
                fi
                dry_run_add_step "Undo: $name" "$uninstall_cmd" "$dest" "$side_effects" "false" ""
                ;;
            *)
                dry_run_add_step "Undo: $name" "(manual) $commands" "$dest" "" "false" ""
                ;;
        esac
    done

    if [[ "$purge_state" == "true" ]]; then
        dry_run_add_step "Remove setup state dir" "rm -rf $STATE_DIR" "$STATE_DIR" "" "false" ""
    fi

    dry_run_print_plan "Undo Plan"

    if dry_run_is_active; then
        return 0
    fi

    echo ""
    prompt_error "This will reverse ${#reverse[@]} action(s) recorded by setup."
    prompt_warn "Brew packages will be uninstalled. Generated configs removed or restored from backup."
    if ! prompt_confirm "Proceed with undo?" "false"; then
        prompt_warn "Undo cancelled."
        return 0
    fi
    if ! prompt_confirm "Are you sure? Re-run setup to install again." "false"; then
        prompt_warn "Undo cancelled."
        return 0
    fi

    local remove_brew=false
    if grep -q '"id":"homebrew"' "$INSTALL_LOG" 2>/dev/null; then
        if prompt_confirm "Also uninstall Homebrew?" "false"; then
            remove_brew=true
        fi
    fi

    for entry in "${reverse[@]}"; do
        local id name action commands dest side_effects symlink_target backup pkgmgr_saved backup_path
        id="$(state_json_field "$entry" id)"
        name="$(state_json_field "$entry" name)"
        action="$(state_json_field "$entry" action)"
        commands="$(state_json_field "$entry" commands)"
        dest="$(state_json_field "$entry" dest)"
        side_effects="$(state_json_field "$entry" side_effects)"
        symlink_target="$(state_json_field "$entry" symlink_target)"
        backup="$(state_json_field "$entry" replaced_backup)"
        pkgmgr_saved="$(state_json_field "$entry" pkgmgr)"
        backup_path="$(_undo_backup_path "$backup" "$side_effects")"

        prompt_style "Undoing: $name"
        case "$action" in
            symlink)
                if [[ -L "$symlink_target" ]]; then
                    unlink "$symlink_target" 2>/dev/null || true
                fi
                if [[ -n "$backup_path" && -e "$backup_path" ]]; then
                    mv "$backup_path" "$symlink_target"
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
                    sed -i.bak '/# >>> dotfiles-setup >>>/,/# <<< dotfiles-setup <<</d' "$HOME/.zprofile" 2>/dev/null || \
                        sed -i '' '/# >>> dotfiles-setup >>>/,/# <<< dotfiles-setup <<</d' "$HOME/.zprofile" 2>/dev/null || true
                elif [[ "$id" == "secrets-zprofile" && -f "$HOME/.zprofile" ]]; then
                    sed -i.bak '/# >>> dotfiles-secrets >>>/,/# <<< dotfiles-secrets <<</d' "$HOME/.zprofile" 2>/dev/null || \
                        sed -i '' '/# >>> dotfiles-secrets >>>/,/# <<< dotfiles-secrets <<</d' "$HOME/.zprofile" 2>/dev/null || true
                else
                    _undo_restore_or_remove "$dest" "$backup_path"
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
                    # Heuristic from recorded install command
                    if [[ "$commands" == brew\ install\ --cask* ]]; then
                        bash -c "$(echo "$commands" | sed 's/brew install --cask/brew uninstall --cask/')" || true
                    elif [[ "$commands" == brew\ install* ]]; then
                        bash -c "$(echo "$commands" | sed 's/brew install/brew uninstall/')" || true
                    else
                        prompt_warn "No automatic uninstall for $name — skipped."
                    fi
                fi
                ;;
        esac
        prompt_success "Undid $name"
    done

    state_remove_ids "$undo_ids"

    if [[ "$purge_state" == "true" ]]; then
        prompt_style "Removing setup state: $STATE_DIR"
        # Keep backups if any remain outside empty dir — wipe the whole state tree
        rm -rf "$STATE_DIR"
        prompt_success "Removed $STATE_DIR"
    fi

    prompt_success "Undo complete."
    prompt_info "Optional manual cleanup: ~/.gitconfig, Xcode CLT (macOS), brew leftover casks."
}

# Full reverse: all logged actions + purge ~/.dotfiles-setup
run_reset() {
    run_undo "false" "true"
}

# Backward-compatible wrapper
revert_setup() {
    run_undo "false" "false"
}
