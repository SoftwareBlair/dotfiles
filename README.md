# Developer Machine Setup (macOS + Linux)

Interactive wizard to bootstrap a new developer machine: coding fonts, editors/terminals, **zsh**, and shell tools — with your choice of package manager (**Homebrew**, **apt**, **dnf**, or **pacman**).

Personal dotfiles in this repo can be symlinked or copied. Starship / Oh My Zsh are **installed and configured** (with conflict handling when both are selected).

**Windows is not supported.**

## Prerequisites

- `git` and `curl`
- `sudo` for system package installs (apt/dnf/pacman)
- A terminal that supports interactive prompts (or use `-y` / `--dry-run`)

## Quick start

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

The repo can live **anywhere** — you are no longer required to use `~/dotfiles`. Moving there is optional.

```bash
./setup.sh -c move_dotfiles   # optional
```

Restart your terminal when finished.

## Presets

| Preset | Includes |
|--------|----------|
| **personal** | SFMono, VS Code, Warp, Zed, zsh, Starship, eza, NVM, plugins, fzf, zoxide |
| **minimal** | zsh + Starship + eza |
| **full** | Everything available for this OS / package manager |
| **custom** | Pick each category interactively |

```bash
./setup.sh --preset personal
./setup.sh -y --preset minimal --pkgmgr apt
```

`-y` uses the **personal** preset by default (not “select everything”).

## Interactive wizard

1. Detects OS / distro / arch  
2. Offers resume if a previous install log exists (full wizard / add tools / undo)  
3. Chooses package manager  
4. Chooses a **preset** or custom categories  
5. Suggests dependencies (e.g. Nerd Font when Starship is selected)  
6. Resolves **Starship vs Oh My Zsh** if both are selected  
7. Optional Git config  
8. Smart symlink/copy suggestions based on selections  
9. Preview plan or install  
10. Writes shell features + end-of-run report  

### Starship & Oh My Zsh configuration

| Mode | Behavior |
|------|----------|
| **Starship** (default if both) | Modular `.zshrc` loads Starship; OMZ may be installed but not loaded |
| **Oh My Zsh** | Modular `.zshrc` loads OMZ as primary |
| **Merged** | OMZ plugins + Starship as the prompt (`ZSH_THEME=""`) |

Features are written to `~/.dotfiles-setup/shell-features.zsh` and sourced by [`.zshrc`](.zshrc).

## Package managers

| Manager | macOS | Linux |
|---------|-------|-------|
| Homebrew | Yes | Yes (Linuxbrew) |
| apt | — | Debian / Ubuntu |
| dnf | — | Fedora / RHEL |
| pacman | — | Arch |

```bash
./setup.sh --pkgmgr apt
```

## Dry run

```bash
./setup.sh --dry-run
./setup.sh --preset personal -n --pkgmgr brew
./setup.sh -y --preset minimal --dry-run
```

## Saved plans

```bash
./setup.sh --export-plan ~/my-setup.env
./setup.sh --plan ~/my-setup.env --dry-run
```

Plans are also saved to `~/.dotfiles-setup/last-plan.env` after a successful run.

## Undo / revert

```bash
./setup.sh --undo
./setup.sh --undo --dry-run
./setup.sh --undo --select
./setup.sh -c revert_setup
```

- Only wizard-owned installs/symlinks are removed  
- `~/.gitconfig` is never deleted  
- Homebrew removal is opt-in  

## Flags reference

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show help |
| `-y`, `--yes` | Non-interactive (personal preset) |
| `-n`, `--dry-run` | Preview only |
| `--preset <name>` | `minimal` \| `personal` \| `full` \| `custom` |
| `--plan <file>` | Apply a saved plan |
| `--export-plan [file]` | Write a plan file |
| `--undo` / `--select` | Reverse logged actions |
| `--pkgmgr <name>` | `brew` \| `apt` \| `dnf` \| `pacman` |
| `-c <command>` | Run a helper |

## Dotfiles layout

| Path | Role |
|------|------|
| `.zshrc` | Modular entrypoint (`DOTFILES_DIR`, features, aliases, plugins, OMZ, Starship) |
| `.zsh/starship.zsh` | Starship init when enabled |
| `.zsh/oh-my-zsh.zsh` | Oh My Zsh when enabled |
| `.zsh/plugins.zsh` | autosuggestions, syntax-highlighting, z, zoxide |
| `.config/starship.toml` | Starship theme |
| `.config/zed/` | Zed settings (when Zed selected) |
| `.warp/` | Warp themes (when Warp selected) |
Link mode: **symlink** (default) or **copy**.

Shell support is **zsh only** for now (bash and fish are not offered).

## State files

```text
~/.dotfiles-setup/
  install-log.jsonl      # undo source of truth
  shell-features.zsh     # ENABLE_STARSHIP / ENABLE_OMZ / DOTFILES_DIR
  last-plan.env          # reusable plan
  backups/               # pre-overwrite backups
~/.dotfiles-setup.conf   # last pkgmgr, preset, selections
```

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Prompt not showing Starship | Check `~/.dotfiles-setup/shell-features.zsh` and restart terminal |
| OMZ not loading | Ensure profile mode is `oh-my-zsh` or `merged`; re-run wizard |
| Fonts missing glyphs | Set terminal font to a Nerd Font |
| Wrong repo path | Features file stores `DOTFILES_DIR`; re-run setup after moving |

## Contributing

Fork, branch, and open a pull request.

## License

MIT — see [LICENSE](LICENSE).
