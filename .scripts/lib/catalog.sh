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

# Items from the loaded profile (MY_SETUP*) are treated as "defaults" in pickers
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

# Resolve package manager package for update checks.
# Prints: kind|package  where kind is cask|formula|native
# Returns 1 when this item can't be checked for updates under PKG_MGR.
catalog_pkg_spec() {
    local id="$1"
    local explicit pkg cmd

    explicit="$(catalog_get "$id" "pkg_${PKG_MGR}")"
    if [[ -n "$explicit" ]]; then
        echo "native|$explicit"
        return 0
    fi

    if [[ "${PKG_MGR:-}" == "brew" ]]; then
        explicit="$(catalog_get "$id" pkg_brew_cask)"
        if [[ -n "$explicit" ]]; then
            echo "cask|$explicit"
            return 0
        fi
        explicit="$(catalog_get "$id" pkg_brew)"
        if [[ -n "$explicit" ]]; then
            echo "formula|$explicit"
            return 0
        fi
    fi

    cmd="$(catalog_resolve_install_cmd "$id")"
    [[ -z "$cmd" ]] && return 1

    if echo "$cmd" | grep -q 'brew install --cask '; then
        pkg="$(echo "$cmd" | sed -n 's/.*brew install --cask \([^ |;&]*\).*/\1/p' | head -1)"
        if [[ -n "$pkg" ]]; then
            echo "cask|$pkg"
            return 0
        fi
    fi

    if echo "$cmd" | grep -q 'brew install '; then
        pkg="$(echo "$cmd" | sed -n 's/.*brew install \([^ |;&]*\).*/\1/p' | head -1)"
        if [[ -n "$pkg" && "$pkg" != "--cask" ]]; then
            echo "formula|$pkg"
            return 0
        fi
    fi

    if echo "$cmd" | grep -q 'apt-get install'; then
        pkg="$(echo "$cmd" | sed -n 's/.*apt-get install -y \([^ |;&]*\).*/\1/p' | head -1)"
        if [[ -z "$pkg" ]]; then
            pkg="$(echo "$cmd" | sed -n 's/.*apt-get install \([^ |;&]*\).*/\1/p' | head -1)"
        fi
        if [[ -n "$pkg" && "$pkg" != "-y" ]]; then
            echo "native|$pkg"
            return 0
        fi
    fi

    if echo "$cmd" | grep -q 'dnf install'; then
        pkg="$(echo "$cmd" | sed -n 's/.*dnf install -y \([^ |;&]*\).*/\1/p' | head -1)"
        if [[ -z "$pkg" ]]; then
            pkg="$(echo "$cmd" | sed -n 's/.*dnf install \([^ |;&]*\).*/\1/p' | head -1)"
        fi
        if [[ -n "$pkg" && "$pkg" != "-y" ]]; then
            echo "native|$pkg"
            return 0
        fi
    fi

    if echo "$cmd" | grep -q 'pacman -S'; then
        pkg="$(echo "$cmd" | sed -n 's/.*pacman -S --noconfirm \([^ |;&]*\).*/\1/p' | head -1)"
        if [[ -z "$pkg" ]]; then
            pkg="$(echo "$cmd" | sed -n 's/.*pacman -S \([^ |;&]*\).*/\1/p' | head -1)"
        fi
        if [[ -n "$pkg" && "$pkg" != "--noconfirm" ]]; then
            echo "native|$pkg"
            return 0
        fi
    fi

    return 1
}

catalog_has_update() {
    local id="$1"
    local spec kind pkg

    # Package-manager packages: only when outdated
    if spec="$(catalog_pkg_spec "$id")"; then
        kind="${spec%%|*}"
        pkg="${spec#*|}"
        pkgmgr_package_outdated "$kind" "$pkg"
        return $?
    fi

    # Script-managed items that opt into “offer re-run / update”
    if [[ "$(catalog_get "$id" upgrade_offer)" == "always" ]]; then
        local upgrade_cmd
        upgrade_cmd="$(catalog_resolve_upgrade_cmd "$id")"
        [[ -n "$upgrade_cmd" ]]
        return $?
    fi
    return 1
}

catalog_resolve_upgrade_cmd() {
    local id="$1"
    local explicit

    explicit="$(catalog_get "$id" upgrade_script)"
    [[ -n "$explicit" ]] && { echo "$explicit"; return 0; }

    if [[ "${PKG_MGR:-}" == "brew" ]]; then
        explicit="$(catalog_get "$id" upgrade_brew)"
        [[ -n "$explicit" ]] && { echo "$explicit"; return 0; }
    else
        explicit="$(catalog_get "$id" "upgrade_${PKG_MGR}")"
        [[ -n "$explicit" ]] && { echo "$explicit"; return 0; }
    fi

    local spec kind pkg
    spec="$(catalog_pkg_spec "$id")" || return 1
    kind="${spec%%|*}"
    pkg="${spec#*|}"

    case "${PKG_MGR:-}" in
        brew)
            if [[ "$kind" == "cask" ]]; then
                echo "brew upgrade --cask $pkg"
            else
                echo "brew upgrade $pkg"
            fi
            ;;
        apt)
            echo "sudo apt-get install --only-upgrade -y $pkg"
            ;;
        dnf)
            echo "sudo dnf upgrade -y $pkg"
            ;;
        pacman)
            echo "sudo pacman -S --noconfirm $pkg"
            ;;
        *)
            return 1
            ;;
    esac
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
    # shellcheck disable=SC1091
    source "$catalog_dir/browsers.sh"
    # shellcheck disable=SC1091
    source "$catalog_dir/cli-tools.sh"
    # shellcheck disable=SC1091
    source "$catalog_dir/apps.sh"
}
