#!/bin/bash
# Run Go TUI unit tests (+ catalog / generate / dry-run smokes)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
cd "$DIR"

if ! command -v go >/dev/null 2>&1; then
    echo "go not installed - skipping Go TUI tests."
else
    echo "Running Go tests in .scripts/tui..."
    go test ./...
fi

echo "Smoke: export_wizard_catalog JSON..."
../setup.sh --pkgmgr brew -c export_wizard_catalog >/tmp/dotfiles-catalog.json
python3 -c '
import json
d=json.load(open("/tmp/dotfiles-catalog.json"))
assert "packages" in d and len(d["packages"])>0, d
ids={p["id"] for p in d["packages"]}
for need in ("zsh","starship","chrome","gh","onepassword","docker"):
    assert need in ids, "missing %s in %s" % (need, sorted(ids))
print("OK - %d packages, pkgmgr=%s" % (len(d["packages"]), d["pkgmgr"]))
'

echo "Smoke: brew-first shell + app ids resolve..."
# shellcheck disable=SC1091
source "$ROOT/.scripts/helpers.sh"
PLATFORM=linux
PKG_MGR=brew
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/platform.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/catalog.sh"
load_catalogs
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/presets.sh"
for id in zsh starship zsh_autosuggestions; do
    catalog_available "$id" || { echo "MISSING required: $id" >&2; exit 1; }
done
for id in chrome firefox gh wget docker python go pnpm yarn onepassword onepassword_cli discord slack signal vlc; do
    catalog_available "$id" || echo "INFO: optional not available on ${PLATFORM}/brew: $id"
done
echo "OK - shell ids available under brew"

echo "Smoke: generate configs (subset)..."
TMPHOME="$(mktemp -d)"
export HOME="$TMPHOME"
STATE_DIR="$HOME/.dotfiles-setup"
BACKUP_DIR="$HOME/.dotfiles-setup/backups"
INSTALL_LOG="$HOME/.dotfiles-setup/install-log.jsonl"
SETUP_CONF="$HOME/.dotfiles-setup/setup.conf"
mkdir -p "$BACKUP_DIR" && touch "$INSTALL_LOG"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/dry-run.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/installer.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/generate.sh"
SELECTED_IDS=(zsh starship)
THEME_STARSHIP=stock
DOTFILES_DIR="$ROOT"
generate_configs
test -f "$HOME/.zshrc"
test -f "$HOME/.dotfiles-setup/generated/starship.zsh"
grep -q 'starship.zsh' "$HOME/.zshrc"
SELECTED_IDS=(zsh nvm)
generate_configs
test -f "$HOME/.dotfiles-setup/generated/nvm.zsh"
test ! -f "$HOME/.dotfiles-setup/generated/starship.zsh"
echo "OK - generate + prune"
rm -rf "$TMPHOME"

echo "Smoke: dry-run creates no ~/.dotfiles-setup..."
TMPHOME="$(mktemp -d)"
if ! HOME="$TMPHOME" bash "$ROOT/.scripts/setup.sh" -y -n --bash >/tmp/dotfiles-dry-run.out 2>&1; then
    echo "dry-run setup failed:" >&2
    cat /tmp/dotfiles-dry-run.out >&2
    rm -rf "$TMPHOME"
    exit 1
fi
if [[ -e "$TMPHOME/.dotfiles-setup" ]]; then
    echo "dry-run created ~/.dotfiles-setup - must create nothing" >&2
    find "$TMPHOME" -maxdepth 3 -print >&2
    rm -rf "$TMPHOME"
    exit 1
fi
if [[ -e "$TMPHOME/.zshrc" || -e "$TMPHOME/.zshenv" || -e "$TMPHOME/.config/starship.toml" ]]; then
    echo "dry-run wrote shell configs - must create nothing" >&2
    find "$TMPHOME" -maxdepth 3 -print >&2
    rm -rf "$TMPHOME"
    exit 1
fi
grep -q 'Dry run complete\|No changes were made\|DRY RUN' /tmp/dotfiles-dry-run.out \
    || { echo "dry-run output missing completion marker:" >&2; cat /tmp/dotfiles-dry-run.out >&2; rm -rf "$TMPHOME"; exit 1; }
echo "OK - dry-run left HOME empty of setup artifacts"
rm -rf "$TMPHOME"

echo "Smoke: validate-profiles..."
bash "$ROOT/.scripts/validate-profiles.sh"

echo "All tests passed."
