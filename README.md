# dotfiles-setup

Cross-platform **new machine setup** for macOS and Linux. A **gum** wizard installs a fixed **zsh + Starship** shell stack via **Homebrew**, then lets you select apps and tools.

## Quick start

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
```

Prefer a dry-run first (writes nothing):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)" -- -n
# or from a clone:
./.scripts/setup.sh -n
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Install](docs/install.md) | curl bootstrap, PATH, prerequisites |
| [Usage](docs/usage.md) | Wizard steps, dry-run, updates, flags |
| [Profiles](docs/profiles.md) | Optional community TOML (not required for the main flow) |
| [Contributing](docs/contributing.md) | Catalog recipes, modules, tests |
| [Architecture](docs/architecture.md) | Engine overview |
| [FAQ](docs/faq.md) | Common questions |

## What it does

1. Detects **macOS** or **Linux**  
2. Ensures **Homebrew** (installs on Linux if missing)  
3. Installs a fixed **shell** stack: zsh, Starship, autosuggestions, syntax highlighting, eza, z (no Oh My Zsh)  
4. Lets you **select/deselect** apps (editors, browsers, chat, Docker, CLI languages, ...)  
5. If something is already installed and outdated, **prompts to update**  
6. Generates modular configs into `$HOME`  

## License

See [LICENSE](LICENSE) (MIT).
