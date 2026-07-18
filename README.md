# My machine setup (macOS + Linux)

Installs **my usual stack** from the `improvements-while-using` workflow — fonts, Warp, **Cursor** (default editor), Zed, Starship, eza, zsh plugins, NVM — then symlinks this repo’s configs.

**Windows is not supported.**

## Quick start

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

Confirm once and it installs. The repo can live anywhere (`~/dotfiles` is optional).

```bash
./setup.sh -y              # non-interactive
./setup.sh -n              # dry-run (preview only)
./setup.sh -y -n           # non-interactive dry-run
./setup.sh --pkgmgr apt    # or brew | dnf | pacman
./setup.sh --undo          # reverse what this script installed
```

Restart your terminal when finished.

## What’s installed

Defined in [`.scripts/lib/presets.sh`](.scripts/lib/presets.sh) as `MY_SETUP`:

| Item | Notes |
|------|--------|
| SFMono Nerd Font | Terminal / editor font |
| Starship | Prompt (via this repo’s `.zshrc`) |
| eza | `ls` replacement |
| Warp | Terminal |
| Cursor | Default editor |
| Zed | Fast editor (+ `.config/zed`) |
| zsh + autosuggestions + syntax-highlighting + z | Shell plugins |
| NVM | Node version manager |
| Raycast | macOS only |
| VS Code | Optional, when a recipe is available |

To change the stack, edit `MY_SETUP` / `MY_SETUP_MACOS` / `MY_SETUP_OPTIONAL` in `presets.sh`.

## Package managers

| Manager | macOS | Linux |
|---------|-------|-------|
| Homebrew (default) | Yes | Yes (Linuxbrew) |
| apt | — | Debian / Ubuntu |
| dnf | — | Fedora / RHEL |
| pacman | — | Arch |

Homebrew is preferred so Mac and Linux stay close to the same workflow.

## Dotfiles linked

Symlinked into `$HOME` (not copied):

- `.zshrc`, `.zshenv`, `.config`
- `.warp` when Warp is selected
- `.config/zed` when Zed is selected

Shell features land in `~/.dotfiles-setup/shell-features.zsh` and are sourced by [`.zshrc`](.zshrc).

## Undo

```bash
./setup.sh --undo
./setup.sh --undo -n       # preview
./setup.sh -c revert_setup
```

Only actions logged by this script are reversed. `~/.gitconfig` is never deleted.

## State

```text
~/.dotfiles-setup/
  install-log.jsonl      # undo source of truth
  shell-features.zsh     # DOTFILES_DIR, Starship flags
  backups/               # pre-overwrite backups
```

## License

MIT — see [LICENSE](LICENSE).
