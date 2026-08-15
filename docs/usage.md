# Usage

## Start the wizard

```bash
./.scripts/setup.sh
# or after curl install:
# (from ~/dotfiles)
./.scripts/setup.sh
```

Uses **gum** for prompts (offers to download gum if missing).

## Flow

1. **Platform** - macOS or Linux  
2. **Homebrew** - install if missing (Linux included)  
3. **Shell** - fixed stack: zsh, Starship, autosuggestions, syntax highlighting, eza, z (+ aliases module)  
4. **Apps** - gum multi-select (pre-selects Cursor, Warp, NVM; opt-in for browsers, chat, CLI, ...)  
5. **Confirm** - Install now, or **Preview plan (dry-run)**  
6. **Updates** - for already-installed selections that are outdated, prompt before upgrading  
7. **Install + generate** - brew install missing packages; write `~/.zshrc` / modules / starship  

Oh My Zsh is **not** offered.

## Dry-run

True no-op: **no** brew installs, **no** config writes, **no** `~/.dotfiles-setup/`.

```bash
./.scripts/setup.sh -n
./.scripts/setup.sh -y -n
/bin/bash -c "$(curl -fsSL .../install.sh)" -- -n
```

Interactive: on confirm, choose **Preview plan (dry-run)**.

## Updates

After confirm, for each selected package that is already installed:

- Up to date → skip with a message  
- Outdated → listed, then prompt **Update these packages now?** (default yes; `-y` accepts)  
- Declining keeps the current version  

Dry-run records would-be upgrades in the printed plan only.

## Generated files

| Path | Role |
|------|------|
| `~/.zshrc` / `~/.zshenv` | Orchestrators (regenerated) |
| `~/.dotfiles-setup/generated/*.zsh` | Modules from the shell stack |
| `~/.config/starship.toml` | Stock Starship theme |
| `~/.dotfiles-setup/shell-features.zsh` | Feature flags |
| `~/.zshrc.local` | **Your** overrides - never overwritten |

## Flags

| Flag | Meaning |
|------|---------|
| `-n` / `--dry-run` | Plan only |
| `-y` / `--yes` | Non-interactive (shell + default apps; auto-accept updates) |
| `--undo` | Reverse logged actions |
| `--tui` | Optional experimental Go TUI |

## Undo

```bash
./.scripts/setup.sh --undo
./.scripts/setup.sh --undo -n
```
