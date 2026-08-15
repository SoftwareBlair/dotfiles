# Architecture

## Primary path

```text
install.sh  →  clone repo  →  .scripts/setup.sh --bash
                                 ↓
                    gum wizard (brew-first)
                                 ↓
              shell stack → app picker → confirm
                                 ↓
         installer_offer_updates → brew install → generate_configs
```

| Piece | Path | Role |
|-------|------|------|
| Bootstrap | `install.sh` | Clone + launch gum wizard |
| Engine | `.scripts/setup.sh` | Orchestration |
| Prompts | `.scripts/lib/prompts.sh` | gum (+ fallback) |
| Catalog | `.scripts/catalog/*.sh` | Package recipes (prefer brew) |
| Presets | `.scripts/lib/presets.sh` | Fixed shell IDs + app picker |
| Installer | `.scripts/lib/installer.sh` | Install + update prompts |
| Generator | `.scripts/lib/generate.sh` | Modular zsh into `$HOME` |
| Dry-run | `.scripts/lib/dry-run.sh` | Plan builder (no writes) |

## Package manager

**Homebrew only** on the main path. Linux installs brew if missing. apt/dnf recipes may still exist in the catalog for legacy/undo but are not offered in the wizard.

## Shell modules

Selected shell ids map to `templates/zsh/modules/*.zsh.tmpl` → `~/.dotfiles-setup/generated/`. Starship theme from `templates/themes/stock/`.

## Optional Go TUI

`.scripts/tui/` remains for experiments (`setup.sh --tui`). Not required for curl install.
