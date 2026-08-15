#!/usr/bin/env bash
# Validate profiles/*.toml against catalog ids and theme directories
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/.scripts/helpers.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/platform.sh"
init_platform
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/catalog.sh"
load_catalogs
PKG_MGR="${PKG_MGR:-brew}"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/profiles.sh"

errors=0
for f in profiles/*.toml; do
    [[ -f "$f" ]] || continue
    id="$(basename "$f" .toml)"
    echo "==> validating @$id"
    if ! profile_load "$id"; then
        echo "FAIL: cannot load $id" >&2
        errors=$((errors + 1))
        continue
    fi
    theme_dir="$ROOT/templates/themes/${THEME_STARSHIP:-stock}"
    if [[ ! -d "$theme_dir" ]]; then
        echo "FAIL: @$id theme missing: $theme_dir" >&2
        errors=$((errors + 1))
    fi
    for pkg in $MY_SETUP $MY_SETUP_MACOS $MY_SETUP_OPTIONAL; do
        [[ -z "$pkg" ]] && continue
        # Must exist in catalog registry
        if [[ -z "$(catalog_get "$pkg" name 2>/dev/null)" ]]; then
            echo "FAIL: @$id unknown catalog id: $pkg" >&2
            errors=$((errors + 1))
            continue
        fi
        if ! catalog_available "$pkg" 2>/dev/null; then
            echo "INFO: @$id package not available on ${PLATFORM:-?}/${PKG_MGR}: $pkg (ok if platform-specific)" >&2
        fi
    done
done

if [[ "$errors" -gt 0 ]]; then
    echo "Profile validation failed ($errors errors)" >&2
    exit 1
fi
echo "All profiles OK"
