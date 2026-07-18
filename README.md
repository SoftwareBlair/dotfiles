# New machine setup (macOS + Linux)

Personal dotfiles plus a setup script that installs **your usual stack**, then symlinks this repo’s configs into `$HOME`.

## Quick start

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

Confirm once and it installs. If something is already present and an update is available, you’ll be offered a chance to upgrade it (auto-accepted with `-y`).

The repo can live **anywhere**; moving to `~/dotfiles` is optional.

```bash
./setup.sh -c move_dotfiles   # optional
```

Restart your terminal when finished.

## Common commands

```bash
./setup.sh                 # confirm, then install
./setup.sh -y              # non-interactive install
./setup.sh -n              # dry-run (preview only)
./setup.sh -y -n           # non-interactive dry-run
./setup.sh --pkgmgr apt    # brew | apt | dnf | pacman
./setup.sh --undo          # reverse logged installs + symlinks
./setup.sh --undo -n       # preview undo
./setup.sh -h              # help
```

## What’s installed

Defined in [`.scripts/lib/presets.sh`](.scripts/lib/presets.sh):

| Item | Notes |
|------|--------|
| SFMono Nerd Font | Patched + ligaturized (not Apple’s stock SF Mono) |
| Starship | Prompt (via this repo’s `.zshrc`) |
| eza | `ls` replacement |
| Warp | Terminal (+ `.warp` config) |
| **Cursor** | Default editor |
| Zed | Fast editor (settings under `.config/zed`) |
| zsh + autosuggestions + syntax-highlighting + z | Shell plugins |
| NVM | Node version manager |
| Raycast | macOS only (`MY_SETUP_MACOS`) |
| VS Code | Optional when a recipe exists (`MY_SETUP_OPTIONAL`) |

To change the stack, edit `MY_SETUP`, `MY_SETUP_MACOS`, or `MY_SETUP_OPTIONAL` in `presets.sh`.

## Package managers

| Manager | macOS | Linux |
|---------|-------|-------|
| Homebrew | Yes (preferred when installed) | Yes (Linuxbrew) |
| apt | — | Debian / Ubuntu (used by `-y` if brew missing) |
| dnf | — | Fedora / RHEL |
| pacman | — | Arch |

### Updates for already-installed tools

| Kind | Behavior |
|------|----------|
| brew / apt / dnf / pacman packages | Detect outdated → offer upgrade |
| Script installs (NVM, SFMono, some Zed/Starship paths) | Offer re-run update when marked `upgrade_offer=always` |

`-y` accepts the upgrade prompt. Upgrades are logged but **not** uninstalled by `--undo`.

## Dotfiles linked

Symlinked into `$HOME` (not copied):

- `.zshrc`, `.zshenv`, `.config` (includes Starship + Zed)
- `.warp` when Warp is installed

Shell feature flags are written to `~/.dotfiles-setup/shell-features.zsh` and sourced by [`.zshrc`](.zshrc).

### Secrets (`~/.zprofile`)

Setup can create or extend **`~/.zprofile`** for local secrets (API keys, tokens). That file lives in your home directory — outside this repo. Non-login shells also load it via [`.zshrc`](.zshrc).

### Repo layout

| Path | Role |
|------|------|
| [`.zshrc`](.zshrc) | Modular entrypoint (`DOTFILES_DIR`, features, aliases, plugins, Starship) |
| [`.zshenv`](.zshenv) | Early env (NVM / Starship path helpers) |
| [`.zsh/`](.zsh/) | `aliases.zsh`, `nvm.zsh`, `plugins.zsh`, `starship.zsh`, … |
| [`.config/starship.toml`](.config/starship.toml) | Starship theme |
| [`.config/zed/`](.config/zed/) | Zed settings / themes |
| [`.warp/`](.warp/) | Warp settings / themes |
| [`.scripts/setup.sh`](.scripts/setup.sh) | Installer entrypoint |
| [`.scripts/lib/presets.sh`](.scripts/lib/presets.sh) | Default stack definition |
| [`.scripts/catalog/`](.scripts/catalog/) | Install recipes |

## Undo

```bash
./setup.sh --undo
./setup.sh --undo -n       # preview
./setup.sh --undo --select # pick which logged actions to reverse
./setup.sh -c revert_setup
```

Reverses actions recorded in the install log, including package installs, **symlinks** (with backups), and config blocks setup added. `~/.gitconfig` is never deleted. Homebrew removal is opt-in.

## Helper commands (`-c`)

```bash
./setup.sh -c move_dotfiles
./setup.sh -c remove_git_origin_remote
./setup.sh -c symlink_dotfile .zshrc
./setup.sh -c unlink_dotfile .zshrc
./setup.sh -c uninstall_nvm
./setup.sh -c revert_setup
```

## Flags

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show help |
| `-y`, `--yes` | Non-interactive (auto-confirm) |
| `-n`, `--dry-run` | Preview plan; change nothing |
| `--pkgmgr <name>` | `brew` \| `apt` \| `dnf` \| `pacman` |
| `--undo` | Reverse logged actions |
| `--select` | With `--undo`, choose which actions to reverse |
| `-c <command>` | Run a helper (see above) |

## State files

```text
~/.dotfiles-setup/
  install-log.jsonl      # undo source of truth
  shell-features.zsh     # DOTFILES_DIR, Starship flags
  backups/               # pre-overwrite backups
~/.dotfiles-setup.conf   # last package manager preference
```

## Lint

```bash
./.scripts/check.sh      # shellcheck when installed
```

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Prompt not showing Starship | Check `~/.dotfiles-setup/shell-features.zsh`, then restart the terminal |
| Missing glyphs / icons | Set the terminal font to **SFMono Nerd Font** (Liga SFMono) |
| Secrets missing in terminal | Confirm `~/.zprofile` has the secrets block; restart (non-login shells load it via `.zshrc`) |
| Wrong repo path after moving | Re-run `./setup.sh` (or `-y`) so `DOTFILES_DIR` is rewritten |
| Undo didn’t remove a symlink | Only logged symlink actions are reversed |

## License

MIT — see [LICENSE](LICENSE).
