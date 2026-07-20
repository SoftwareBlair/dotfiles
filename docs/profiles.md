# Profiles

Profiles are declarative TOML files under [`profiles/`](../profiles/). They define **package lists** and **themes** — not a full copy of someone’s `$HOME`.

## Built-in: `default`

Fresh install path. Minimal shell defaults (`zsh`, `starship`) and the **stock** Starship theme.

## Community profiles

Named after a GitHub username, e.g. [`SoftwareBlair.toml`](../profiles/SoftwareBlair.toml). The filename must match `github = "…"`.

Choosing a profile **is** choosing its package set — the wizard does not ask you to pick packages again.

Example fields:

```toml
github = "YourName"
name = "Display name"
description = "One-line summary"

packages_shell = ["zsh", "starship", "zsh_aliases"]
packages_dev = ["cursor", "zed"]
packages_macos = ["raycast"]
packages_optional = ["vscode"]

[themes]
starship = "stock"   # or a folder under templates/themes/
```

## Themes

Starship themes live in `templates/themes/<id>/starship.toml`. Profiles reference them via `[themes] starship = "<id>"`.

## Modules vs packages

Some shell ids only **generate** config (`zsh_aliases`). Others install software and may also emit a module (`nvm`, `starship`, …). See [architecture](architecture.md).

## Preview

The TUI profile screen shows description, theme, shell items, and dev items for the highlighted profile.
