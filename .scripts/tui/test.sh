#!/bin/bash
# Run Go TUI unit tests (+ catalog export + generate smoke)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
cd "$DIR"

if ! command -v go >/dev/null 2>&1; then
    echo "go not installed — skipping TUI tests."
    exit 0
fi

echo "Running Go tests in .scripts/tui…"
go test ./...

echo "Smoke: export_wizard_catalog JSON…"
if ! ../setup.sh --pkgmgr apt --profile default -c export_wizard_catalog >/tmp/dotfiles-catalog.json; then
    echo "export_wizard_catalog failed" >&2
    exit 1
fi
python3 -c '
import json
d=json.load(open("/tmp/dotfiles-catalog.json"))
assert "packages" in d and len(d["packages"])>0
assert "profiles" in d and len(d["profiles"])>=2
assert any(p["id"]=="default" for p in d["profiles"])
print("OK — %d packages, %d profiles, pkgmgr=%s" % (len(d["packages"]), len(d["profiles"]), d["pkgmgr"]))
'

echo "Smoke: generate configs (subset)…"
TMPHOME="$(mktemp -d)"
export HOME="$TMPHOME"
# shellcheck disable=SC1091
source "$ROOT/.scripts/helpers.sh"
STATE_DIR="$HOME/.dotfiles-setup"
BACKUP_DIR="$HOME/.dotfiles-setup/backups"
INSTALL_LOG="$HOME/.dotfiles-setup/install-log.jsonl"
SETUP_CONF="$HOME/.dotfiles-setup/setup.conf"
mkdir -p "$BACKUP_DIR" && touch "$INSTALL_LOG"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/dry-run.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/catalog.sh"
load_catalogs
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/installer.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/profiles.sh"
# shellcheck disable=SC1091
source "$ROOT/.scripts/lib/generate.sh"
profile_load default
SELECTED_IDS=(zsh starship)
THEME_STARSHIP=stock
generate_configs
test -f "$HOME/.zshrc"
test -f "$HOME/.dotfiles-setup/generated/starship.zsh"
grep -q 'starship.zsh' "$HOME/.zshrc"
SELECTED_IDS=(zsh nvm)
generate_configs
test -f "$HOME/.dotfiles-setup/generated/nvm.zsh"
test ! -f "$HOME/.dotfiles-setup/generated/starship.zsh"
echo "OK — generate + prune"
rm -rf "$TMPHOME"

echo "Smoke: dry-run creates no ~/.dotfiles-setup…"
TMPHOME="$(mktemp -d)"
if ! HOME="$TMPHOME" bash "$ROOT/.scripts/setup.sh" -y -n --profile default --pkgmgr apt --bash >/tmp/dotfiles-dry-run.out 2>&1; then
    echo "dry-run setup failed:" >&2
    cat /tmp/dotfiles-dry-run.out >&2
    rm -rf "$TMPHOME"
    exit 1
fi
if [[ -e "$TMPHOME/.dotfiles-setup" ]]; then
    echo "dry-run created ~/.dotfiles-setup — must create nothing" >&2
    find "$TMPHOME" -maxdepth 3 -print >&2
    rm -rf "$TMPHOME"
    exit 1
fi
if [[ -e "$TMPHOME/.zshrc" || -e "$TMPHOME/.zshenv" || -e "$TMPHOME/.config/starship.toml" ]]; then
    echo "dry-run wrote shell configs — must create nothing" >&2
    find "$TMPHOME" -maxdepth 3 -print >&2
    rm -rf "$TMPHOME"
    exit 1
fi
grep -q 'Dry run complete\|No changes were made\|DRY RUN' /tmp/dotfiles-dry-run.out \
    || { echo "dry-run output missing completion marker:" >&2; cat /tmp/dotfiles-dry-run.out >&2; rm -rf "$TMPHOME"; exit 1; }
echo "OK — dry-run left HOME empty of setup artifacts"
rm -rf "$TMPHOME"

echo "Smoke: validate-profiles…"
bash "$ROOT/.scripts/validate-profiles.sh" || exit 1

echo "All TUI tests passed."
