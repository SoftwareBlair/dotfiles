#!/bin/bash
# Run Go TUI unit tests (+ optional live catalog export smoke test)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if ! command -v go >/dev/null 2>&1; then
    echo "go not installed — skipping TUI tests."
    exit 0
fi

echo "Running Go tests in .scripts/tui…"
go test ./...

echo "Smoke: export_wizard_catalog JSON…"
if ! ../setup.sh --pkgmgr apt -c export_wizard_catalog >/tmp/dotfiles-catalog.json; then
    echo "export_wizard_catalog failed" >&2
    exit 1
fi
python3 -c 'import json; d=json.load(open("/tmp/dotfiles-catalog.json")); assert "packages" in d and len(d["packages"])>0; print("OK — %d packages for %s" % (len(d["packages"]), d["pkgmgr"]))'

echo "All TUI tests passed."
