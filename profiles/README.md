# Profiles

Community setups for **dotfiles-setup**. Each file is named after a GitHub username.

| File | User |
|------|------|
| `default.toml` | Built-in fresh install |
| `SoftwareBlair.toml` | [@SoftwareBlair](https://github.com/SoftwareBlair) |

## Add yours

1. Copy `default.toml` → `YourGitHubUsername.toml`
2. Set `github = "YourGitHubUsername"` (must match the filename)
3. Fill `packages_shell`, `packages_dev`, and `[themes]`
4. Run `../.scripts/validate-profiles.sh`
5. Open a PR

Full guide: [docs/profiles.md](../docs/profiles.md) · [docs/contributing.md](../docs/contributing.md)
