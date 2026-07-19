# Setup TUI (Bubble Tea)

Go terminal UI for the new-machine setup wizard. It loads the package catalog from bash (`setup.sh -c export_wizard_catalog`), lets you pick a package manager and packages, then runs the existing bash engine non-interactively.

## Build

```bash
cd .scripts/tui
go build -o dotfiles-setup .
```

## Run

```bash
# From .scripts — prefers the TUI when the binary exists
./setup.sh --tui
./setup.sh --tui -n          # start in dry-run mode
./setup.sh --bash            # classic gum/bash prompts

# Or run the binary directly
./tui/dotfiles-setup --dry-run --pkgmgr apt
./tui/dotfiles-setup --catalog testdata/catalog_linux_apt.json --dry-run
```

## Tests

```bash
./tui/test.sh
# or
cd tui && go test ./...
```

Tests cover:
- catalog JSON parsing (fixture)
- wizard state machine (selection, navigation, summary text)
- Bubble Tea key handling → expected view contents
- engine argv/env wiring (fake `setup.sh`)

## Keys

| Screen | Keys |
|--------|------|
| Package manager | ↑/↓, enter |
| Packages | ↑/↓, space toggle, `a` all, `d` defaults, `c` clear, enter |
| Confirm | enter run, `n` toggle dry-run, esc back |
| Done | enter / q |
