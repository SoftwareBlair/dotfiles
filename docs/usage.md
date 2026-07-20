# Usage

## Start the wizard

```bash
dotfiles-setup
# or from a clone:
./.scripts/setup.sh --tui
./.scripts/setup.sh --bash   # classic prompts
```

## TUI flow

1. **Prerequisites** — install git/curl if missing  
2. **Package manager** — brew / apt / dnf / pacman  
3. **Migrate** (if needed) — upgrade prior setup, adopt unmanaged configs, or skip  
4. **Profile** — Default (fresh) or a community profile; preview shows packages & themes  
5. **Shell environment** — zsh modules/tools (only selected modules are generated)  
6. **Developer apps** — editors, terminals, fonts  
7. **Confirm** — review plan; press `n` to toggle **dry-run**  
8. **Run** — install packages + generate configs  

Require at least one selected package/module before confirm.

### Keys

| Screen | Keys |
|--------|------|
| Lists | ↑/↓, enter |
| Packages | space toggle, `a` all, `d` defaults, `c` clear |
| Confirm | enter run, `n` dry-run toggle, esc back |
| Anywhere | `q` quit |

## Generated files

| Path | Role |
|------|------|
| `~/.zshrc` / `~/.zshenv` | Orchestrators (regenerated) |
| `~/.dotfiles-setup/generated/*.zsh` | Selected modules only |
| `~/.config/starship.toml` | Theme from profile (if starship selected) |
| `~/.dotfiles-setup/shell-features.zsh` | Feature flags (`DOTFILES_SETUP_SCHEMA=2`) |
| `~/.zshrc.local` | **Your** overrides — never overwritten |
| `~/.zprofile` | Secrets (optional prompt) |

## Dry-run

```bash
dotfiles-setup --dry-run
./.scripts/setup.sh -n --bash --profile default
```

Same prompts/plan; no installs or file writes.

## Non-interactive

```bash
./.scripts/setup.sh -y --profile default --pkgmgr brew --bash
./.scripts/setup.sh -y -n --profile SoftwareBlair --pkgmgr apt --bash
```

`-y` uses the profile’s default package set.

## Undo

```bash
./.scripts/setup.sh --undo
./.scripts/setup.sh --undo -n
./.scripts/setup.sh --undo --select
```

Reverses actions in `~/.dotfiles-setup/install-log.jsonl` (including generated files when logged).

## Flags (setup.sh)

| Flag | Meaning |
|------|---------|
| `--tui` / `--bash` | Force UI |
| `--profile <id>` | `default`, `SoftwareBlair`, … |
| `--pkgmgr <name>` | brew \| apt \| dnf \| pacman |
| `-y` | Non-interactive |
| `-n` | Dry-run |
| `--undo` | Reverse logged actions |
| `-h` | Help |
