#!/bin/bash
# Install log read/write under ~/.dotfiles-setup/

state_init() {
    mkdir -p "$STATE_DIR" "$BACKUP_DIR"
    touch "$INSTALL_LOG"
}

# Escape a string for JSON
_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# state_log_install id name action commands dest side_effects symlink_source symlink_target backup_path
state_log_install() {
    if dry_run_is_active 2>/dev/null; then
        return 0
    fi
    local id="$1"
    local name="$2"
    local action="$3"
    local commands="$4"
    local dest="${5:-}"
    local side_effects="${6:-}"
    local symlink_source="${7:-}"
    local symlink_target="${8:-}"
    local backup_path="${9:-}"
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"

    state_init

    local line
    line=$(printf '{"id":"%s","name":"%s","timestamp":"%s","pkgmgr":"%s","platform":"%s","action":"%s","commands":"%s","dest":"%s","side_effects":"%s","symlink_source":"%s","symlink_target":"%s","replaced_backup":"%s","owned_by_setup":true}' \
        "$(_json_escape "$id")" \
        "$(_json_escape "$name")" \
        "$ts" \
        "$(_json_escape "${PKG_MGR:-}")" \
        "$(_json_escape "${PLATFORM:-}")" \
        "$(_json_escape "$action")" \
        "$(_json_escape "$commands")" \
        "$(_json_escape "$dest")" \
        "$(_json_escape "$side_effects")" \
        "$(_json_escape "$symlink_source")" \
        "$(_json_escape "$symlink_target")" \
        "$(_json_escape "$backup_path")")

    echo "$line" >> "$INSTALL_LOG"
}

state_log_count() {
    if [[ ! -f "$INSTALL_LOG" ]] || [[ ! -s "$INSTALL_LOG" ]]; then
        echo 0
        return
    fi
    local n
    n="$(grep -c . "$INSTALL_LOG" 2>/dev/null || true)"
    echo "${n:-0}"
}

state_log_lines() {
    if [[ ! -f "$INSTALL_LOG" ]]; then
        return
    fi
    cat "$INSTALL_LOG"
}

# Extract JSON field (simple parser for our flat records)
state_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | sed -n "s/.*\"${field}\":\"\\([^\"]*\\)\".*/\\1/p" | head -1
}

# Remove log lines whose id is in the given list (space-separated)
state_remove_ids() {
    local ids_to_remove="$1"
    local tmp
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local id
        id="$(state_json_field "$line" "id")"
        if [[ " $ids_to_remove " != *" $id "* ]]; then
            echo "$line" >> "$tmp"
        fi
    done < "$INSTALL_LOG"
    mv "$tmp" "$INSTALL_LOG"
}

# Backup a path before overwrite; prints backup path or empty
state_backup_path() {
    local target="$1"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        echo ""
        return
    fi
    state_init
    local base
    base="$(basename "$target")"
    local stamp
    stamp="$(date +%Y%m%d%H%M%S)"
    local dest="$BACKUP_DIR/${base}.${stamp}"
    mv "$target" "$dest"
    echo "$dest"
}

save_setup_prefs() {
    state_init
    {
        echo "PKG_MGR=${PKG_MGR:-}"
        echo "LAST_PRESET=${PRESET_NAME:-}"
        echo "LAST_PROFILE=${PROFILE_ID:-}"
        echo "LAST_SELECTION_IDS=\"${SELECTED_IDS[*]:-}\""
        echo "LAST_SHELL_PROFILE=${SHELL_PROFILE_MODE:-}"
        echo "LAST_LINK_MODE=${LINK_MODE:-symlink}"
        echo "DOTFILES_DIR=${DOTFILES_DIR:-}"
    } > "$SETUP_CONF"
}

# Backward-compatible alias
save_pkgmgr_pref() {
    PKG_MGR="$1"
    save_setup_prefs
}

load_setup_prefs() {
    if [[ -f "$SETUP_CONF" ]]; then
        # shellcheck disable=SC1090
        . "$SETUP_CONF"
    fi
}

load_pkgmgr_pref() {
    load_setup_prefs
}
