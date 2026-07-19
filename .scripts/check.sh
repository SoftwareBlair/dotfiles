#!/bin/bash
# Lightweight lint for setup scripts (requires shellcheck)
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not installed — skipping."
    echo "  macOS: brew install shellcheck"
    echo "  Debian/Ubuntu: sudo apt-get install -y shellcheck"
    exit 0
fi

files=(
    "$SCRIPTS_DIR/setup.sh"
    "$SCRIPTS_DIR/helpers.sh"
    "$SCRIPTS_DIR/check.sh"
    "$SCRIPTS_DIR/lib"/*.sh
    "$SCRIPTS_DIR/catalog"/*.sh
)

echo "Running shellcheck on ${#files[@]} files…"
# Bash 3.2-friendly; allow sourced libs without following every path
shellcheck -x -s bash "${files[@]}"
echo "OK"

if [[ -x "$SCRIPTS_DIR/tui/test.sh" ]] || [[ -f "$SCRIPTS_DIR/tui/test.sh" ]]; then
    bash "$SCRIPTS_DIR/tui/test.sh"
fi
