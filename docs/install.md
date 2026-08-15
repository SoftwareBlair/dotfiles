# Install

Supported platforms: **macOS** and **Linux**. Package manager: **Homebrew only** (installed automatically on Linux if missing).

## Prerequisites

- A terminal
- Network access to GitHub / Homebrew
- The wizard can install **git** and **curl** via brew if they are missing

## Curl one-liner

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
```

This will:

1. Clone or reuse the repo under `~/dotfiles` (override with `DOTFILES_DIR`)
2. Optionally try to download a Go TUI binary (not required - wizard uses **gum**)
3. Launch the **bash + gum** setup wizard

### Useful flags

```bash
/bin/bash -c "$(curl -fsSL .../install.sh)" -- -n          # dry-run (no writes)
/bin/bash -c "$(curl -fsSL .../install.sh)" -- -y          # non-interactive defaults
/bin/bash -c "$(curl -fsSL .../install.sh)" -- -y -n       # non-interactive dry-run
```

Environment: `DOTFILES_REPO`, `DOTFILES_REF`, `DOTFILES_DIR`, `DOTFILES_DRY_RUN`, `DOTFILES_YES`.

### Testing a branch before merge

```bash
DOTFILES_REF=cursor/cross-platform-setup-wizard-5b1c \
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/cursor/cross-platform-setup-wizard-5b1c/install.sh)" -- -n
```

## From a clone

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git ~/dotfiles
cd ~/dotfiles
./.scripts/setup.sh
./.scripts/setup.sh -n    # dry-run
```

## Optional Go TUI

The Bubble Tea TUI is **experimental** and not used by `install.sh` by default:

```bash
cd .scripts/tui && go build -o ../bin/dotfiles-setup .
../setup.sh --tui
```
