# Architecture

```text
┌─────────────────┐     catalog JSON      ┌──────────────────┐
│  Go TUI         │ ←── export_wizard ─── │  bash setup.sh   │
│  (Bubble Tea)   │                       │  + catalog       │
│                 │ ── engine Run -y ───→ │  + generate.sh   │
└─────────────────┘                       │  + migrate.sh    │
                                          └──────────────────┘
                                                    │
                                                    ▼
                                          ~/.zshrc + generated/
                                          packages via brew/apt/…
```

## Layers

| Layer | Path | Role |
|-------|------|------|
| TUI | `.scripts/tui/` | Wizard UX, previews, dry-run toggle |
| Engine | `setup.sh` + `lib/` | Packages, migrate, generate, undo log |
| Profiles | `profiles/*.toml` | Package lists + theme ids |
| Templates | `templates/` | zsh modules + themes |

## Module ↔ package map

| Selection id | Install? | Generated module |
|--------------|----------|------------------|
| `zsh` | yes | orchestrator only |
| `starship` | yes | `starship.zsh` + theme toml |
| `nvm` | yes | `nvm.zsh` |
| `zsh_autosuggestions` | yes | `zsh_autosuggestions.zsh` |
| `zsh_syntax_highlighting` | yes | `zsh_syntax_highlighting.zsh` |
| `z` | yes | `z.zsh` |
| `eza` | yes | `eza.zsh` (skipped if `zsh_aliases` also selected) |
| `zsh_aliases` | no | `aliases.zsh` |
| `oh_my_zsh` | yes | `oh-my-zsh.zsh` |

## State

`~/.dotfiles-setup/` holds `install-log.jsonl`, `setup.conf`, `shell-features.zsh` (`DOTFILES_SETUP_SCHEMA=2`), `generated/`, and backups.

## Migrate signals

- Prior setup without schema v2  
- `~/.zshrc` symlink into an old clone  
- Unmanaged `~/.zshrc` without the generated marker  
