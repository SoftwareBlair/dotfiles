# Setup profiles

Each TOML file is a **community setup** named after a [GitHub username](https://github.com/).

| File | GitHub user |
|------|-------------|
| `SoftwareBlair.toml` | [@SoftwareBlair](https://github.com/SoftwareBlair) |

## Add your setup

1. Copy `SoftwareBlair.toml` to `YourGitHubUsername.toml`.
2. Set `github = "YourGitHubUsername"` (must match the filename).
3. Edit `packages`, `packages_macos`, `packages_optional`, and `link` for your stack.
4. Put your config files either:
   - at the repo root and set `config_root = "."` (like Blair), or
   - under `profiles/YourGitHubUsername/` and set `config_root = "profiles/YourGitHubUsername"`.
5. Open a PR.

Package IDs must exist in [`.scripts/catalog/`](../.scripts/catalog/).

## Schema

```toml
github = "YourGitHubUsername"          # required; must match filename
name = "Display name"                  # short label in the picker
description = "One-line summary"

packages = ["starship", "eza", "zsh"] # wizard defaults
packages_macos = []                    # macOS-only extras
packages_optional = []                 # added when available for this OS/pkgmgr

link = [".zshrc", ".zshenv", ".config"]

config_root = "profiles/YourGitHubUsername"

help_editors = "…"
help_terminal = "…"
help_shell = "…"

# Keep [link_if] last — TOML puts following keys into the current table.
[link_if]
warp = [".warp"]                       # optional: link when package selected
```

## Using a profile

```bash
./setup.sh --profile SoftwareBlair
./setup.sh --profile SoftwareBlair -y
DOTFILES_PROFILE=SoftwareBlair ./setup.sh
```

Interactive runs let you pick a profile when more than one is present.
