# dotfiles-setup

Cross-platform **new machine setup** for macOS and Linux. A TUI wizard installs packages and **generates** modular shell configs into your home directory. Community **profiles** (including a built-in Default) share package lists and themes — this is a tool for everyone, not one person’s private dotfiles dump.

## Quick start

```bash
# curl (recommended one-liner)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"

# or Homebrew (after the first release is tagged)
brew tap SoftwareBlair/dotfiles
brew install dotfiles-setup
dotfiles-setup
```

Prefer a dry-run first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)" -- -n
# or
dotfiles-setup --dry-run
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Install](docs/install.md) | curl, Homebrew, PATH, prerequisites |
| [Usage](docs/usage.md) | TUI walkthrough, dry-run, flags, undo |
| [Profiles](docs/profiles.md) | Default vs community profiles & themes |
| [Contributing](docs/contributing.md) | Catalog recipes, modules, PRs, tests |
| [Releasing](docs/releasing.md) | Tags, GitHub Actions, brew formula |
| [Architecture](docs/architecture.md) | TUI ↔ bash engine ↔ generator |
| [FAQ](docs/faq.md) | Common questions |

## What it does

1. Detects OS (macOS / Linux) and package manager options  
2. Ensures `git` and `curl`  
3. Lets you pick a **profile** (Default or a community setup) with a live preview  
4. Select **shell** packages/modules, then **developer** apps  
5. Confirms the plan (dry-run toggle) and installs + generates configs  

Configs are written to `~/.zshrc`, `~/.zshenv`, `~/.config/starship.toml`, and `~/.dotfiles-setup/generated/` — only modules you selected.

## License

See [LICENSE](LICENSE) (MIT).
