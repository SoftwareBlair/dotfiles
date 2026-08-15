# Releasing

## Tag a release

```bash
git checkout main
git pull
# bump Formula/dotfiles-setup.rb version if needed
git tag v0.1.0
git push origin v0.1.0
```

Pushing a `v*` tag runs [`.github/workflows/release-tui.yml`](../.github/workflows/release-tui.yml), which builds:

- `dotfiles-setup-linux-amd64`
- `dotfiles-setup-linux-arm64`
- `dotfiles-setup-darwin-amd64`
- `dotfiles-setup-darwin-arm64`

and attaches them to the GitHub Release.

Manual: Actions → **Release TUI** → Run workflow (optional tag input).

## Homebrew formula

1. Download release assets and compute `sha256` for each platform binary  
2. Update [`Formula/dotfiles-setup.rb`](../Formula/dotfiles-setup.rb) `version` and `sha256` values  
3. Users install with:

```bash
brew tap SoftwareBlair/dotfiles
brew install dotfiles-setup
```

(If the tap is this same repository, `brew tap SoftwareBlair/dotfiles` works when GitHub hosts the Formula.)

## Smoke checklist before announcing

- [ ] `install.sh` downloads the new binary for your OS/arch  
- [ ] `dotfiles-setup --dry-run` completes on a clean VM  
- [ ] `./.scripts/setup.sh -y -n --profile default --pkgmgr apt --bash` succeeds  
- [ ] `./.scripts/tui/test.sh` and `./.scripts/validate-profiles.sh` pass  
- [ ] Docs version notes / changelog (optional) updated  
