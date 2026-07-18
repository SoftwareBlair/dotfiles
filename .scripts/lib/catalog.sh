#!/bin/bash
# Catalog registry helpers (bash 3.2 compatible)

CATALOG_IDS=""

# catalog_register id key=value key=value ...
catalog_register() {
    local id="$1"
    shift
    if [[ " $CATALOG_IDS " != *" $id "* ]]; then
        CATALOG_IDS="${CATALOG_IDS:+$CATALOG_IDS }$id"
    fi
    while [[ $# -gt 0 ]]; do
        local pair="$1"
        local key="${pair%%=*}"
        local val="${pair#*=}"
        eval "CATALOG__${id}__${key}=\"\$val\""
        shift
    done
}

catalog_get() {
    local id="$1"
    local key="$2"
    eval "printf '%s' \"\${CATALOG__${id}__${key}:-}\""
}

catalog_all_ids() {
    echo "$CATALOG_IDS"
}

catalog_ids_by_category() {
    local category="$1"
    local id
    for id in $CATALOG_IDS; do
        if [[ "$(catalog_get "$id" category)" == "$category" ]]; then
            echo "$id"
        fi
    done
}

# Returns true if item is available for current PLATFORM + PKG_MGR
catalog_available() {
    local id="$1"
    local platforms
    platforms="$(catalog_get "$id" platforms)"
    platform_supports "$platforms" || return 1

    # Must have an install recipe for current pkgmgr (or install_script)
    local script
    script="$(catalog_get "$id" install_script)"
    [[ -n "$script" ]] && return 0

    local key="install_${PKG_MGR}"
    if [[ "$PKG_MGR" == "brew" ]]; then
        local os_key="install_brew_${PLATFORM}"
        local os_val
        os_val="$(catalog_get "$id" "$os_key")"
        [[ -n "$os_val" ]] && return 0
    fi
    local val
    val="$(catalog_get "$id" "$key")"
    [[ -n "$val" ]] && return 0
    return 1
}

# Items in MY_SETUP are treated as "defaults" in pickers
catalog_is_default() {
    local id="$1"
    local defaults="${DEFAULT_CATALOG_IDS:-}"
    if [[ -z "$defaults" && -n "${MY_SETUP:-}" ]]; then
        defaults="$MY_SETUP ${MY_SETUP_MACOS:-} ${MY_SETUP_OPTIONAL:-}"
    fi
    [[ " $defaults " == *" $id "* ]]
}

# Label for pickers:
#   defaults → "Name  [default]"
#   others   → "Name — short description"
catalog_label() {
    local id="$1"
    local name desc
    name="$(catalog_get "$id" name)"
    desc="$(catalog_get "$id" description)"
    if catalog_is_default "$id"; then
        echo "${name}  [default]"
    elif [[ -n "$desc" ]]; then
        echo "${name} — ${desc}"
    else
        echo "$name"
    fi
}

# Strip picker decorations to get the bare catalog name
catalog_label_name() {
    local label="$1"
    # Remove "  [default]" suffix
    label="${label%  \[default\]}"
    # Remove " — description" suffix
    label="${label%% — *}"
    # Trim trailing spaces
    label="${label%"${label##*[![:space:]]}"}"
    printf '%s' "$label"
}

# Resolve label back to id
catalog_id_from_label() {
    local label="$1"
    local id
    for id in $CATALOG_IDS; do
        if [[ "$(catalog_label "$id")" == "$label" ]]; then
            echo "$id"
            return 0
        fi
    done
    # Fallback: match by bare name
    local name
    name="$(catalog_label_name "$label")"
    for id in $CATALOG_IDS; do
        if [[ "$(catalog_get "$id" name)" == "$name" ]]; then
            echo "$id"
            return 0
        fi
    done
    return 1
}

catalog_resolve_install_cmd() {
    local id="$1"
    if [[ "$PKG_MGR" == "brew" ]]; then
        local os_cmd
        os_cmd="$(catalog_get "$id" "install_brew_${PLATFORM}")"
        if [[ -n "$os_cmd" ]]; then
            echo "$os_cmd"
            return 0
        fi
        os_cmd="$(catalog_get "$id" install_brew)"
        if [[ -n "$os_cmd" ]]; then
            echo "$os_cmd"
            return 0
        fi
    else
        local mgr_cmd
        mgr_cmd="$(catalog_get "$id" "install_${PKG_MGR}")"
        if [[ -n "$mgr_cmd" ]]; then
            echo "$mgr_cmd"
            return 0
        fi
    fi
    # Fallback: custom install script (e.g. Nerd Font download, NVM curl)
    catalog_get "$id" install_script
}

catalog_resolve_uninstall_cmd() {
    local id="$1"
    local script
    script="$(catalog_get "$id" uninstall_script)"
    if [[ -n "$script" ]]; then
        echo "$script"
        return 0
    fi
    if [[ "$PKG_MGR" == "brew" ]]; then
        local os_cmd
        os_cmd="$(catalog_get "$id" "uninstall_brew_${PLATFORM}")"
        if [[ -n "$os_cmd" ]]; then
            echo "$os_cmd"
            return 0
        fi
        os_cmd="$(catalog_get "$id" uninstall_brew)"
        if [[ -n "$os_cmd" ]]; then
            echo "$os_cmd"
            return 0
        fi
    fi
    catalog_get "$id" "uninstall_${PKG_MGR}"
}

catalog_install_dest() {
    local id="$1"
    local dest
    dest="$(catalog_get "$id" "install_dest_${PLATFORM}")"
    if [[ -z "$dest" ]]; then
        dest="$(catalog_get "$id" install_dest)"
    fi
    echo "$dest"
}

load_catalogs() {
    local catalog_dir
    catalog_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../catalog" && pwd)"
    # shellcheck disable=SC1091
    source "$catalog_dir/fonts.sh"
    # shellcheck disable=SC1091
    source "$catalog_dir/dev-tools.sh"
    # shellcheck disable=SC1091
    source "$catalog_dir/shells.sh"
    # shellcheck disable=SC1091
    source "$catalog_dir/shell-configs.sh"
}
