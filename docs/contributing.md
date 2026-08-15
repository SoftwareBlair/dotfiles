# Contributing

Thanks for improving **dotfiles-setup** - a shared machine-setup tool.

## Dev setup

```bash
git clone https://github.com/SoftwareBlair/dotfiles.git
cd dotfiles
# TUI
cd .scripts/tui && go test ./... && ./test.sh
# Profiles
../validate-profiles.sh
```

## Add a catalog package

Edit files under [`.scripts/catalog/`](../.scripts/catalog/). Register with `catalog_register`, set `category` (`shells`, `shell-configs`, `dev-tools`, `fonts`), and provide install recipes per package manager.

For generate-only modules set `generate_only=true` (see `zsh_aliases`).

## Add a zsh module template

1. Add `templates/zsh/modules/<name>.zsh.tmpl`
2. Map the catalog id in [`.scripts/lib/generate.sh`](../.scripts/lib/generate.sh) (`generate_module_name`)
3. Optionally register a catalog id so it appears in the shell step

## Add a profile

1. Create `profiles/YourGitHubUsername.toml` (`github` must match the filename)
2. List `packages_shell` / `packages_dev` using real catalog ids
3. Point `[themes]` at an existing theme under `templates/themes/`
4. Run `.scripts/validate-profiles.sh`
5. Open a PR

Details: [profiles](profiles.md) and [`profiles/README.md`](../profiles/README.md).

## Tests (required)

- Go: `cd .scripts/tui && go test ./...` - wizard steps, UI keys, engine argv, catalog parse
- Smoke: `./.scripts/tui/test.sh` (includes catalog export)
- Profiles: `./.scripts/validate-profiles.sh`

Update fixtures under `.scripts/tui/testdata/` when the export JSON shape changes.

## PR checklist

- [ ] Tests pass (`go test`, `test.sh`, `validate-profiles.sh`)
- [ ] Docs updated if flags or user flow changed (`docs/`, README)
- [ ] No secrets committed
- [ ] New catalog ids documented in profile / contributing notes if user-facing

## Code of conduct

Be respectful in issues and PRs. Maintainers may close hostile or off-topic traffic.
