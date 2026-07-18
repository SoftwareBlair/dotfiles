# My machine setup (macOS + Linux)

Personal dotfiles plus a setup script that installs **my usual stack**, then symlinks this repo’s configs into `$HOME`.

## Quick start

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

Confirm once and it installs. If something is already present and the package manager reports an update, you’ll be offered a chance to upgrade it (auto-accepted with `-y`).

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
| SFMono Nerd Font | Terminal / editor font |
| Starship | Prompt (via this repo’s `.zshrc`) |
| eza | `ls` replacement |
| Warp | Terminal (+ `.warp` config) |
| **Cursor** | Default editor |
| Zed | Fast editor (+ `.config/zed`) |
| zsh + autosuggestions + syntax-highlighting + z | Shell plugins |
| NVM | Node version manager |
| Raycast | macOS only (`MY_SETUP_MACOS`) |
| VS Code | Optional when a recipe exists (`MY_SETUP_OPTIONAL`) |

To change the stack, edit `MY_SETUP`, `MY_SETUP_MACOS`, or `MY_SETUP_OPTIONAL` in `presets.sh`.

## Package managers

| Manager | macOS | Linux |
|---------|-------|-------|
| Homebrew (default) | Yes | Yes (Linuxbrew) |
| apt | — | Debian / Ubuntu |
| dnf | — | Fedora / RHEL |
| pacman | — | Arch |

Homebrew is preferred so Mac and Linux stay close to the same workflow.

### Updates for already-installed tools

During setup, anything already installed is checked for updates via the active package manager:

| Manager | How updates are detected |
|---------|--------------------------|
| Homebrew | `brew outdated` (formula / cask) |
| apt | Installed vs candidate version |
| dnf | `dnf check-update` |
| pacman | `pacman -Qu` |

If updates are available, setup lists them and asks once: **Update these packages now?** (`-y` accepts). Version bumps are logged as `upgrade` actions and are **not** uninstalled by `--undo`.

Script-only installs (e.g. NVM curl installer, some font downloads) can’t always detect updates and are left as-is when already present.

## Dotfiles linked

Symlinked into `$HOME` (not copied):

- `.zshrc`, `.zshenv`, `.config`
- `.warp` when Warp is installed
- `.config/zed` when Zed is installed

Shell feature flags are written to `~/.dotfiles-setup/shell-features.zsh` and sourced by [`.zshrc`](.zshrc).

### Secrets (`.zprofile`)

Setup can create an untracked **`.zprofile`** in the repo root for local secrets (API keys, tokens). It is listed in [`.gitignore`](.gitignore) so it is never committed, and is sourced from [`.zshenv`](.zshenv) when present.

### Repo layout

| Path | Role |
|------|------|
| [`.zshrc`](.zshrc) | Modular entrypoint (`DOTFILES_DIR`, features, aliases, plugins, Starship) |
| [`.zshenv`](.zshenv) | Early env (NVM / Starship path helpers; sources local `.zprofile`) |
| `.zprofile` | Local secrets (gitignored — created by setup if you opt in) |
| [`.zsh/`](.zsh/) | `aliases.zsh`, `nvm.zsh`, `plugins.zsh`, `starship.zsh`, … |
| [`.config/starship.toml`](.config/starship.toml) | Starship theme |
| [`.config/zed/`](.config/zed/) | Zed settings / themes |
| [`.warp/`](.warp/) | Warp settings / themes |
| [`.scripts/setup.sh`](.scripts/setup.sh) | Installer entrypoint |
| [`.scripts/lib/presets.sh`](.scripts/lib/presets.sh) | Default stack definition |
| [`.scripts/catalog/`](.scripts/catalog/) | Install recipes (fonts, editors, shells, …) |

## Undo

```bash
./setup.sh --undo
./setup.sh --undo -n       # preview
./setup.sh --undo --select # pick which logged actions to reverse
./setup.sh -c revert_setup
```

Reverses actions recorded in the install log, including:

- Package installs owned by this script
- **Symlinks** created by setup (and restores backups when present)
- Repo files / config blocks the script added (e.g. brew shellenv marker)

`~/.gitconfig` is never deleted. Homebrew removal is opt-in when prompted.

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

Legacy `--preset` / `--plan` / `--export-plan` flags are ignored (kept so older scripts don’t break).

## State files

```text
~/.dotfiles-setup/
  install-log.jsonl      # undo source of truth
  shell-features.zsh     # DOTFILES_DIR, Starship / OMZ flags
  backups/               # pre-overwrite backups
~/.dotfiles-setup.conf   # last package manager preference
```

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Prompt not showing Starship | Check `~/.dotfiles-setup/shell-features.zsh`, then restart the terminal |
| Missing glyphs / icons | Set the terminal font to a Nerd Font (e.g. SFMono Nerd Font) |
| Wrong repo path after moving | Re-run `./setup.sh` (or `-y`) so `DOTFILES_DIR` is rewritten |
| Undo didn’t remove a symlink | It only removes paths still logged as symlinks; already-correct links skipped at install may not be logged |

## License

MIT — see [LICENSE](LICENSE).
