# Developer Machine Setup (macOS + Linux)

Interactive wizard to bootstrap a new developer machine: coding fonts, editors/terminals, shells (**zsh** or **fish**), and shell tools — with your choice of package manager (**Homebrew**, **apt**, **dnf**, or **pacman**).

Personal dotfiles in this repo (Starship, zsh aliases, Warp/Zed themes, etc.) can be optionally symlinked at the end.

**Windows is not supported.**

## Prerequisites

- `git` and `curl`
- `sudo` for system package installs (apt/dnf/pacman)
- A terminal that supports interactive prompts (or use `-y` / `--dry-run` for non-interactive / preview)

## Quick start

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git ~/dotfiles
cd ~/dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

If the repo is not at `~/dotfiles`:

```bash
./setup.sh -c move_dotfiles
./setup.sh
```

Restart your terminal when finished.

## Interactive wizard

1. Detects OS (macOS / Linux), distro family, and architecture  
2. Lets you choose a **package manager** available on this system  
3. Installs prerequisites (Xcode CLT on macOS, build tools on Linux)  
4. Multi-select catalogs:
   - **Fonts** — SFMono Nerd Font, Hack, FiraCode, JetBrains Mono, Meslo, Cascadia Code  
   - **Developer software** — VS Code, Warp (Mac + Linux), Zed, JetBrains Toolbox, GitHub CLI, Git, Raycast (macOS only)  
   - **Shell** — **zsh** or **fish** only (bash is not offered; it is already the default on most Linux distros, and zsh is default on modern macOS)  
   - **Shell configs** — Starship, Oh My Zsh, eza, NVM, zsh plugins, fzf, zoxide, bat  
5. Optional Git identity configuration  
6. Optional symlink of dotfiles from this repo  
7. Preview the install plan or install immediately  

## Package managers

| Manager   | macOS | Linux                          |
|-----------|-------|--------------------------------|
| Homebrew  | Yes   | Yes (Linuxbrew)                |
| apt       | —     | Debian / Ubuntu family         |
| dnf       | —     | Fedora / RHEL family           |
| pacman    | —     | Arch family                    |

Skip the picker with:

```bash
./setup.sh --pkgmgr apt
```

Preference is saved to `~/.dotfiles-setup.conf`.

## Dry run

See **exactly** which commands would run, where things install, and side effects — without changing your system:

```bash
./setup.sh --dry-run
# or
./setup.sh -n
```

Non-interactive plan from defaults:

```bash
./setup.sh -y --dry-run --pkgmgr brew
```

In interactive mode you can also choose **Preview install plan** before confirming.

## Undo / revert

Every successful install, symlink, and wizard-owned side effect is recorded in:

```text
~/.dotfiles-setup/install-log.jsonl
```

Backups of replaced files go to `~/.dotfiles-setup/backups/`.

```bash
./setup.sh --undo                 # reverse everything logged
./setup.sh --undo --dry-run       # preview undo plan
./setup.sh --undo --select        # pick which items to undo
./setup.sh -c revert_setup        # same as --undo
```

Safety notes:

- Only items installed by this wizard (`owned_by_wizard`) are removed  
- Pre-existing tools are not uninstalled  
- `~/.gitconfig` is **never** deleted automatically  
- Homebrew is only removed if you explicitly opt in during undo  

## Flags reference

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show help |
| `-y`, `--yes` | Non-interactive defaults / select all available items |
| `-n`, `--dry-run` | Preview only; no changes |
| `--undo` | Reverse logged setup actions |
| `--select` | With `--undo`: choose items |
| `--pkgmgr <name>` | `brew` \| `apt` \| `dnf` \| `pacman` |
| `-c <command>` | Run a single helper |

## Selective helpers (`-c`)

```bash
./setup.sh -c move_dotfiles
./setup.sh -c remove_git_origin_remote
./setup.sh -c revert_setup
./setup.sh -c uninstall_nvm
```

## Dotfiles layout

When you opt into symlinks, typical targets are:

| Path | When |
|------|------|
| `.zshrc` | zsh users |
| `.config` | Starship and other shared config |
| `.config/zed` | Zed selected |
| `.warp` | Warp selected |
| `.config/fish` | fish selected |

## Terminal UI

The wizard uses [gum](https://github.com/charmbracelet/gum) when available (installed via Homebrew or a downloaded binary under `.scripts/bin/`). If gum cannot be installed, it falls back to plain colored prompts.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Unsupported OS | Only macOS and Linux are supported |
| Option missing from list | Filtered for your OS + package manager |
| Partial install failure | Re-run wizard or `--undo --select` then retry |
| Shell plugins not loading | Ensure brew/system paths match [`.zshrc`](.zshrc); restart terminal |
| Fonts not showing | Restart terminal / set font in terminal settings; on Linux run `fc-cache -fv` |

## Contributing

Fork, branch, and open a pull request. Suggestions welcome.

## License

MIT — see [LICENSE](LICENSE).
