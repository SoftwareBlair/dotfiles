# Contributing

Thanks for improving **dotfiles-setup**.

## Dev setup

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles
bash .scripts/tui/test.sh   # Go tests + catalog/generate/dry-run smokes
bash .scripts/validate-profiles.sh
```

## Add a catalog package

Add a `catalog_register` entry under [`.scripts/catalog/`](../.scripts/catalog/) (`browsers.sh`, `cli-tools.sh`, `apps.sh`, `dev-tools.sh`, …). Prefer **brew** recipes:

- `install_brew_macos` / `install_brew_linux`
- `check=…` for installed detection
- `pkg_brew` or `pkg_brew_cask` (or parseable `brew install` / `brew install --cask`) for update checks
- `uninstall_brew=…`

List new **opt-in** app ids in `APP_OPTIONAL_IDS` (or defaults in `APP_DEFAULT_IDS`) in [`.scripts/lib/presets.sh`](../.scripts/lib/presets.sh).

## Add a zsh module template

1. Add `templates/zsh/modules/<name>.zsh.tmpl`
2. Map the catalog id in [`.scripts/lib/generate.sh`](../.scripts/lib/generate.sh)
3. Add the id to `SHELL_IDS` in presets if it is part of the fixed shell stack

## Tests (required)

- `bash .scripts/tui/test.sh` - includes dry-run no-op and brew catalog smokes
- `bash .scripts/validate-profiles.sh` if touching profiles/
