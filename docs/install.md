# Install

Supported platforms: **macOS** and **Linux** (apt, dnf, pacman, or Homebrew).

## Prerequisites

- A terminal
- Network access to GitHub
- The wizard can install **git** and **curl** if they are missing (you will be prompted)

## Option A — curl one-liner

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/SoftwareBlair/dotfiles/main/install.sh)"
```

This will:

1. Clone or reuse the repo under `~/dotfiles` (override with `DOTFILES_DIR`)
2. Download the `dotfiles-setup` binary from GitHub Releases into `.scripts/bin/` and `~/.local/bin/`
3. Launch the setup wizard

Ensure `~/.local/bin` is on your `PATH` if you want to re-run `dotfiles-setup` later:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Useful flags

Pass flags after `--` when using `bash -c`:

```bash
/bin/bash -c "$(curl -fsSL …/install.sh)" -- -n
/bin/bash -c "$(curl -fsSL …/install.sh)" -- --profile default
/bin/bash -c "$(curl -fsSL …/install.sh)" -- --bash
```

## Option B — Homebrew

After a `v*` release exists:

```bash
brew tap SoftwareBlair/dotfiles
brew install dotfiles-setup
dotfiles-setup
```

The formula lives in this repo at [`Formula/dotfiles-setup.rb`](../Formula/dotfiles-setup.rb). Maintainers bump `version` and `sha256` on each release (see [releasing](releasing.md)).

From a local checkout (development):

```bash
brew install --formula ./Formula/dotfiles-setup.rb
```

## Option C — clone and run

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles/.scripts
./setup.sh --tui    # or --bash
```

Build the TUI locally if no release binary is present:

```bash
cd .scripts/tui && go build -o ../bin/dotfiles-setup .
```

## Verify

```bash
dotfiles-setup --help   # if on PATH
./.scripts/setup.sh -h
```
