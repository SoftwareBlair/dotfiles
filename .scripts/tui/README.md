# Setup TUI (Bubble Tea)

Go terminal UI for the new-machine setup wizard. It loads the package catalog from bash (`setup.sh -c export_wizard_catalog`), lets you pick a package manager and packages, then runs the existing bash engine non-interactively.

## Install (no Go required)

End users should use the repo root one-liner — it clones/tarballs the repo, downloads a prebuilt binary from GitHub Releases into `.scripts/bin/dotfiles-setup`, and launches the wizard:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
```

Binaries are published by `.github/workflows/release-tui.yml` on `v*` tags (`dotfiles-setup-{linux,darwin}-{amd64,arm64}`).

## Build

```bash
cd .scripts/tui
go build -o dotfiles-setup .
```

## Run

```bash
# From .scripts — prefers .scripts/bin/dotfiles-setup, then ./tui/dotfiles-setup
./setup.sh --tui
./setup.sh --tui -n          # start in dry-run mode
./setup.sh --profile SoftwareBlair --tui
./setup.sh --bash            # classic gum/bash prompts

# Or run the binary directly
./tui/dotfiles-setup --dry-run --pkgmgr apt --profile SoftwareBlair
./tui/dotfiles-setup --catalog testdata/catalog_linux_apt.json --dry-run
```

Profiles live in `profiles/<GitHubUsername>.toml` (see `profiles/README.md`).

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
