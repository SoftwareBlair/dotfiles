# FAQ

## Is this only SoftwareBlair’s personal dotfiles?

No. It is a general **brew-first** machine setup tool. The default path installs a shared zsh + Starship stack and optional apps.

## Will dry-run change my machine?

No. `-n` / confirm **Preview plan (dry-run)** installs nothing and does not create `~/.dotfiles-setup` or rewrite shell configs.

## What if a package is already installed?

The wizard checks for updates and asks whether to upgrade. Decline to keep the current version. `-y` accepts updates automatically.

## Why Homebrew on Linux?

One package manager across macOS and Linux keeps recipes consistent. The wizard installs Homebrew on Linux when it is missing.

## Where is Oh My Zsh?

Not part of this flow. The shell stack uses **Starship** instead.

## What about the Go TUI?

Optional/experimental. Build under `.scripts/tui` and run `./.scripts/setup.sh --tui`. Curl install uses gum.

## Where is state stored?

`~/.dotfiles-setup/` - install log, prefs, generated modules (created only on a real install).
